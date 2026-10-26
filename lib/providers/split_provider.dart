import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/split_models.dart';
import '../services/split_service.dart';
import '../services/pixabay_service.dart';

class SplitProvider with ChangeNotifier {
  List<SplitGroup> _groups = [];
  final Map<String, List<SplitMember>> _members = {};
  final Map<String, List<SplitExpense>> _expenses = {};
  final Map<String, List<Settlement>> _settlements = {};
  final Map<String, Map<String, double>> _balances = {};
  bool _isLoading = false;
  bool _hasPendingSync = false;
  String? _error;
  String? _currentMemberName; // the name used by this device in groups

  static const _groupIdsKey = 'split_group_ids_v1';
  static const _memberNameKey = 'split_member_name_v1';

  List<SplitGroup> get groups => _groups;
  Map<String, List<SplitMember>> get members => _members;
  Map<String, List<SplitExpense>> get expenses => _expenses;
  Map<String, List<Settlement>> get settlements => _settlements;
  Map<String, Map<String, double>> get balances => _balances;
  bool get isLoading => _isLoading;
  bool get hasPendingSync => _hasPendingSync;
  String? get error => _error;
  String? get currentMemberName => _currentMemberName;

  List<SplitMember> getMembersForGroup(String groupId) => _members[groupId] ?? [];
  List<SplitExpense> getExpensesForGroup(String groupId) => _expenses[groupId] ?? [];
  List<Settlement> getSettlementsForGroup(String groupId) => _settlements[groupId] ?? [];
  Map<String, double> getBalancesForGroup(String groupId) => _balances[groupId] ?? {};

  SplitProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentMemberName = prefs.getString(_memberNameKey);
    await loadGroups();
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
      final ids = prefs.getStringList(_groupIdsKey) ?? [];
      if (ids.isEmpty) {
        _groups = [];
      } else {
        _groups = await SplitService.instance.getGroupsByIds(ids);
        await Future.wait(_groups.map((g) => loadGroupDetail(g.id)));
      }
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
    } catch (e) {
      if (!isBackgroundRefresh) {
        _error = e.toString();
      }
    }
    if (!isBackgroundRefresh) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadGroupDetail(String groupId) async {
    try {
      final members = await SplitService.instance.getMembers(groupId);
      final exps = await SplitService.instance.getExpenses(groupId);
      final setts = await SplitService.instance.getSettlements(groupId);
      final bals = await SplitService.instance.computeBalances(groupId);
      _members[groupId] = members;
      _expenses[groupId] = exps;
      _settlements[groupId] = setts;
      _balances[groupId] = bals;
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
    final finalImageUrl = imageUrl ??
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
    // Add creator as first member
    await SplitService.instance.addMember(groupId: group.id, name: createdByName);
    // Add other members
    for (final mn in memberNames) {
      if (mn.trim().isNotEmpty) {
        await SplitService.instance.addMember(groupId: group.id, name: mn.trim());
      }
    }
    // Save group id locally
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_groupIdsKey) ?? [];
    if (!ids.contains(group.id)) {
      ids.add(group.id);
      await prefs.setStringList(_groupIdsKey, ids);
    }
    _groups.insert(0, group);
    await loadGroupDetail(group.id);
    _checkPendingSync();
    notifyListeners();
    return group;
  }

  Future<SplitGroup?> joinGroupByInviteCode(String code, String memberName) async {
    final group = await SplitService.instance.getGroupByInviteCode(code);
    if (group == null) return null;
    // Add this user as member if not already present
    final existingMembers = await SplitService.instance.getMembers(group.id);
    final alreadyMember = existingMembers.any(
      (m) => m.name.toLowerCase().trim() == memberName.toLowerCase().trim(),
    );
    if (!alreadyMember) {
      await SplitService.instance.addMember(groupId: group.id, name: memberName);
    }
    // Save locally
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_groupIdsKey) ?? [];
    if (!ids.contains(group.id)) {
      ids.add(group.id);
      await prefs.setStringList(_groupIdsKey, ids);
      _groups.insert(0, group);
    }
    await loadGroupDetail(group.id);
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
    final ids = prefs.getStringList(_groupIdsKey) ?? [];
    ids.remove(groupId);
    await prefs.setStringList(_groupIdsKey, ids);
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
      addedByMemberId: addedByMemberId,
    );
    await loadGroupDetail(groupId);
    _checkPendingSync();
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
  }) async {
    await SplitService.instance.updateExpense(
      expenseId: expenseId,
      title: title,
      totalAmount: totalAmount,
      paidByMemberId: paidByMemberId,
      splitType: splitType,
      shares: shares,
      category: category,
      note: note,
    );
    await loadGroupDetail(groupId);
    _checkPendingSync();
  }

  Future<void> deleteExpense(String groupId, String expenseId) async {
    await SplitService.instance.deleteExpense(expenseId);
    await loadGroupDetail(groupId);
    _checkPendingSync();
  }

  Future<void> recordSettlement({
    required String groupId,
    required String fromMemberId,
    required String toMemberId,
    required double amount,
    String? note,
  }) async {
    await SplitService.instance.recordSettlement(
      groupId: groupId,
      fromMemberId: fromMemberId,
      toMemberId: toMemberId,
      amount: amount,
      note: note,
    );
    await loadGroupDetail(groupId);
    _checkPendingSync();
  }

  Future<void> addMember(String groupId, String name) async {
    await SplitService.instance.addMember(groupId: groupId, name: name);
    await loadGroupDetail(groupId);
    _checkPendingSync();
  }

  Future<void> removeMember(String groupId, String memberId) async {
    await SplitService.instance.removeMember(memberId);
    await loadGroupDetail(groupId);
    _checkPendingSync();
  }

  Future<List<SplitShare>> getSharesForExpense(String expenseId) async {
    return SplitService.instance.getSharesForExpense(expenseId);
  }

  List<Debt> getDebtsForGroup(String groupId) {
    final bals = _balances[groupId];
    if (bals == null || bals.isEmpty) return [];
    return simplifyDebts(bals);
  }
}
