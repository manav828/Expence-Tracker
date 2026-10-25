import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/split_models.dart';

class SplitService {
  static final SplitService instance = SplitService._();
  SplitService._();

  SupabaseClient get _db => Supabase.instance.client;
  static const _uuid = Uuid();

  // Groups
  Future<SplitGroup> createGroup({
    required String name,
    String? description,
    required String createdBy,
  }) async {
    final id = _uuid.v4();
    final inviteCode = _uuid.v4().substring(0, 8).toUpperCase();
    final group = SplitGroup(
      id: id, name: name, description: description,
      createdBy: createdBy, inviteCode: inviteCode, createdAt: DateTime.now(),
    );
    await _db.from('split_groups').insert(group.toMap());
    return group;
  }

  Future<List<SplitGroup>> getGroupsByIds(List<String> groupIds) async {
    if (groupIds.isEmpty) return [];
    final res = await _db.from('split_groups').select()
        .inFilter('id', groupIds).order('created_at', ascending: false);
    return (res as List).map((m) => SplitGroup.fromMap(m)).toList();
  }

  Future<SplitGroup?> getGroupByInviteCode(String code) async {
    final res = await _db.from('split_groups').select()
        .eq('invite_code', code.toUpperCase()).maybeSingle();
    if (res == null) return null;
    return SplitGroup.fromMap(res);
  }

  Future<SplitGroup?> getGroupById(String id) async {
    final res = await _db.from('split_groups').select().eq('id', id).maybeSingle();
    if (res == null) return null;
    return SplitGroup.fromMap(res);
  }

  Future<void> updateGroup(SplitGroup group) async {
    await _db.from('split_groups')
        .update({'name': group.name, 'description': group.description})
        .eq('id', group.id);
  }

  Future<void> deleteGroup(String groupId) async {
    final expenses = await _db.from('split_expenses').select('id').eq('group_id', groupId);
    for (final e in expenses as List) {
      await _db.from('split_shares').delete().eq('expense_id', e['id']);
    }
    await _db.from('split_expenses').delete().eq('group_id', groupId);
    await _db.from('settlements').delete().eq('group_id', groupId);
    await _db.from('split_members').delete().eq('group_id', groupId);
    await _db.from('split_groups').delete().eq('id', groupId);
  }

  // Members
  Future<SplitMember> addMember({required String groupId, required String name, String? phone}) async {
    final member = SplitMember(
      id: _uuid.v4(), groupId: groupId, name: name, phone: phone, joinedAt: DateTime.now(),
    );
    await _db.from('split_members').insert(member.toMap());
    return member;
  }

  Future<List<SplitMember>> getMembers(String groupId) async {
    final res = await _db.from('split_members').select()
        .eq('group_id', groupId).order('joined_at', ascending: true);
    return (res as List).map((m) => SplitMember.fromMap(m)).toList();
  }

  Future<void> removeMember(String memberId) async {
    await _db.from('split_shares').delete().eq('member_id', memberId);
    await _db.from('settlements').delete().eq('from_member_id', memberId);
    await _db.from('settlements').delete().eq('to_member_id', memberId);
    await _db.from('split_members').delete().eq('id', memberId);
  }

  Future<void> updateExpense({
    required String expenseId,
    required String title,
    required double totalAmount,
    required String paidByMemberId,
    required SplitType splitType,
    required Map<String, double> shares,
    String? category,
    String? note,
  }) async {
    await _db.from('split_expenses').update({
      'title': title,
      'total_amount': totalAmount,
      'paid_by_member_id': paidByMemberId,
      'split_type': splitType.name,
      'category': category,
      'note': note,
    }).eq('id', expenseId);

    await _db.from('split_shares').delete().eq('expense_id', expenseId);
    final sharesList = shares.entries.map((e) => SplitShare(
      id: _uuid.v4(), expenseId: expenseId, memberId: e.key, shareAmount: e.value,
    ).toMap()).toList();
    if (sharesList.isNotEmpty) {
      await _db.from('split_shares').insert(sharesList);
    }
  }

  Future<void> updateMemberName(String memberId, String newName) async {
    await _db.from('split_members').update({'name': newName}).eq('id', memberId);
  }

  // Expenses
  Future<SplitExpense> addExpense({
    required String groupId, required String title, required double totalAmount,
    required String paidByMemberId, required SplitType splitType,
    required Map<String, double> shares, String? category, String? note,
    required String addedByMemberId,
  }) async {
    final expense = SplitExpense(
      id: _uuid.v4(), groupId: groupId, title: title, totalAmount: totalAmount,
      paidByMemberId: paidByMemberId, splitType: splitType, category: category,
      note: note, addedByMemberId: addedByMemberId, createdAt: DateTime.now(),
    );
    await _db.from('split_expenses').insert(expense.toMap());
    final sharesList = shares.entries.map((e) => SplitShare(
      id: _uuid.v4(), expenseId: expense.id, memberId: e.key, shareAmount: e.value,
    ).toMap()).toList();
    if (sharesList.isNotEmpty) await _db.from('split_shares').insert(sharesList);
    return expense;
  }

  Future<List<SplitExpense>> getExpenses(String groupId) async {
    final res = await _db.from('split_expenses').select()
        .eq('group_id', groupId).order('created_at', ascending: false);
    return (res as List).map((m) => SplitExpense.fromMap(m)).toList();
  }

  Future<void> deleteExpense(String expenseId) async {
    await _db.from('split_shares').delete().eq('expense_id', expenseId);
    await _db.from('split_expenses').delete().eq('id', expenseId);
  }

  Future<List<SplitShare>> getSharesForExpense(String expenseId) async {
    final res = await _db.from('split_shares').select().eq('expense_id', expenseId);
    return (res as List).map((m) => SplitShare.fromMap(m)).toList();
  }

  Future<List<SplitShare>> getAllSharesForGroup(String groupId) async {
    final expenses = await _db.from('split_expenses').select('id').eq('group_id', groupId);
    final ids = (expenses as List).map((e) => e['id'] as String).toList();
    if (ids.isEmpty) return [];
    final res = await _db.from('split_shares').select().inFilter('expense_id', ids);
    return (res as List).map((m) => SplitShare.fromMap(m)).toList();
  }

  // Settlements
  Future<Settlement> recordSettlement({
    required String groupId, required String fromMemberId,
    required String toMemberId, required double amount, String? note,
  }) async {
    final s = Settlement(
      id: _uuid.v4(), groupId: groupId, fromMemberId: fromMemberId,
      toMemberId: toMemberId, amount: amount, settledAt: DateTime.now(), note: note,
    );
    await _db.from('settlements').insert(s.toMap());
    return s;
  }

  Future<List<Settlement>> getSettlements(String groupId) async {
    final res = await _db.from('settlements').select()
        .eq('group_id', groupId).order('settled_at', ascending: false);
    return (res as List).map((m) => Settlement.fromMap(m)).toList();
  }

  // Balance calculation
  Future<Map<String, double>> computeBalances(String groupId) async {
    final members = await getMembers(groupId);
    final expenses = await getExpenses(groupId);
    final settlements = await getSettlements(groupId);
    final shares = await getAllSharesForGroup(groupId);
    final balances = <String, double>{for (final m in members) m.id: 0.0};

    for (final exp in expenses) {
      balances[exp.paidByMemberId] = (balances[exp.paidByMemberId] ?? 0) + exp.totalAmount;
    }
    for (final share in shares) {
      balances[share.memberId] = (balances[share.memberId] ?? 0) - share.shareAmount;
    }
    for (final s in settlements) {
      balances[s.fromMemberId] = (balances[s.fromMemberId] ?? 0) + s.amount;
      balances[s.toMemberId] = (balances[s.toMemberId] ?? 0) - s.amount;
    }
    return balances;
  }
}
