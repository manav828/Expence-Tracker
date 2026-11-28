import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors/error_handler.dart';
import '../models/split_models.dart';
import '../services/split_service.dart';
import '../services/pixabay_service.dart';

class SplitProvider with ChangeNotifier {
  List<SplitGroup> _groups = [];
  final Map<String, List<SplitMember>> _members = {};
  final Map<String, List<SplitExpense>> _expenses = {};
  final Map<String, List<Settlement>> _settlements = {};
  final Map<String, Map<String, double>> _balances = {};
  final Map<String, List<SplitShare>> _shares = {};
  final Map<String, List<SplitExpenseGroup>> _expenseGroups = {};
  final Map<String, List<SplitSettlementGroup>> _settlementGroups = {};
  final Map<String, bool> _simplifyDebts = {};
  bool _isLoading = false;
  bool _hasPendingSync = false;
  String? _error;
  String? _currentMemberName; // the name used by this device in groups
  StreamSubscription<AuthState>? _authSub;
  final Map<String, Future<SplitGroup?>> _inFlightJoins = {};

  User? get _currentAuthUser {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  String get _userGroupIdsKey {
    final uid = _currentAuthUser?.id;
    return uid != null ? 'split_group_ids_$uid' : 'split_group_ids_guest';
  }

  String get _memberNameKey {
    final uid = _currentAuthUser?.id;
    return uid != null ? 'split_member_name_$uid' : 'split_member_name_guest';
  }

  List<SplitGroup> get groups => _groups;
  Map<String, List<SplitMember>> get members => _members;
  Map<String, List<SplitExpense>> get expenses => _expenses;
  Map<String, List<Settlement>> get settlements => _settlements;
  Map<String, Map<String, double>> get balances => _balances;
  Map<String, List<SplitExpenseGroup>> get expenseGroups => _expenseGroups;
  Map<String, List<SplitSettlementGroup>> get settlementGroups => _settlementGroups;
  bool get isLoading => _isLoading;
  bool get hasPendingSync => _hasPendingSync;
  String? get error => _error;
  String? get currentMemberName => _currentMemberName;

  static const _activeTripGroupIdKey = 'active_trip_mode_group_id';
  String? _activeTripGroupId;

  String? get activeTripGroupId => _activeTripGroupId;
  bool get isTripModeActive =>
      _activeTripGroupId != null && _groups.any((g) => g.id == _activeTripGroupId);

  SplitGroup? get activeTripGroup {
    if (_activeTripGroupId == null) return null;
    try {
      return _groups.firstWhere((g) => g.id == _activeTripGroupId);
    } catch (_) {
      return null;
    }
  }

  Future<void> enableTripMode(String groupId) async {
    _activeTripGroupId = groupId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeTripGroupIdKey, groupId);
    notifyListeners();
  }

  Future<void> disableTripMode() async {
    _activeTripGroupId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeTripGroupIdKey);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  List<SplitMember> getMembersForGroup(String groupId) => _members[groupId] ?? [];

  SplitMember? getCurrentMemberForGroup(String groupId) {
    final members = getMembersForGroup(groupId);
    final userId = _currentAuthUser?.id;
    final name = _currentMemberName?.trim().toLowerCase();
    return members.where((member) => userId != null && member.userId == userId).firstOrNull ??
        members.where((member) => member.userId == null && member.name.trim().toLowerCase() == name).firstOrNull;
  }

  bool ownsGroup(SplitGroup group) => group.userId != null && group.userId == _currentAuthUser?.id;
  bool canManageExpense(SplitExpense expense) {
    final userId = _currentAuthUser?.id;
    if (expense.authorUserId != null) return expense.authorUserId == userId;
    final member = getCurrentMemberForGroup(expense.groupId);
    return member != null &&
        member.id == expense.addedByMemberId &&
        (userId == null || member.userId == userId);
  }

  void _requireExpenseAuthor(String groupId, String expenseId) {
    final expense = getExpensesForGroup(groupId).where((item) => item.id == expenseId).firstOrNull;
    if (expense == null || !canManageExpense(expense)) {
      throw StateError('Only the person who added this expense can change it.');
    }
  }
  List<SplitExpense> getExpensesForGroup(String groupId) => _expenses[groupId] ?? [];
  List<Settlement> getSettlementsForGroup(String groupId) => _settlements[groupId] ?? [];
  Map<String, double> getBalancesForGroup(String groupId) => _balances[groupId] ?? {};

  @visibleForTesting
  void setGroupDetailForTesting({
    required String groupId,
    required List<SplitMember> members,
    required List<SplitSettlementGroup> settlementGroups,
    List<SplitExpenseGroup> expenseGroups = const [],
    List<SplitExpense> expenses = const [],
    List<Settlement> settlements = const [],
    Map<String, double> balances = const {},
    List<SplitGroup>? groups,
  }) {
    if (groups != null) {
      _groups.clear();
      _groups.addAll(groups);
    }
    _members[groupId] = members;
    _settlementGroups[groupId] = settlementGroups;
    _expenseGroups[groupId] = expenseGroups;
    _expenses[groupId] = expenses;
    _settlements[groupId] = settlements;
    _balances[groupId] = balances;
    notifyListeners();
  }
  List<SplitExpenseGroup> getExpenseGroupsForGroup(String groupId) => _expenseGroups[groupId] ?? [];
  List<SplitSettlementGroup> getSettlementGroupsForGroup(String groupId) => _settlementGroups[groupId] ?? [];

  SplitProvider() {
    _init();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentMemberName ??= prefs.getString(_memberNameKey);
    _activeTripGroupId ??= prefs.getString(_activeTripGroupIdKey);
    await loadGroups();

    try {
      // Listen to Supabase auth events (e.g. session restored from disk, login, user switch)
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        final event = data.event;
        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.initialSession ||
            event == AuthChangeEvent.userUpdated) {
          final prefs = await SharedPreferences.getInstance();
          _currentMemberName = prefs.getString(_memberNameKey);
          loadGroups(isBackgroundRefresh: true);
        } else if (event == AuthChangeEvent.signedOut) {
          clearStateOnLogout();
        }
      });
    } catch (_) {}
  }

  void clearStateOnLogout() {
    _activeTripGroupId = null;
    _groups.clear();
    _members.clear();
    _expenses.clear();
    _settlements.clear();
    _balances.clear();
    _expenseGroups.clear();
    _settlementGroups.clear();
    notifyListeners();
  }

  Future<void> setCurrentMemberName(String name) async {
    _currentMemberName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_memberNameKey, name);
    notifyListeners();
  }

  Future<void> _checkPendingSync() async {
    _hasPendingSync = await SplitService.instance.hasPendingSync();
    notifyListeners();
  }

  Future<int> syncAll() async {
    final synced = await SplitService.instance.syncPendingData();
    await _checkPendingSync();
    if (synced > 0) {
      await loadGroups(isBackgroundRefresh: true);
    }
    return synced;
  }

  Future<void> loadGroups({bool isBackgroundRefresh = false}) async {
    if (!isBackgroundRefresh) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_userGroupIdsKey) ?? [];
      final guestIds = prefs.getStringList('split_group_ids_guest') ?? [];
      final localIds = await SplitService.instance.getAllLocalGroupIds();
      final allLocalIds = {
        ...ids,
        if (_currentAuthUser != null) ...guestIds,
        ...localIds
      }.toList();

      // FETCH FROM DB (Supabase cloud first, with local SQLite offline fallback)
      _groups = await SplitService.instance.fetchUserGroups(localKnownIds: allLocalIds);

      // Keep local preferences updated with all discovered group IDs for this user
      final discoveredIds = _groups.map((g) => g.id).toList();
      if (discoveredIds.isNotEmpty) {
        await prefs.setStringList(_userGroupIdsKey, discoveredIds);
      }

      await Future.wait(_groups.map((g) => loadGroupDetail(g.id)));
      _checkPendingSync();

      // Drain pending queue if online in background
      SplitService.instance.syncPendingData().then((synced) {
        if (synced > 0) {
          _checkPendingSync();
          for (final g in _groups) {
            loadGroupDetail(g.id);
          }
        }
      });
    } catch (e, st) {
      ErrorHandler.log('SplitProvider.loadGroups', e, st);
      if (!isBackgroundRefresh) {
        _error = ErrorHandler.getUserMessage(e);
      }
    }
    if (!isBackgroundRefresh) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadGroupDetail(String groupId) async {
    try {
      final results = await Future.wait([
        SplitService.instance.getMembers(groupId),
        SplitService.instance.getExpenses(groupId),
        SplitService.instance.getSettlements(groupId),
        SplitService.instance.getAllSharesForGroup(groupId),
        SplitService.instance.getExpenseGroups(groupId),
        SplitService.instance.getSettlementGroups(groupId),
      ]);

      final members = results[0] as List<SplitMember>;
      final exps = results[1] as List<SplitExpense>;
      final setts = results[2] as List<Settlement>;
      final shares = results[3] as List<SplitShare>;
      final egs = results[4] as List<SplitExpenseGroup>;
      final sgs = results[5] as List<SplitSettlementGroup>;

      final bals = SplitService.instance.computeBalancesFromData(
        members: members,
        expenses: exps,
        settlements: setts,
        shares: shares,
      );

      final prefs = await SharedPreferences.getInstance();
      _simplifyDebts[groupId] = prefs.getBool('split_simplify_debts_$groupId') ?? true;

      _members[groupId] = members;
      _expenses[groupId] = exps;
      _settlements[groupId] = setts;
      _shares[groupId] = shares;
      _balances[groupId] = bals;
      _expenseGroups[groupId] = egs;
      _settlementGroups[groupId] = sgs;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<SplitGroup> createGroup({
    required String name,
    String? description,
    String? imageUrl,
    required String createdByName,
    required List<String> memberNames,
  }) async {
    final finalImageUrl = imageUrl?.trim().isNotEmpty == true ? imageUrl :
        await PixabayService.fetchImageForGroup(
          name: name,
          description: description,
        );

    final group = await SplitService.instance.createGroup(
      name: name,
      description: description,
      imageUrl: finalImageUrl,
      createdBy: createdByName,
    );
    // Add creator as first member with their auth user_id
    final currentUser = _currentAuthUser;
    await SplitService.instance.addMember(
      groupId: group.id,
      name: createdByName,
      userId: currentUser?.id,
    );
    // Add other members
    for (final mn in memberNames) {
      if (mn.trim().isNotEmpty) {
        await SplitService.instance.addMember(groupId: group.id, name: mn.trim());
      }
    }
    // Save group id locally
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_userGroupIdsKey) ?? [];
    if (!ids.contains(group.id)) {
      ids.add(group.id);
      await prefs.setStringList(_userGroupIdsKey, ids);
    }
    _groups.removeWhere((g) => g.id == group.id);
    _groups.insert(0, group);
    try {
      await loadGroupDetail(group.id);
    } catch (e) {
      debugPrint('Error loading group detail in join: $e');
    }
    _checkPendingSync();
    notifyListeners();
    return group;
  }

  Future<SplitGroup?> joinGroupByInviteCode(String code, String memberName) async {
    final cleanCode = code.trim().toUpperCase();
    if (_inFlightJoins.containsKey(cleanCode)) {
      debugPrint('Join already in flight for $cleanCode, awaiting existing join...');
      return await _inFlightJoins[cleanCode]!;
    }

    final future = _joinGroupByInviteCodeInternal(cleanCode, memberName);
    _inFlightJoins[cleanCode] = future;
    try {
      final res = await future;
      return res;
    } finally {
      _inFlightJoins.remove(cleanCode);
    }
  }

  Future<SplitGroup?> _joinGroupByInviteCodeInternal(String code, String memberName) async {
    final group = await SplitService.instance.joinGroupByInviteCode(code, memberName);
    if (group == null) return null;
    await setCurrentMemberName(memberName.trim());

    // Save group ID in user-scoped preferences
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_userGroupIdsKey) ?? [];
    if (!ids.contains(group.id)) {
      ids.add(group.id);
      await prefs.setStringList(_userGroupIdsKey, ids);
    }
    await prefs.remove('pending_invite_code');

    _groups.removeWhere((g) => g.id == group.id);
    _groups.insert(0, group);
    try {
      await loadGroupDetail(group.id);
    } catch (e) {
      debugPrint('Error loading group detail in join: $e');
    }
    _checkPendingSync();
    notifyListeners();
    return group;
  }

  Future<void> updateGroup(SplitGroup updated) async {
    await SplitService.instance.updateGroup(updated);
    final idx = _groups.indexWhere((g) => g.id == updated.id);
    if (idx != -1) {
      _groups[idx] = updated;
    }
    _checkPendingSync();
    notifyListeners();
  }

  Future<void> deleteGroup(String groupId) async {
    await SplitService.instance.deleteGroup(groupId);
    _groups.removeWhere((g) => g.id == groupId);
    _members.remove(groupId);
    _expenses.remove(groupId);
    _settlements.remove(groupId);
    _balances.remove(groupId);
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_userGroupIdsKey) ?? [];
    ids.remove(groupId);
    await prefs.setStringList(_userGroupIdsKey, ids);
    _checkPendingSync();
    notifyListeners();
  }

  Future<void> addExpense({
    required String groupId,
    required String title,
    required double totalAmount,
    required String paidByMemberId,
    required SplitType splitType,
    required Map<String, double> shares,
    String? category,
    String? note,
    String? receiptUrl,
    required String addedByMemberId,
  }) async {
    await SplitService.instance.addExpense(
      groupId: groupId,
      title: title,
      totalAmount: totalAmount,
      paidByMemberId: paidByMemberId,
      splitType: splitType,
      shares: shares,
      category: category,
      note: note,
      receiptUrl: receiptUrl,
      addedByMemberId: addedByMemberId,
    );
    await loadGroupDetail(groupId);
    _checkPendingSync();
  }

  /// Adds an expense into the currently active trip group with equal split among members.
  Future<bool> addTripModeExpense({
    required double amount,
    required String title,
    String? category,
    String? note,
    String? receiptUrl,
  }) async {
    final tripGroup = activeTripGroup;
    if (tripGroup == null || amount <= 0) return false;

    List<SplitMember> groupMembers = getMembersForGroup(tripGroup.id);
    if (groupMembers.isEmpty) {
      await loadGroupDetail(tripGroup.id);
      groupMembers = getMembersForGroup(tripGroup.id);
    }
    if (groupMembers.isEmpty) return false;

    // Resolve current member
    final myUid = _currentAuthUser?.id;
    final myName = _currentMemberName?.trim().toLowerCase();
    SplitMember? currentMem;

    if (myUid != null) {
      for (final m in groupMembers) {
        if (m.userId == myUid) {
          currentMem = m;
          break;
        }
      }
    }
    if (currentMem == null && myName != null && myName.isNotEmpty) {
      for (final m in groupMembers) {
        if (m.name.trim().toLowerCase() == myName) {
          currentMem = m;
          break;
        }
      }
    }
    currentMem ??= groupMembers.first;

    // Distribute equal cents
    final totalCents = (amount * 100).round();
    final count = groupMembers.length;
    final baseCents = totalCents ~/ count;
    final remainderCents = totalCents % count;
    final shares = <String, double>{};
    for (var i = 0; i < count; i++) {
      final cents = baseCents + (i < remainderCents ? 1 : 0);
      shares[groupMembers[i].id] = cents / 100.0;
    }

    await addExpense(
      groupId: tripGroup.id,
      title: title,
      totalAmount: amount,
      paidByMemberId: currentMem.id,
      splitType: SplitType.equal,
      shares: shares,
      category: category,
      note: note,
      receiptUrl: receiptUrl,
      addedByMemberId: currentMem.id,
    );
    return true;
  }

  /// Calculates the current user's net expense share for a given split group.
  double calculateUserNetShare(String groupId) {
    final groupMembers = getMembersForGroup(groupId);
    if (groupMembers.isEmpty) return 0.0;
    final myUid = _currentAuthUser?.id;
    final myName = _currentMemberName?.trim().toLowerCase();

    SplitMember? currentMem;
    if (myUid != null) {
      for (final m in groupMembers) {
        if (m.userId == myUid) {
          currentMem = m;
          break;
        }
      }
    }
    if (currentMem == null && myName != null && myName.isNotEmpty) {
      for (final m in groupMembers) {
        if (m.name.trim().toLowerCase() == myName) {
          currentMem = m;
          break;
        }
      }
    }
    currentMem ??= groupMembers.first;

    final allShares = _shares[groupId];
    if (allShares != null && allShares.isNotEmpty) {
      return allShares
          .where((s) => s.memberId == currentMem!.id)
          .fold(0.0, (sum, s) => sum + s.shareAmount);
    }

    // Fallback: estimate from expenses with equal split
    final groupExpenses = getExpensesForGroup(groupId);
    if (groupExpenses.isEmpty) return 0.0;
    return groupExpenses.fold(0.0, (sum, e) => sum + (e.totalAmount / groupMembers.length));
  }

  Future<void> updateExpense({
    required String groupId,
    required String expenseId,
    required String title,
    required double totalAmount,
    required String paidByMemberId,
    required SplitType splitType,
    required Map<String, double> shares,
    String? category,
    String? note,
    String? receiptUrl,
  }) async {
    _requireExpenseAuthor(groupId, expenseId);
    await SplitService.instance.updateExpense(
      expenseId: expenseId,
      title: title,
      totalAmount: totalAmount,
      paidByMemberId: paidByMemberId,
      splitType: splitType,
      shares: shares,
      category: category,
      note: note,
      receiptUrl: receiptUrl,
    );
    await loadGroupDetail(groupId);
    _checkPendingSync();
  }

  Future<void> deleteExpense(String groupId, String expenseId) async {
    _requireExpenseAuthor(groupId, expenseId);
    await SplitService.instance.deleteExpense(expenseId, groupId);
    _expenses[groupId]?.removeWhere((expense) => expense.id == expenseId);
    notifyListeners();
    await loadGroupDetail(groupId);
    _checkPendingSync();
  }

  Future<void> recordSettlement({
    required String groupId,
    required String fromMemberId,
    required String toMemberId,
    required double amount,
    String? note,
    String? fromSettlementGroupId,
    String? toSettlementGroupId,
  }) async {
    final s = await SplitService.instance.recordSettlement(
      groupId: groupId,
      fromMemberId: fromMemberId,
      toMemberId: toMemberId,
      amount: amount,
      note: note,
      fromSettlementGroupId: fromSettlementGroupId,
      toSettlementGroupId: toSettlementGroupId,
    );

    // Optimistically update settlements and balances immediately so the slider card clears at once!
    final currentSetts = List<Settlement>.from(_settlements[groupId] ?? []);
    currentSetts.removeWhere((existing) => existing.id == s.id);
    currentSetts.insert(0, s);
    _settlements[groupId] = currentSetts;

    final members = _members[groupId] ?? [];
    final exps = _expenses[groupId] ?? [];
    final shares = _shares[groupId] ?? [];
    _balances[groupId] = SplitService.instance.computeBalancesFromData(
      members: members,
      expenses: exps,
      settlements: currentSetts,
      shares: shares,
    );
    notifyListeners();

    await loadGroupDetail(groupId);
    _checkPendingSync();
  }

  // --- Module A: Expense Member Groups Management ---

  Future<SplitExpenseGroup> createExpenseGroup({
    required String groupId,
    required String name,
    String? description,
    String? icon,
    required List<String> memberIds,
  }) async {
    final eg = await SplitService.instance.createExpenseGroup(
      groupId: groupId,
      name: name,
      description: description,
      icon: icon,
      memberIds: memberIds,
    );
    await loadGroupDetail(groupId);
    _checkPendingSync();
    return eg;
  }

  Future<void> updateExpenseGroup({
    required String expenseGroupId,
    required String groupId,
    required String name,
    String? description,
    String? icon,
    required List<String> memberIds,
  }) async {
    await SplitService.instance.updateExpenseGroup(
      expenseGroupId: expenseGroupId,
      name: name,
      description: description,
      icon: icon,
      memberIds: memberIds,
    );
    await loadGroupDetail(groupId);
    _checkPendingSync();
  }

  Future<void> deleteExpenseGroup({
    required String expenseGroupId,
    required String groupId,
  }) async {
    await SplitService.instance.deleteExpenseGroup(expenseGroupId);
    await loadGroupDetail(groupId);
    _checkPendingSync();
  }

  // --- Module B: Combined Settlement Groups Management ---

  Future<SplitSettlementGroup> createSettlementGroup({
    required String groupId,
    required String name,
    required List<String> memberIds,
  }) async {
    final sg = await SplitService.instance.createSettlementGroup(
      groupId: groupId,
      name: name,
      memberIds: memberIds,
    );
    await loadGroupDetail(groupId);
    _checkPendingSync();
    return sg;
  }

  Future<void> updateSettlementGroup({
    required String settlementGroupId,
    required String groupId,
    required String name,
    required List<String> memberIds,
  }) async {
    await SplitService.instance.updateSettlementGroup(
      settlementGroupId: settlementGroupId,
      groupId: groupId,
      name: name,
      memberIds: memberIds,
    );
    await loadGroupDetail(groupId);
    _checkPendingSync();
  }

  Future<void> deleteSettlementGroup({
    required String settlementGroupId,
    required String groupId,
  }) async {
    await SplitService.instance.deleteSettlementGroup(settlementGroupId);
    await loadGroupDetail(groupId);
    _checkPendingSync();
  }

  CombinedBalancesResult getCombinedBalancesResult(String groupId) {
    final individualBalances = _balances[groupId] ?? {};
    final settlementGroups = _settlementGroups[groupId] ?? [];
    return aggregateCombinedBalances(
      individualBalances: individualBalances,
      settlementGroups: settlementGroups,
    );
  }

  Future<void> addMember(String groupId, String name) async {
    final newMember = await SplitService.instance.addMember(groupId: groupId, name: name);
    final currentList = _members[groupId] ?? [];
    if (!currentList.any((m) => m.id == newMember.id)) {
      _members[groupId] = [...currentList, newMember];
      notifyListeners();
    }
    await loadGroupDetail(groupId);
    _checkPendingSync();
  }

  Future<void> assignPlaceholder({
    required String groupId,
    required String placeholderId,
    required String joinedMemberId,
  }) async {
    await SplitService.instance.assignPlaceholder(
      groupId: groupId,
      placeholderId: placeholderId,
      joinedMemberId: joinedMemberId,
    );
    await loadGroupDetail(groupId);
  }

  Future<void> removeMember(String groupId, String memberId) async {
    await SplitService.instance.removeMember(memberId);
    await loadGroupDetail(groupId);
    _checkPendingSync();
  }

  Future<void> updateMemberName(String groupId, String memberId, String newName) async {
    await SplitService.instance.updateMemberName(memberId, newName);
    await loadGroupDetail(groupId);
    _checkPendingSync();
  }

  Future<void> mergeMembers(String groupId, String fromMemberId, String toMemberId) async {
    await SplitService.instance.mergeMembers(groupId, fromMemberId, toMemberId);
    await loadGroupDetail(groupId);
    _checkPendingSync();
  }

  Future<List<SplitShare>> getSharesForExpense(String expenseId) async {
    return SplitService.instance.getSharesForExpense(expenseId);
  }

  bool isSimplifyDebtsEnabled(String groupId) => _simplifyDebts[groupId] ?? true;

  Future<void> setSimplifyDebts(String groupId, bool enabled) async {
    _simplifyDebts[groupId] = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('split_simplify_debts_$groupId', enabled);
  }

  Future<void> toggleSimplifyDebts(String groupId) async {
    final current = isSimplifyDebtsEnabled(groupId);
    await setSimplifyDebts(groupId, !current);
  }

  Future<void> deleteSettlement(String settlementId, String groupId) async {
    await SplitService.instance.deleteSettlement(settlementId);
    await loadGroupDetail(groupId);
    _checkPendingSync();
  }

  List<Debt> getDebtsForGroup(String groupId, {bool? forceSimplify}) {
    final simplify = forceSimplify ?? isSimplifyDebtsEnabled(groupId);
    final settlementGroups = _settlementGroups[groupId] ?? [];
    final bals = _balances[groupId];

    // If all members are settled up (all net balances 0.00), no payments needed!
    if (bals != null && bals.isNotEmpty && bals.values.every((b) => b.abs() < 0.01)) {
      return [];
    }

    if (simplify) {
      if (bals == null || bals.isEmpty) return [];
      return simplifyDebtsWithGroups(
        individualBalances: bals,
        settlementGroups: settlementGroups,
      );
    } else {
      final exps = _expenses[groupId] ?? [];
      final shares = _shares[groupId] ?? [];
      final setts = _settlements[groupId] ?? [];
      final raw = calculateDirectDebtsWithGroups(
        expenses: exps,
        shares: shares,
        settlements: setts,
        settlementGroups: settlementGroups,
      );
      return eliminateDebtCycles(raw);
    }
  }

  /// Calculates how many transactions are eliminated when Simplify Debts is turned ON.
  int getSavedPaymentsCount(String groupId) {
    final direct = getDebtsForGroup(groupId, forceSimplify: false);
    final simplified = getDebtsForGroup(groupId, forceSimplify: true);
    final diff = direct.length - simplified.length;
    return diff > 0 ? diff : 0;
  }

  /// Sends a push notification reminder to the debtor in [debt].
  Future<SettlementReminderStatus> sendSettlementReminder({
    required SplitGroup group,
    required Debt debt,
    required String fromName,
    required String toName,
  }) async {
    final groupMembers = getMembersForGroup(group.id);
    final recipient = groupMembers.cast<SplitMember?>().firstWhere(
          (m) => m?.id == debt.fromMemberId,
          orElse: () => null,
        );
    return SplitService.instance.sendSettlementReminder(
      groupId: group.id,
      groupName: group.name,
      fromMemberId: debt.fromMemberId,
      toMemberId: debt.toMemberId,
      fromName: fromName,
      toName: toName,
      amount: debt.amount,
      recipientUserId: recipient?.userId,
    );
  }
}
