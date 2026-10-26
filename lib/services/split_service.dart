import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/split_models.dart';
import 'database_service.dart';

class SplitService {
  static final SplitService instance = SplitService._();
  SplitService._();

  SupabaseClient get _db => Supabase.instance.client;
  static const _uuid = Uuid();

  Future<sqflite.Database> get _localDb async => await DatabaseService.instance.database;

  // Internet check helper
  Future<bool> _isOnline() async {
    if (kIsWeb) return true;
    try {
      final res = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return res.isNotEmpty && res[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Sync Queue helper
  Future<void> _enqueue(String action, String tableName, String recordId, Map<String, dynamic>? payload) async {
    if (kIsWeb) return;
    try {
      final db = await _localDb;
      await db.insert('split_sync_queue', {
        'action': action,
        'table_name': tableName,
        'record_id': recordId,
        'payload': payload != null ? jsonEncode(payload) : null,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Split _enqueue error: $e');
    }
  }

  bool _isSyncing = false;

  /// Sync all pending offline operations to Supabase
  Future<int> syncPendingData() async {
    if (_isSyncing || kIsWeb) return 0;
    _isSyncing = true;
    int syncedCount = 0;
    try {
      final online = await _isOnline();
      if (!online) {
        _isSyncing = false;
        return 0;
      }

      final db = await _localDb;
      final queue = await db.query('split_sync_queue', orderBy: 'id ASC');
      for (final item in queue) {
        final id = item['id'] as int;
        final action = item['action'] as String;
        final table = item['table_name'] as String;
        final recordId = item['record_id'] as String;
        final payloadStr = item['payload'] as String?;
        final payload = payloadStr != null ? jsonDecode(payloadStr) as Map<String, dynamic> : null;

        try {
          if (action == 'INSERT' || action == 'UPSERT') {
            if (payload != null) {
              await _db.from(table).upsert(payload);
            }
          } else if (action == 'UPDATE') {
            if (payload != null) {
              await _db.from(table).update(payload).eq('id', recordId);
            }
          } else if (action == 'DELETE') {
            await _db.from(table).delete().eq('id', recordId);
          }
          await db.delete('split_sync_queue', where: 'id = ?', whereArgs: [id]);
          syncedCount++;
        } catch (e) {
          debugPrint('Failed to sync queue item $id ($table): $e');
          break; // Stop on first network error to preserve operation order
        }
      }
    } catch (e) {
      debugPrint('Split syncPendingData error: $e');
    } finally {
      _isSyncing = false;
    }
    return syncedCount;
  }

  /// Check if there are any pending offline items waiting to sync
  Future<bool> hasPendingSync() async {
    if (kIsWeb) return false;
    try {
      final db = await _localDb;
      final count = sqflite.Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM split_sync_queue'),
      ) ?? 0;
      return count > 0;
    } catch (_) {
      return false;
    }
  }

  // --- Groups ---

  Future<SplitGroup> createGroup({
    required String name,
    String? description,
    String? imageUrl,
    required String createdBy,
  }) async {
    final id = _uuid.v4();
    final inviteCode = _uuid.v4().substring(0, 8).toUpperCase();
    final group = SplitGroup(
      id: id,
      name: name,
      description: description,
      imageUrl: imageUrl,
      createdBy: createdBy,
      inviteCode: inviteCode,
      createdAt: DateTime.now(),
    );

    // Save locally
    if (!kIsWeb) {
      try {
        final db = await _localDb;
        await db.insert('split_groups', group.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      } catch (e) {
        debugPrint('Local createGroup error: $e');
      }
    }

    // Try cloud or queue
    try {
      await _db.from('split_groups').insert(group.toMap());
    } catch (e) {
      debugPrint('Cloud createGroup error, queued offline: $e');
      await _enqueue('INSERT', 'split_groups', group.id, group.toMap());
    }

    return group;
  }

  Future<List<SplitGroup>> getGroupsByIds(List<String> groupIds) async {
    if (groupIds.isEmpty) return [];

    List<SplitGroup> localGroups = [];
    if (!kIsWeb) {
      try {
        final db = await _localDb;
        final placeholders = List.filled(groupIds.length, '?').join(',');
        final res = await db.query(
          'split_groups',
          where: 'id IN ($placeholders)',
          whereArgs: groupIds,
          orderBy: 'created_at DESC',
        );
        localGroups = res.map((m) => SplitGroup.fromMap(m)).toList();
      } catch (e) {
        debugPrint('Split local getGroupsByIds error: $e');
      }
    }

    try {
      final res = await _db
          .from('split_groups')
          .select()
          .inFilter('id', groupIds)
          .order('created_at', ascending: false);
      final cloudGroups = (res as List).map((m) => SplitGroup.fromMap(m)).toList();

      if (!kIsWeb && cloudGroups.isNotEmpty) {
        final db = await _localDb;
        final batch = db.batch();
        for (final g in cloudGroups) {
          batch.insert('split_groups', g.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
      return cloudGroups;
    } catch (e) {
      debugPrint('Cloud getGroupsByIds error, returning local cached: $e');
    }

    return localGroups;
  }

  Future<SplitGroup?> getGroupByInviteCode(String code) async {
    try {
      final res = await _db
          .from('split_groups')
          .select()
          .eq('invite_code', code.toUpperCase())
          .maybeSingle();
      if (res != null) {
        final group = SplitGroup.fromMap(res);
        if (!kIsWeb) {
          final db = await _localDb;
          await db.insert('split_groups', group.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
        return group;
      }
    } catch (e) {
      debugPrint('Cloud getGroupByInviteCode error: $e');
    }

    if (!kIsWeb) {
      try {
        final db = await _localDb;
        final res = await db.query(
          'split_groups',
          where: 'UPPER(invite_code) = ?',
          whereArgs: [code.toUpperCase()],
          limit: 1,
        );
        if (res.isNotEmpty) return SplitGroup.fromMap(res.first);
      } catch (e) {
        debugPrint('Local getGroupByInviteCode error: $e');
      }
    }
    return null;
  }

  Future<SplitGroup?> getGroupById(String id) async {
    try {
      final res = await _db.from('split_groups').select().eq('id', id).maybeSingle();
      if (res != null) {
        final group = SplitGroup.fromMap(res);
        if (!kIsWeb) {
          final db = await _localDb;
          await db.insert('split_groups', group.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
        return group;
      }
    } catch (e) {
      debugPrint('Cloud getGroupById error: $e');
    }

    if (!kIsWeb) {
      try {
        final db = await _localDb;
        final res = await db.query('split_groups', where: 'id = ?', whereArgs: [id], limit: 1);
        if (res.isNotEmpty) return SplitGroup.fromMap(res.first);
      } catch (e) {
        debugPrint('Local getGroupById error: $e');
      }
    }
    return null;
  }

  Future<void> updateGroup(SplitGroup group) async {
    final updatePayload = {
      'name': group.name,
      'description': group.description,
      'image_url': group.imageUrl,
    };

    if (!kIsWeb) {
      try {
        final db = await _localDb;
        await db.update('split_groups', updatePayload, where: 'id = ?', whereArgs: [group.id]);
      } catch (e) {
        debugPrint('Local updateGroup error: $e');
      }
    }

    try {
      await _db.from('split_groups').update(updatePayload).eq('id', group.id);
    } catch (e) {
      debugPrint('Cloud updateGroup error, queued offline: $e');
      await _enqueue('UPDATE', 'split_groups', group.id, updatePayload);
    }
  }

  Future<void> deleteGroup(String groupId) async {
    if (!kIsWeb) {
      try {
        final db = await _localDb;
        final expenses = await db.query('split_expenses', columns: ['id'], where: 'group_id = ?', whereArgs: [groupId]);
        for (final e in expenses) {
          await db.delete('split_shares', where: 'expense_id = ?', whereArgs: [e['id']]);
        }
        await db.delete('split_expenses', where: 'group_id = ?', whereArgs: [groupId]);
        await db.delete('settlements', where: 'group_id = ?', whereArgs: [groupId]);
        await db.delete('split_members', where: 'group_id = ?', whereArgs: [groupId]);
        await db.delete('split_groups', where: 'id = ?', whereArgs: [groupId]);
      } catch (e) {
        debugPrint('Local deleteGroup error: $e');
      }
    }

    try {
      final expenses = await _db.from('split_expenses').select('id').eq('group_id', groupId);
      for (final e in expenses as List) {
        await _db.from('split_shares').delete().eq('expense_id', e['id']);
      }
      await _db.from('split_expenses').delete().eq('group_id', groupId);
      await _db.from('settlements').delete().eq('group_id', groupId);
      await _db.from('split_members').delete().eq('group_id', groupId);
      await _db.from('split_groups').delete().eq('id', groupId);
    } catch (e) {
      debugPrint('Cloud deleteGroup error, queued offline: $e');
      await _enqueue('DELETE', 'split_groups', groupId, null);
    }
  }

  // --- Members ---

  Future<SplitMember> addMember({required String groupId, required String name, String? phone}) async {
    final member = SplitMember(
      id: _uuid.v4(),
      groupId: groupId,
      name: name,
      phone: phone,
      joinedAt: DateTime.now(),
    );

    if (!kIsWeb) {
      try {
        final db = await _localDb;
        await db.insert('split_members', member.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      } catch (e) {
        debugPrint('Local addMember error: $e');
      }
    }

    try {
      await _db.from('split_members').insert(member.toMap());
    } catch (e) {
      debugPrint('Cloud addMember error, queued offline: $e');
      await _enqueue('INSERT', 'split_members', member.id, member.toMap());
    }
    return member;
  }

  Future<List<SplitMember>> getMembers(String groupId) async {
    List<SplitMember> localMembers = [];
    if (!kIsWeb) {
      try {
        final db = await _localDb;
        final res = await db.query(
          'split_members',
          where: 'group_id = ?',
          whereArgs: [groupId],
          orderBy: 'joined_at ASC',
        );
        localMembers = res.map((m) => SplitMember.fromMap(m)).toList();
      } catch (e) {
        debugPrint('Local getMembers error: $e');
      }
    }

    try {
      final res = await _db
          .from('split_members')
          .select()
          .eq('group_id', groupId)
          .order('joined_at', ascending: true);
      final cloudMembers = (res as List).map((m) => SplitMember.fromMap(m)).toList();
      if (!kIsWeb && cloudMembers.isNotEmpty) {
        final db = await _localDb;
        final batch = db.batch();
        for (final m in cloudMembers) {
          batch.insert('split_members', m.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
      return cloudMembers;
    } catch (e) {
      debugPrint('Cloud getMembers error, returning local cached: $e');
    }

    return localMembers;
  }

  Future<void> removeMember(String memberId) async {
    if (!kIsWeb) {
      try {
        final db = await _localDb;
        await db.delete('split_shares', where: 'member_id = ?', whereArgs: [memberId]);
        await db.delete('settlements', where: 'from_member_id = ? OR to_member_id = ?', whereArgs: [memberId, memberId]);
        await db.delete('split_members', where: 'id = ?', whereArgs: [memberId]);
      } catch (e) {
        debugPrint('Local removeMember error: $e');
      }
    }

    try {
      await _db.from('split_shares').delete().eq('member_id', memberId);
      await _db.from('settlements').delete().eq('from_member_id', memberId);
      await _db.from('settlements').delete().eq('to_member_id', memberId);
      await _db.from('split_members').delete().eq('id', memberId);
    } catch (e) {
      debugPrint('Cloud removeMember error, queued offline: $e');
      await _enqueue('DELETE', 'split_members', memberId, null);
    }
  }

  Future<void> updateMemberName(String memberId, String newName) async {
    final payload = {'name': newName};
    if (!kIsWeb) {
      try {
        final db = await _localDb;
        await db.update('split_members', payload, where: 'id = ?', whereArgs: [memberId]);
      } catch (e) {
        debugPrint('Local updateMemberName error: $e');
      }
    }
    try {
      await _db.from('split_members').update(payload).eq('id', memberId);
    } catch (e) {
      debugPrint('Cloud updateMemberName error, queued offline: $e');
      await _enqueue('UPDATE', 'split_members', memberId, payload);
    }
  }

  // --- Expenses ---

  Future<SplitExpense> addExpense({
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
    final expense = SplitExpense(
      id: _uuid.v4(),
      groupId: groupId,
      title: title,
      totalAmount: totalAmount,
      paidByMemberId: paidByMemberId,
      splitType: splitType,
      category: category,
      note: note,
      addedByMemberId: addedByMemberId,
      createdAt: DateTime.now(),
    );

    final sharesObjects = shares.entries.map((e) => SplitShare(
      id: _uuid.v4(),
      expenseId: expense.id,
      memberId: e.key,
      shareAmount: e.value,
    )).toList();

    // Save locally
    if (!kIsWeb) {
      try {
        final db = await _localDb;
        await db.insert('split_expenses', expense.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        final batch = db.batch();
        for (final s in sharesObjects) {
          batch.insert('split_shares', s.toSqliteMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      } catch (e) {
        debugPrint('Local addExpense error: $e');
      }
    }

    // Try cloud or queue
    try {
      await _db.from('split_expenses').insert(expense.toMap());
      final sharesList = sharesObjects.map((s) => s.toMap()).toList();
      if (sharesList.isNotEmpty) {
        await _db.from('split_shares').insert(sharesList);
      }
    } catch (e) {
      debugPrint('Cloud addExpense error, queued offline: $e');
      await _enqueue('INSERT', 'split_expenses', expense.id, expense.toMap());
      for (final s in sharesObjects) {
        await _enqueue('INSERT', 'split_shares', s.id, s.toMap());
      }
    }

    return expense;
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
    final updateData = {
      'title': title,
      'total_amount': totalAmount,
      'paid_by_member_id': paidByMemberId,
      'split_type': splitType.name,
      'category': category,
      'note': note,
    };

    final sharesObjects = shares.entries.map((e) => SplitShare(
      id: _uuid.v4(),
      expenseId: expenseId,
      memberId: e.key,
      shareAmount: e.value,
    )).toList();

    if (!kIsWeb) {
      try {
        final db = await _localDb;
        await db.update('split_expenses', updateData, where: 'id = ?', whereArgs: [expenseId]);
        await db.delete('split_shares', where: 'expense_id = ?', whereArgs: [expenseId]);
        final batch = db.batch();
        for (final s in sharesObjects) {
          batch.insert('split_shares', s.toSqliteMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      } catch (e) {
        debugPrint('Local updateExpense error: $e');
      }
    }

    try {
      await _db.from('split_expenses').update(updateData).eq('id', expenseId);
      await _db.from('split_shares').delete().eq('expense_id', expenseId);
      final sharesList = sharesObjects.map((s) => s.toMap()).toList();
      if (sharesList.isNotEmpty) {
        await _db.from('split_shares').insert(sharesList);
      }
    } catch (e) {
      debugPrint('Cloud updateExpense error, queued offline: $e');
      await _enqueue('UPDATE', 'split_expenses', expenseId, updateData);
      await _enqueue('DELETE', 'split_shares', expenseId, null);
      for (final s in sharesObjects) {
        await _enqueue('INSERT', 'split_shares', s.id, s.toMap());
      }
    }
  }

  Future<List<SplitExpense>> getExpenses(String groupId) async {
    List<SplitExpense> localExpenses = [];
    if (!kIsWeb) {
      try {
        final db = await _localDb;
        final res = await db.query(
          'split_expenses',
          where: 'group_id = ?',
          whereArgs: [groupId],
          orderBy: 'created_at DESC',
        );
        localExpenses = res.map((m) => SplitExpense.fromMap(m)).toList();
      } catch (e) {
        debugPrint('Local getExpenses error: $e');
      }
    }

    try {
      final res = await _db
          .from('split_expenses')
          .select()
          .eq('group_id', groupId)
          .order('created_at', ascending: false);
      final cloudExpenses = (res as List).map((m) => SplitExpense.fromMap(m)).toList();
      if (!kIsWeb && cloudExpenses.isNotEmpty) {
        final db = await _localDb;
        final batch = db.batch();
        for (final exp in cloudExpenses) {
          batch.insert('split_expenses', exp.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
      return cloudExpenses;
    } catch (e) {
      debugPrint('Cloud getExpenses error, returning local cached: $e');
    }

    return localExpenses;
  }

  Future<void> deleteExpense(String expenseId) async {
    if (!kIsWeb) {
      try {
        final db = await _localDb;
        await db.delete('split_shares', where: 'expense_id = ?', whereArgs: [expenseId]);
        await db.delete('split_expenses', where: 'id = ?', whereArgs: [expenseId]);
      } catch (e) {
        debugPrint('Local deleteExpense error: $e');
      }
    }

    try {
      await _db.from('split_shares').delete().eq('expense_id', expenseId);
      await _db.from('split_expenses').delete().eq('id', expenseId);
    } catch (e) {
      debugPrint('Cloud deleteExpense error, queued offline: $e');
      await _enqueue('DELETE', 'split_shares', expenseId, null);
      await _enqueue('DELETE', 'split_expenses', expenseId, null);
    }
  }

  Future<List<SplitShare>> getSharesForExpense(String expenseId) async {
    List<SplitShare> localShares = [];
    if (!kIsWeb) {
      try {
        final db = await _localDb;
        final res = await db.query(
          'split_shares',
          where: 'expense_id = ?',
          whereArgs: [expenseId],
        );
        localShares = res.map((m) => SplitShare.fromMap(m)).toList();
      } catch (e) {
        debugPrint('Local getSharesForExpense error: $e');
      }
    }

    try {
      final res = await _db.from('split_shares').select().eq('expense_id', expenseId);
      final cloudShares = (res as List).map((m) => SplitShare.fromMap(m)).toList();
      if (!kIsWeb && cloudShares.isNotEmpty) {
        final db = await _localDb;
        final batch = db.batch();
        for (final s in cloudShares) {
          batch.insert('split_shares', s.toSqliteMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
      return cloudShares;
    } catch (e) {
      debugPrint('Cloud getSharesForExpense error, returning local cached: $e');
    }

    return localShares;
  }

  Future<List<SplitShare>> getAllSharesForGroup(String groupId) async {
    List<SplitShare> localShares = [];
    if (!kIsWeb) {
      try {
        final db = await _localDb;
        final expenses = await db.query(
          'split_expenses',
          columns: ['id'],
          where: 'group_id = ?',
          whereArgs: [groupId],
        );
        final ids = expenses.map((e) => e['id'] as String).toList();
        if (ids.isNotEmpty) {
          final placeholders = List.filled(ids.length, '?').join(',');
          final res = await db.query(
            'split_shares',
            where: 'expense_id IN ($placeholders)',
            whereArgs: ids,
          );
          localShares = res.map((m) => SplitShare.fromMap(m)).toList();
        }
      } catch (e) {
        debugPrint('Local getAllSharesForGroup error: $e');
      }
    }

    try {
      final expenses = await _db.from('split_expenses').select('id').eq('group_id', groupId);
      final ids = (expenses as List).map((e) => e['id'] as String).toList();
      if (ids.isEmpty) return localShares;
      final res = await _db.from('split_shares').select().inFilter('expense_id', ids);
      final cloudShares = (res as List).map((m) => SplitShare.fromMap(m)).toList();
      if (!kIsWeb && cloudShares.isNotEmpty) {
        final db = await _localDb;
        final batch = db.batch();
        for (final s in cloudShares) {
          batch.insert('split_shares', s.toSqliteMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
      return cloudShares;
    } catch (e) {
      debugPrint('Cloud getAllSharesForGroup error, returning local cached: $e');
    }

    return localShares;
  }

  // --- Settlements ---

  Future<Settlement> recordSettlement({
    required String groupId,
    required String fromMemberId,
    required String toMemberId,
    required double amount,
    String? note,
  }) async {
    final s = Settlement(
      id: _uuid.v4(),
      groupId: groupId,
      fromMemberId: fromMemberId,
      toMemberId: toMemberId,
      amount: amount,
      settledAt: DateTime.now(),
      note: note,
    );

    if (!kIsWeb) {
      try {
        final db = await _localDb;
        await db.insert('settlements', s.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      } catch (e) {
        debugPrint('Local recordSettlement error: $e');
      }
    }

    try {
      await _db.from('settlements').insert(s.toMap());
    } catch (e) {
      debugPrint('Cloud recordSettlement error, queued offline: $e');
      await _enqueue('INSERT', 'settlements', s.id, s.toMap());
    }

    return s;
  }

  Future<List<Settlement>> getSettlements(String groupId) async {
    List<Settlement> localSettlements = [];
    if (!kIsWeb) {
      try {
        final db = await _localDb;
        final res = await db.query(
          'settlements',
          where: 'group_id = ?',
          whereArgs: [groupId],
          orderBy: 'settled_at DESC',
        );
        localSettlements = res.map((m) => Settlement.fromMap(m)).toList();
      } catch (e) {
        debugPrint('Local getSettlements error: $e');
      }
    }

    try {
      final res = await _db
          .from('settlements')
          .select()
          .eq('group_id', groupId)
          .order('settled_at', ascending: false);
      final cloudSettlements = (res as List).map((m) => Settlement.fromMap(m)).toList();
      if (!kIsWeb && cloudSettlements.isNotEmpty) {
        final db = await _localDb;
        final batch = db.batch();
        for (final sett in cloudSettlements) {
          batch.insert('settlements', sett.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
      return cloudSettlements;
    } catch (e) {
      debugPrint('Cloud getSettlements error, returning local cached: $e');
    }

    return localSettlements;
  }

  // --- Balance Calculation (pure math, 100% offline & local) ---

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
