import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_preference_service.dart';
import '../models/expense.dart';
import '../models/budget.dart';
import '../models/payment_reminder.dart';
import '../utils/expense_sync_reconciler.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static sqflite.Database? _database;

  static const List<String> defaultCategories = [
    'Food & Dining',
    'Shopping',
    'Transport',
    'Bills & Utilities',
    'Entertainment',
    'Health & Wellness',
    'Investment',
    'General',
  ];

  static const List<String> defaultIncomeCategories = [
    'Salary',
    'Freelance',
    'Investments',
    'Refund / Cashback',
    'Rental Income',
    'Gifts',
    'Other Income',
  ];

  static const List<String> defaultPaymentMethods = [
    'UPI',
    'Card',
    'Cash',
    'Transfer',
  ];

  // In-memory store for Web & test environments
  final List<Expense> _webExpenses = [];
  int _nextWebId = 1;
  final List<ExpenseDeleteTombstone> _webDeletedTombstones = [];
  String? _webHydratedUserId;
  final List<String> _webCategories = List<String>.from(defaultCategories);
  final List<String> _webIncomeCategories = List<String>.from(defaultIncomeCategories);
  final List<String> _webPaymentMethods = List<String>.from(defaultPaymentMethods);
  Future<void> _webBudgetOperation = Future.value();
  final List<PaymentReminder> _webReminders = [];

  SupabaseClient? get _supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  DatabaseService._init() {
    // Clean initial state: no dummy data
  }

  /// Clears local SQLite tables, Web in-memory stores, and user-scoped UI prefs
  /// on logout or account switch without wiping cloud Supabase data.
  Future<void> clearLocalDatabaseOnly() async {
    if (kIsWeb) {
      _webExpenses.clear();
      _nextWebId = 1;
      _webDeletedTombstones.clear();
      _webHydratedUserId = null;
      _webReminders.clear();
      _webCategories
        ..clear()
        ..addAll(defaultCategories);
      _webIncomeCategories
        ..clear()
        ..addAll(defaultIncomeCategories);
      _webPaymentMethods
        ..clear()
        ..addAll(defaultPaymentMethods);
    } else {
      try {
        final db = await instance.database;
        await db.delete('expenses');
        await db.delete('deleted_expense_tombstones');
        await db.delete('payment_reminders');
        await db.delete('budgets');
      } catch (e) {
        debugPrint('Local clearLocalDatabaseOnly error: $e');
      }
    }

    try {
      await StoragePreferenceService.clearSyncStateOnSignOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_categoryOrderPrefKey);
      await prefs.remove(_incomeCategoryOrderPrefKey);
      await prefs.remove(_paymentMethodOrderPrefKey);
      await prefs.remove('reminder_banner_dismissed_date');
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith('budget_safeguards_dismissed_')) {
          await prefs.remove(key);
        }
      }
    } catch (_) {}
  }

  Future<void> clearAllExpenses() async {
    final isCloud = await StoragePreferenceService.isCloud();
    final client = _supabaseClient;
    final currentUser = client?.auth.currentUser;
    if (isCloud && currentUser != null && client != null) {
      try {
        await client
            .from('user_expenses')
            .delete()
            .eq('user_id', currentUser.id);
        await StoragePreferenceService.setBackupDirty(currentUser.id, false);
        await StoragePreferenceService.setLastBackupAt(currentUser.id, DateTime.now());
      } catch (e) {
        debugPrint('Cloud clearAllExpenses error: $e');
      }
    }
    if (kIsWeb) {
      _webExpenses.clear();
      _webDeletedTombstones.clear();
      return;
    }
    final db = await instance.database;
    await db.delete('expenses');
    await db.delete('deleted_expense_tombstones');
  }

  Future<sqflite.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expenses.db');
    return _database!;
  }

  Future<sqflite.Database> _initDB(String filePath) async {
    final dbPath = await sqflite.getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await sqflite.openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onOpen: (db) async {
        await _ensureMetaTables(db);
      },
    );
  }

  Future _createDB(sqflite.Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          payment_method TEXT NOT NULL,
          comment TEXT,
          receipt_url TEXT,
          expense_date INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          type TEXT NOT NULL DEFAULT 'expense'
      )
    ''');
    await db.execute('CREATE INDEX idx_expense_date ON expenses(expense_date)');
    await db.execute('CREATE INDEX idx_category ON expenses(category)');
    await db.execute('CREATE INDEX idx_payment_method ON expenses(payment_method)');
    await db.execute('CREATE INDEX idx_expense_type ON expenses(type)');

    await _ensureMetaTables(db);
  }

  Future<void> _ensureMetaTables(sqflite.Database db) async {
    try {
      await db.execute('ALTER TABLE expenses ADD COLUMN user_id TEXT');
    } catch (_) {
      // Column already exists
    }
    try {
      await db.execute('ALTER TABLE expenses ADD COLUMN receipt_url TEXT');
    } catch (_) {
      // Column already exists
    }
    try {
      await db.execute("ALTER TABLE expenses ADD COLUMN type TEXT NOT NULL DEFAULT 'expense'");
    } catch (_) {
      // Column already exists
    }
    try {
      await db.execute('ALTER TABLE split_groups ADD COLUMN image_url TEXT');
    } catch (_) {
      // Column already exists
    }
    try {
      await db.execute('ALTER TABLE split_expenses ADD COLUMN receipt_url TEXT');
    } catch (_) {
      // Column already exists
    }
    try {
      await db.execute('ALTER TABLE split_groups ADD COLUMN user_id TEXT');
    } catch (_) {
      // Column already exists
    }
    try {
      await db.execute('ALTER TABLE split_members ADD COLUMN user_id TEXT');
    } catch (_) {
      // Column already exists
    }
    try {
      await db.execute('ALTER TABLE settlements ADD COLUMN from_settlement_group_id TEXT');
    } catch (_) {
      // Column already exists
    }
    try {
      await db.execute('ALTER TABLE settlements ADD COLUMN to_settlement_group_id TEXT');
    } catch (_) {
      // Column already exists
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS income_categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_methods (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category TEXT UNIQUE NOT NULL,
          monthly_limit REAL NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS deleted_expense_tombstones (
          created_at INTEGER PRIMARY KEY,
          cloud_id INTEGER,
          user_id TEXT,
          deleted_at INTEGER NOT NULL
      )
    ''');

    // Splitwise tables for offline persistence
    await db.execute('''
      CREATE TABLE IF NOT EXISTS split_groups (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          name TEXT NOT NULL,
          description TEXT,
          image_url TEXT,
          created_by TEXT NOT NULL,
          invite_code TEXT NOT NULL,
          created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS split_members (
          id TEXT PRIMARY KEY,
          group_id TEXT NOT NULL,
          user_id TEXT,
          name TEXT NOT NULL,
          phone TEXT,
          joined_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS split_expenses (
          id TEXT PRIMARY KEY,
          group_id TEXT NOT NULL,
          title TEXT NOT NULL,
          total_amount REAL NOT NULL,
          paid_by_member_id TEXT NOT NULL,
          split_type TEXT NOT NULL,
          category TEXT,
          note TEXT,
          receipt_url TEXT,
          added_by_member_id TEXT NOT NULL,
          created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS split_shares (
          id TEXT PRIMARY KEY,
          expense_id TEXT NOT NULL,
          member_id TEXT NOT NULL,
          share_amount REAL NOT NULL,
          is_settled INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settlements (
          id TEXT PRIMARY KEY,
          group_id TEXT NOT NULL,
          from_member_id TEXT NOT NULL,
          to_member_id TEXT NOT NULL,
          amount REAL NOT NULL,
          settled_at TEXT NOT NULL,
          note TEXT,
          from_settlement_group_id TEXT,
          to_settlement_group_id TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS split_expense_groups (
          id TEXT PRIMARY KEY,
          group_id TEXT NOT NULL,
          name TEXT NOT NULL,
          description TEXT,
          icon TEXT,
          created_by TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS split_expense_group_members (
          id TEXT PRIMARY KEY,
          expense_group_id TEXT NOT NULL,
          member_id TEXT NOT NULL,
          created_at TEXT NOT NULL,
          UNIQUE(expense_group_id, member_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS split_settlement_groups (
          id TEXT PRIMARY KEY,
          group_id TEXT NOT NULL,
          name TEXT NOT NULL,
          created_by TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS split_settlement_group_members (
          id TEXT PRIMARY KEY,
          group_id TEXT NOT NULL,
          settlement_group_id TEXT NOT NULL,
          member_id TEXT NOT NULL,
          created_at TEXT NOT NULL,
          UNIQUE(settlement_group_id, member_id),
          UNIQUE(group_id, member_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS split_sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action TEXT NOT NULL,
          table_name TEXT NOT NULL,
          record_id TEXT NOT NULL,
          payload TEXT,
          created_at INTEGER NOT NULL
      )
    ''');

    // Recurring & One-Time Payment Reminders table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_reminders (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          payment_method TEXT NOT NULL,
          frequency TEXT NOT NULL DEFAULT 'monthly',
          custom_interval_days INTEGER,
          due_day INTEGER,
          due_date INTEGER,
          next_due_date INTEGER NOT NULL,
          last_paid_date INTEGER,
          notified_day_before_at INTEGER,
          notified_due_day_at INTEGER,
          is_active INTEGER NOT NULL DEFAULT 1,
          is_completed INTEGER NOT NULL DEFAULT 0,
          split_group_id TEXT,
          split_type TEXT DEFAULT 'personal',
          split_target_member_id TEXT,
          notes TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_reminders_dashboard ON payment_reminders(is_active, is_completed, next_due_date ASC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_reminders_split ON payment_reminders(split_group_id)');

    final catCount = sqflite.Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM categories')) ?? 0;
    if (catCount == 0) {
      for (var cat in defaultCategories) {
        await db.insert(
          'categories',
          {'name': cat},
          conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
        );
      }
    }

    final incCount = sqflite.Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM income_categories')) ?? 0;
    if (incCount == 0) {
      for (var cat in defaultIncomeCategories) {
        await db.insert(
          'income_categories',
          {'name': cat},
          conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
        );
      }
    }

    final pmCount = sqflite.Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM payment_methods')) ?? 0;
    if (pmCount == 0) {
      for (var pm in defaultPaymentMethods) {
        await db.insert(
          'payment_methods',
          {'name': pm},
          conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
        );
      }
    }

    // Backfill any custom categories from existing expenses into meta tables so Native Android sees them
    try {
      await db.execute('''
        INSERT OR IGNORE INTO income_categories (name)
        SELECT DISTINCT TRIM(category) FROM expenses
        WHERE type = 'income' AND category IS NOT NULL AND TRIM(category) != ''
      ''');
    } catch (_) {}

    try {
      await db.execute('''
        INSERT OR IGNORE INTO categories (name)
        SELECT DISTINCT TRIM(category) FROM expenses
        WHERE (type IS NULL OR type != 'income') AND category IS NOT NULL AND TRIM(category) != ''
      ''');
    } catch (_) {}
  }

  Future<int>? _personalSyncLock;

  Future<List<ExpenseDeleteTombstone>> getPendingDeleteTombstones({String? userId}) async {
    if (kIsWeb) {
      return _webDeletedTombstones
          .where((t) => userId == null || t.userId == null || t.userId == userId)
          .toList();
    }
    try {
      final db = await instance.database;
      final res = userId != null
          ? await db.query(
              'deleted_expense_tombstones',
              where: 'user_id = ? OR user_id IS NULL',
              whereArgs: [userId],
            )
          : await db.query('deleted_expense_tombstones');
      return res.map((m) => ExpenseDeleteTombstone.fromMap(m)).toList();
    } catch (e) {
      debugPrint('getPendingDeleteTombstones error: $e');
      return [];
    }
  }

  Future<void> _recordDeleteTombstone(ExpenseDeleteTombstone tombstone) async {
    await _removeDeleteTombstones([tombstone.createdAt]);
    if (kIsWeb) {
      _webDeletedTombstones.add(tombstone);
      return;
    }
    try {
      final db = await instance.database;
      await db.insert(
        'deleted_expense_tombstones',
        tombstone.toMap(),
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('_recordDeleteTombstone error: $e');
    }
  }

  Future<void> _removeDeleteTombstones(Iterable<int> createdAts) async {
    final keys = createdAts.toSet();
    if (keys.isEmpty) return;
    if (kIsWeb) {
      _webDeletedTombstones.removeWhere((t) => keys.contains(t.createdAt));
      return;
    }
    try {
      final db = await instance.database;
      final placeholders = List.filled(keys.length, '?').join(',');
      await db.delete(
        'deleted_expense_tombstones',
        where: 'created_at IN ($placeholders)',
        whereArgs: keys.toList(),
      );
    } catch (e) {
      debugPrint('_removeDeleteTombstones error: $e');
    }
  }

  Future<Map<String, dynamic>> _executeWithSchemaFallback(
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload) op,
    Map<String, dynamic> payload,
  ) async {
    try {
      return await op(payload);
    } catch (err) {
      final errStr = err.toString().toLowerCase();
      if (errStr.contains('type') && payload.containsKey('type')) {
        final fallback = Map<String, dynamic>.from(payload)..remove('type');
        return await op(fallback);
      }
      if (errStr.contains('receipt_url') && payload.containsKey('receipt_url')) {
        final fallback = Map<String, dynamic>.from(payload)..remove('receipt_url');
        return await op(fallback);
      }
      rethrow;
    }
  }

  Future<Expense> _insertCloudExpense(
    SupabaseClient client,
    String userId,
    Expense expense,
  ) async {
    final map = expense.toMap()
      ..remove('id')
      ..['user_id'] = userId;
    final res = await _executeWithSchemaFallback(
      (p) => client.from('user_expenses').insert(p).select().single(),
      map,
    );
    return Expense.fromMap(res);
  }

  Future<int?> _updateCloudExpense(
    SupabaseClient client,
    String userId,
    Expense expense,
  ) async {
    final map = expense.toMap()
      ..remove('id')
      ..['user_id'] = userId;

    Future<List<dynamic>> runUpdate(Map<String, dynamic> payload, {required bool byId}) {
      if (byId && expense.id != null) {
        return client
            .from('user_expenses')
            .update(payload)
            .eq('id', expense.id!)
            .eq('user_id', userId)
            .select('id');
      }
      return client
          .from('user_expenses')
          .update(payload)
          .eq('created_at', expense.createdAt)
          .eq('user_id', userId)
          .select('id');
    }

    Future<List<dynamic>> withFallback(Map<String, dynamic> payload, {required bool byId}) async {
      try {
        return await runUpdate(payload, byId: byId);
      } catch (err) {
        final errStr = err.toString().toLowerCase();
        if (errStr.contains('type') && payload.containsKey('type')) {
          return await runUpdate(Map<String, dynamic>.from(payload)..remove('type'), byId: byId);
        }
        if (errStr.contains('receipt_url') && payload.containsKey('receipt_url')) {
          return await runUpdate(Map<String, dynamic>.from(payload)..remove('receipt_url'), byId: byId);
        }
        rethrow;
      }
    }

    List<dynamic> rows = [];
    if (expense.id != null) {
      rows = await withFallback(map, byId: true);
    }
    if (rows.isEmpty) {
      rows = await withFallback(map, byId: false);
    }
    if (rows.isEmpty) {
      final inserted = await _insertCloudExpense(client, userId, expense);
      return inserted.id;
    }
    final rawId = rows.first['id'];
    return rawId is num ? rawId.toInt() : int.tryParse(rawId.toString());
  }

  Future<void> _replaceLocalExpenseId(int createdAt, int? cloudId) async {
    if (cloudId == null) return;
    if (kIsWeb) {
      final idx = _webExpenses.indexWhere((e) => e.createdAt == createdAt);
      if (idx != -1 && _webExpenses[idx].id != cloudId) {
        _webExpenses[idx] = _webExpenses[idx].copyWith(id: cloudId);
      }
      return;
    }
    final db = await instance.database;
    await db.update(
      'expenses',
      {'id': cloudId},
      where: 'created_at = ?',
      whereArgs: [createdAt],
    );
  }

  Future<void> _upsertLocalExpense(Expense expense) async {
    if (kIsWeb) {
      final idx = _webExpenses.indexWhere((e) => e.createdAt == expense.createdAt);
      if (idx != -1) {
        _webExpenses[idx] = expense;
      } else {
        _webExpenses.add(expense);
      }
      return;
    }
    final db = await instance.database;
    final existing = await db.query(
      'expenses',
      columns: ['id'],
      where: 'created_at = ?',
      whereArgs: [expense.createdAt],
    );
    if (existing.isEmpty) {
      await db.insert(
        'expenses',
        expense.toMap(),
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    } else {
      await db.update(
        'expenses',
        expense.toMap(),
        where: 'created_at = ?',
        whereArgs: [expense.createdAt],
      );
    }
  }

  Future<Expense> insertExpense(Expense expense) async {
    await _removeDeleteTombstones([expense.createdAt]);

    Expense localSaved;
    if (kIsWeb) {
      localSaved = Expense(
        id: expense.id ?? _nextWebId++,
        userId: expense.userId,
        amount: expense.amount,
        category: expense.category,
        paymentMethod: expense.paymentMethod,
        comment: expense.comment,
        receiptUrl: expense.receiptUrl,
        expenseDate: expense.expenseDate,
        createdAt: expense.createdAt,
        updatedAt: expense.updatedAt,
        type: expense.type,
      );
      _webExpenses.add(localSaved);
    } else {
      final db = await instance.database;
      final id = await db.insert('expenses', expense.toMap());
      localSaved = expense.copyWith(id: id);
    }

    final isCloud = await StoragePreferenceService.isCloud();
    final client = _supabaseClient;
    final currentUser = client?.auth.currentUser;
    if (isCloud && currentUser != null && client != null) {
      await StoragePreferenceService.setBackupDirty(currentUser.id, true);
      final schedule = await StoragePreferenceService.getBackupSchedule();
      if (schedule == CloudBackupSchedule.onEveryChange) {
        try {
          final cloudExpense = await _insertCloudExpense(client, currentUser.id, localSaved);
          await _replaceLocalExpenseId(localSaved.createdAt, cloudExpense.id);
          await StoragePreferenceService.setHydratedUserId(currentUser.id);
          final pendingDeletes = await getPendingDeleteTombstones(userId: currentUser.id);
          if (pendingDeletes.isEmpty) {
            await StoragePreferenceService.setBackupDirty(currentUser.id, false);
            await StoragePreferenceService.setLastBackupAt(currentUser.id, DateTime.now());
          }
          return cloudExpense;
        } catch (e) {
          debugPrint('Cloud insert deferred to local queue: $e');
        }
      }
    }

    return localSaved;
  }

  /// Fast local path: retrieves all expenses directly from local SQLite or memory cache in <5ms.
  Future<List<Expense>> getLocalExpenses() async {
    if (kIsWeb) {
      final list = List<Expense>.from(_webExpenses);
      list.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
      return list;
    }
    try {
      final db = await instance.database;
      final result = await db.query('expenses', orderBy: 'expense_date DESC');
      return result.map((json) => Expense.fromMap(json)).toList();
    } catch (e) {
      debugPrint('Local SQLite query error in getLocalExpenses: $e');
      return [];
    }
  }

  Future<List<Expense>> getAllExpenses({bool forceCloudRefresh = false}) async {
    final localList = await getLocalExpenses();

    final isCloud = await StoragePreferenceService.isCloud();
    final client = _supabaseClient;
    final currentUser = client?.auth.currentUser;
    if (!isCloud || currentUser == null || client == null) {
      return localList;
    }

    final bool needsHydration;
    if (kIsWeb) {
      needsHydration = forceCloudRefresh || _webHydratedUserId != currentUser.id;
    } else {
      final hydrated = await StoragePreferenceService.isUserHydrated(currentUser.id);
      needsHydration = forceCloudRefresh || !hydrated;
    }

    if (!needsHydration) {
      return localList;
    }

    try {
      await syncAndReconcileCloud(pullFromCloud: true);
      return await getLocalExpenses();
    } catch (e) {
      debugPrint('Cloud hydration error, using local cache: $e');
      return localList;
    }
  }

  Future<int> updateExpense(Expense expense) async {
    await _removeDeleteTombstones([expense.createdAt]);

    int resultCount;
    if (kIsWeb) {
      final idx = _webExpenses.indexWhere(
        (e) => (expense.id != null && e.id == expense.id) || e.createdAt == expense.createdAt,
      );
      if (idx != -1) {
        _webExpenses[idx] = expense;
      } else {
        _webExpenses.add(expense);
      }
      resultCount = 1;
    } else {
      final db = await instance.database;
      resultCount = await db.update(
        'expenses',
        expense.toMap(),
        where: 'id = ? OR created_at = ?',
        whereArgs: [expense.id ?? -1, expense.createdAt],
      );
    }

    final isCloud = await StoragePreferenceService.isCloud();
    final client = _supabaseClient;
    final currentUser = client?.auth.currentUser;
    if (isCloud && currentUser != null && client != null) {
      await StoragePreferenceService.setBackupDirty(currentUser.id, true);
      final schedule = await StoragePreferenceService.getBackupSchedule();
      if (schedule == CloudBackupSchedule.onEveryChange) {
        try {
          final cloudId = await _updateCloudExpense(client, currentUser.id, expense);
          await _replaceLocalExpenseId(expense.createdAt, cloudId);
          final pendingDeletes = await getPendingDeleteTombstones(userId: currentUser.id);
          if (pendingDeletes.isEmpty) {
            await StoragePreferenceService.setBackupDirty(currentUser.id, false);
            await StoragePreferenceService.setLastBackupAt(currentUser.id, DateTime.now());
          }
        } catch (e) {
          debugPrint('Cloud updateExpense deferred to local queue: $e');
        }
      }
    }

    return resultCount;
  }

  Future<int> deleteExpense(int id, {int? createdAt}) async {
    int? resolvedCreatedAt = createdAt;
    int? resolvedCloudId = id > 0 ? id : null;

    if (resolvedCreatedAt == null) {
      if (kIsWeb) {
        for (final e in _webExpenses) {
          if (e.id == id) {
            resolvedCreatedAt = e.createdAt;
            resolvedCloudId = e.id ?? resolvedCloudId;
            break;
          }
        }
      } else {
        try {
          final db = await instance.database;
          final rows = await db.query(
            'expenses',
            columns: ['id', 'created_at'],
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );
          if (rows.isNotEmpty) {
            resolvedCreatedAt = (rows.first['created_at'] as num?)?.toInt();
            resolvedCloudId = (rows.first['id'] as num?)?.toInt() ?? resolvedCloudId;
          }
        } catch (_) {}
      }
    }

    int deletedCount;
    if (kIsWeb) {
      _webExpenses.removeWhere(
        (e) => e.id == id || (resolvedCreatedAt != null && e.createdAt == resolvedCreatedAt),
      );
      deletedCount = 1;
    } else {
      final db = await instance.database;
      deletedCount = await db.delete(
        'expenses',
        where: 'id = ? OR created_at = ?',
        whereArgs: [id, resolvedCreatedAt ?? -1],
      );
    }

    final isCloud = await StoragePreferenceService.isCloud();
    final client = _supabaseClient;
    final currentUser = client?.auth.currentUser;
    final hydratedUid = await StoragePreferenceService.getHydratedUserId();

    if ((isCloud || (currentUser != null && hydratedUid == currentUser.id)) &&
        resolvedCreatedAt != null) {
      final tombstone = ExpenseDeleteTombstone(
        createdAt: resolvedCreatedAt,
        cloudId: resolvedCloudId,
        userId: currentUser?.id,
        deletedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _recordDeleteTombstone(tombstone);
    }

    if (isCloud && currentUser != null && client != null) {
      await StoragePreferenceService.setBackupDirty(currentUser.id, true);
      final schedule = await StoragePreferenceService.getBackupSchedule();
      if (schedule == CloudBackupSchedule.onEveryChange) {
        try {
          final res = await client
              .from('user_expenses')
              .delete()
              .eq('id', id)
              .eq('user_id', currentUser.id)
              .select('id');
          if (res.isEmpty && resolvedCreatedAt != null) {
            await client
                .from('user_expenses')
                .delete()
                .eq('created_at', resolvedCreatedAt)
                .eq('user_id', currentUser.id);
          }
          if (resolvedCreatedAt != null) {
            await _removeDeleteTombstones([resolvedCreatedAt]);
          }
          final remaining = await getPendingDeleteTombstones(userId: currentUser.id);
          if (remaining.isEmpty) {
            await StoragePreferenceService.setBackupDirty(currentUser.id, false);
            await StoragePreferenceService.setLastBackupAt(currentUser.id, DateTime.now());
          }
        } catch (e) {
          debugPrint('Cloud deleteExpense queued via tombstone: $e');
        }
      }
    }

    return deletedCount;
  }

  /// Conflict-free 3-way personal-expense backup & hydration pass using
  /// delete tombstones and `updated_at` comparisons.
  Future<int> syncAndReconcileCloud({bool pullFromCloud = true}) async {
    final existing = _personalSyncLock;
    if (existing != null) return await existing;

    final future = _runSyncAndReconcileCloud(pullFromCloud: pullFromCloud);
    _personalSyncLock = future;
    try {
      return await future;
    } finally {
      _personalSyncLock = null;
    }
  }

  Future<int> _runSyncAndReconcileCloud({bool pullFromCloud = true}) async {
    final client = _supabaseClient;
    final currentUser = client?.auth.currentUser;
    if (client == null || currentUser == null) {
      debugPrint('syncAndReconcileCloud aborted: User is not authenticated or Supabase uninitialized.');
      return 0;
    }

    final localList = await getLocalExpenses();
    final res = await client
        .from('user_expenses')
        .select()
        .eq('user_id', currentUser.id)
        .order('expense_date', ascending: false);
    final cloudList = (res as List).map((m) => Expense.fromMap(m)).toList();
    final tombstones = await getPendingDeleteTombstones(userId: currentUser.id);

    final plan = ExpenseSyncReconciler.plan(
      localExpenses: localList,
      cloudExpenses: cloudList,
      tombstones: tombstones,
      allowCloudPull: pullFromCloud,
    );

    int syncedChanges = 0;

    // 1. Apply confirmed local deletes to cloud first so deleted rows never return
    final clearedTombstones = <int>[...plan.tombstoneCreatedAtsToClear];
    for (final tomb in plan.cloudDeletes) {
      await client
          .from('user_expenses')
          .delete()
          .eq('created_at', tomb.createdAt)
          .eq('user_id', currentUser.id);
      clearedTombstones.add(tomb.createdAt);
      syncedChanges++;
    }
    await _removeDeleteTombstones(clearedTombstones);

    // 2. Upload new local-only rows to cloud
    for (final exp in plan.toUploadToCloud) {
      final inserted = await _insertCloudExpense(client, currentUser.id, exp);
      await _replaceLocalExpenseId(exp.createdAt, inserted.id);
      syncedChanges++;
    }

    // 3. Push newer local edits to cloud
    for (final exp in plan.toUpdateInCloud) {
      final cloudId = await _updateCloudExpense(client, currentUser.id, exp);
      await _replaceLocalExpenseId(exp.createdAt, cloudId);
      syncedChanges++;
    }

    // 4. Mirror new or newer cloud entries into local SQLite / Web store
    for (final exp in plan.toInsertLocally) {
      await _upsertLocalExpense(exp);
      syncedChanges++;
    }
    for (final exp in plan.toUpdateLocally) {
      await _upsertLocalExpense(exp);
      syncedChanges++;
    }
    for (final exp in plan.localIdAlignments) {
      await _replaceLocalExpenseId(exp.createdAt, exp.id);
    }

    _webHydratedUserId = currentUser.id;
    await StoragePreferenceService.setHydratedUserId(currentUser.id);
    await StoragePreferenceService.setBackupDirty(currentUser.id, false);
    await StoragePreferenceService.setLastBackupAt(currentUser.id, DateTime.now());
    return syncedChanges;
  }

  /// Automatically backs up personal expenses when Weekly / 2-Weekly / Monthly
  /// schedule is due and local changes or delete tombstones exist.
  Future<bool> runScheduledBackupIfDue() async {
    final isCloud = await StoragePreferenceService.isCloud();
    final client = _supabaseClient;
    final currentUser = client?.auth.currentUser;
    if (!isCloud || currentUser == null || client == null) {
      return false;
    }

    final schedule = await StoragePreferenceService.getBackupSchedule();
    final isDirty = await StoragePreferenceService.isBackupDirty(currentUser.id);
    final tombstones = await getPendingDeleteTombstones(userId: currentUser.id);
    final hasPendingChanges = isDirty || tombstones.isNotEmpty;

    final bool shouldSync;
    if (schedule == CloudBackupSchedule.onEveryChange) {
      shouldSync = hasPendingChanges;
    } else {
      final lastBackupAt = await StoragePreferenceService.getLastBackupAt(currentUser.id);
      shouldSync = StoragePreferenceService.isScheduledBackupDue(
        schedule: schedule,
        lastBackupAt: lastBackupAt,
        hasPendingChanges: hasPendingChanges,
      );
    }

    if (!shouldSync) return false;

    try {
      await syncAndReconcileCloud(pullFromCloud: true);
      return true;
    } catch (e) {
      debugPrint('Scheduled personal backup failed safely (will retry): $e');
      return false;
    }
  }

  Future<int> syncLocalToCloud() async {
    try {
      return await syncAndReconcileCloud(pullFromCloud: true);
    } catch (e) {
      debugPrint('syncLocalToCloud error: $e');
      return 0;
    }
  }

  Future<int> syncCloudToLocal() async {
    try {
      return await syncAndReconcileCloud(pullFromCloud: true);
    } catch (e) {
      debugPrint('syncCloudToLocal error: $e');
      return 0;
    }
  }

  // --- Category Management ---
  static const String _categoryOrderPrefKey = 'custom_category_order_v1';
  static const String _paymentMethodOrderPrefKey = 'custom_payment_method_order_v1';

  Future<List<String>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList(_categoryOrderPrefKey);

    if (kIsWeb) {
      if (savedOrder != null && savedOrder.isNotEmpty) {
        _webCategories
          ..clear()
          ..addAll(savedOrder);
        return List<String>.from(_webCategories);
      }
      _webCategories
        ..clear()
        ..addAll(defaultCategories);
      await prefs.setStringList(_categoryOrderPrefKey, _webCategories);
      return List<String>.from(_webCategories);
    }

    List<String> rawList = [];
    try {
      final db = await instance.database;
      final res = await db.query('categories', orderBy: 'id ASC');
      rawList = res.map((e) => e['name'] as String).toList();

      // Ensure custom categories from expenses are captured & synced into categories table
      try {
        final expRes = await db.rawQuery(
          "SELECT DISTINCT TRIM(category) as name FROM expenses WHERE (type IS NULL OR type != 'income') AND category IS NOT NULL AND TRIM(category) != ''",
        );
        for (final row in expRes) {
          final catName = (row['name'] as String?)?.trim();
          if (catName != null && catName.isNotEmpty && !rawList.any((c) => c.toLowerCase() == catName.toLowerCase())) {
            rawList.add(catName);
            await db.insert(
              'categories',
              {'name': catName},
              conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
            );
          }
        }
      } catch (_) {}
    } catch (_) {
      rawList = List<String>.from(_webCategories);
    }

    if (savedOrder != null && savedOrder.isNotEmpty) {
      final ordered = <String>[];
      for (final item in savedOrder) {
        if (rawList.contains(item)) {
          ordered.add(item);
        }
      }
      for (final item in rawList) {
        if (!ordered.contains(item)) {
          ordered.add(item);
        }
      }
      return ordered;
    }

    return rawList;
  }

  Future<void> saveCategoryOrder(List<String> order) async {
    final cleanOrder = List<String>.from(order);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_categoryOrderPrefKey, cleanOrder);
    } catch (_) {}
    _webCategories
      ..clear()
      ..addAll(cleanOrder);
  }

  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (kIsWeb) {
      final current = await getCategories();
      if (!current.any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
        current.add(trimmed);
      }
      await saveCategoryOrder(current);
      return;
    }
    try {
      final db = await instance.database;
      await db.insert(
        'categories',
        {'name': trimmed},
        conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
      );
    } catch (_) {
      if (!_webCategories.any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
        _webCategories.add(trimmed);
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_categoryOrderPrefKey) ?? [];
      if (!savedOrder.any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
        savedOrder.add(trimmed);
        await prefs.setStringList(_categoryOrderPrefKey, savedOrder);
      }
    } catch (_) {}
  }

  Future<void> updateCategory(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return;
    if (kIsWeb) {
      final current = await getCategories();
      final idx = current.indexWhere((c) => c.toLowerCase() == oldName.toLowerCase());
      if (idx != -1) {
        current[idx] = trimmed;
      }
      await saveCategoryOrder(current);
      for (int i = 0; i < _webExpenses.length; i++) {
        if (_webExpenses[i].category.toLowerCase() == oldName.toLowerCase()) {
          _webExpenses[i] = Expense(
            id: _webExpenses[i].id,
            amount: _webExpenses[i].amount,
            category: trimmed,
            paymentMethod: _webExpenses[i].paymentMethod,
            comment: _webExpenses[i].comment,
            expenseDate: _webExpenses[i].expenseDate,
            createdAt: _webExpenses[i].createdAt,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
        }
      }
      return;
    }

    try {
      final db = await instance.database;
      await db.update('categories', {'name': trimmed}, where: 'name = ?', whereArgs: [oldName]);
      await db.update('expenses', {'category': trimmed}, where: 'category = ?', whereArgs: [oldName]);
    } catch (_) {
      final idx = _webCategories.indexWhere((c) => c.toLowerCase() == oldName.toLowerCase());
      if (idx != -1) {
        _webCategories[idx] = trimmed;
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_categoryOrderPrefKey) ?? [];
      final idx = savedOrder.indexWhere((c) => c.toLowerCase() == oldName.toLowerCase());
      if (idx != -1) {
        savedOrder[idx] = trimmed;
        await prefs.setStringList(_categoryOrderPrefKey, savedOrder);
      }
    } catch (_) {}
  }

  Future<void> deleteCategory(String name) async {
    if (kIsWeb) {
      final current = await getCategories();
      current.removeWhere((c) => c.toLowerCase() == name.toLowerCase());
      await saveCategoryOrder(current);
      return;
    }
    try {
      final db = await instance.database;
      await db.delete('categories', where: 'name = ?', whereArgs: [name]);
    } catch (_) {
      _webCategories.removeWhere((c) => c.toLowerCase() == name.toLowerCase());
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_categoryOrderPrefKey) ?? [];
      savedOrder.removeWhere((c) => c.toLowerCase() == name.toLowerCase());
      await prefs.setStringList(_categoryOrderPrefKey, savedOrder);
    } catch (_) {}
  }

  // --- Income Category Management ---
  static const String _incomeCategoryOrderPrefKey = 'custom_income_category_order_v1';

  Future<List<String>> getIncomeCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList(_incomeCategoryOrderPrefKey);

    if (kIsWeb) {
      if (savedOrder != null && savedOrder.isNotEmpty) {
        _webIncomeCategories
          ..clear()
          ..addAll(savedOrder);
        return List<String>.from(_webIncomeCategories);
      }
      _webIncomeCategories
        ..clear()
        ..addAll(defaultIncomeCategories);
      await prefs.setStringList(_incomeCategoryOrderPrefKey, _webIncomeCategories);
      return List<String>.from(_webIncomeCategories);
    }

    List<String> rawList = [];
    try {
      final db = await instance.database;
      final res = await db.query('income_categories', orderBy: 'id ASC');
      rawList = res.map((e) => e['name'] as String).toList();

      // Ensure custom income categories from expenses are captured & synced into income_categories table
      try {
        final expRes = await db.rawQuery(
          "SELECT DISTINCT TRIM(category) as name FROM expenses WHERE type = 'income' AND category IS NOT NULL AND TRIM(category) != ''",
        );
        for (final row in expRes) {
          final catName = (row['name'] as String?)?.trim();
          if (catName != null && catName.isNotEmpty && !rawList.any((c) => c.toLowerCase() == catName.toLowerCase())) {
            rawList.add(catName);
            await db.insert(
              'income_categories',
              {'name': catName},
              conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
            );
          }
        }
      } catch (_) {}
    } catch (_) {
      rawList = List<String>.from(_webIncomeCategories);
    }

    if (rawList.isEmpty) {
      rawList = List<String>.from(defaultIncomeCategories);
    }

    if (savedOrder != null && savedOrder.isNotEmpty) {
      final ordered = <String>[];
      for (final item in savedOrder) {
        if (rawList.contains(item)) {
          ordered.add(item);
        }
      }
      for (final item in rawList) {
        if (!ordered.contains(item)) {
          ordered.add(item);
        }
      }
      return ordered;
    }

    return rawList;
  }

  Future<void> saveIncomeCategoryOrder(List<String> order) async {
    final cleanOrder = List<String>.from(order);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_incomeCategoryOrderPrefKey, cleanOrder);
    } catch (_) {}
    _webIncomeCategories
      ..clear()
      ..addAll(cleanOrder);
  }

  Future<void> addIncomeCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (kIsWeb) {
      final current = await getIncomeCategories();
      if (!current.any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
        current.add(trimmed);
      }
      await saveIncomeCategoryOrder(current);
      return;
    }
    try {
      final db = await instance.database;
      await db.insert(
        'income_categories',
        {'name': trimmed},
        conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
      );
    } catch (_) {
      if (!_webIncomeCategories.any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
        _webIncomeCategories.add(trimmed);
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_incomeCategoryOrderPrefKey) ?? [];
      if (!savedOrder.any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
        savedOrder.add(trimmed);
        await prefs.setStringList(_incomeCategoryOrderPrefKey, savedOrder);
      }
    } catch (_) {}
  }

  Future<void> updateIncomeCategory(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return;
    if (kIsWeb) {
      final current = await getIncomeCategories();
      final idx = current.indexWhere((c) => c.toLowerCase() == oldName.toLowerCase());
      if (idx != -1) {
        current[idx] = trimmed;
      }
      await saveIncomeCategoryOrder(current);
      for (int i = 0; i < _webExpenses.length; i++) {
        if (_webExpenses[i].isIncome && _webExpenses[i].category.toLowerCase() == oldName.toLowerCase()) {
          _webExpenses[i] = Expense(
            id: _webExpenses[i].id,
            amount: _webExpenses[i].amount,
            category: trimmed,
            paymentMethod: _webExpenses[i].paymentMethod,
            comment: _webExpenses[i].comment,
            expenseDate: _webExpenses[i].expenseDate,
            createdAt: _webExpenses[i].createdAt,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            type: _webExpenses[i].type,
          );
        }
      }
      return;
    }

    try {
      final db = await instance.database;
      await db.update('income_categories', {'name': trimmed}, where: 'name = ?', whereArgs: [oldName]);
      await db.update('expenses', {'category': trimmed}, where: 'category = ? AND type = ?', whereArgs: [oldName, 'income']);
    } catch (_) {
      final idx = _webIncomeCategories.indexWhere((c) => c.toLowerCase() == oldName.toLowerCase());
      if (idx != -1) {
        _webIncomeCategories[idx] = trimmed;
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_incomeCategoryOrderPrefKey) ?? [];
      final idx = savedOrder.indexWhere((c) => c.toLowerCase() == oldName.toLowerCase());
      if (idx != -1) {
        savedOrder[idx] = trimmed;
        await prefs.setStringList(_incomeCategoryOrderPrefKey, savedOrder);
      }
    } catch (_) {}
  }

  Future<void> deleteIncomeCategory(String name) async {
    if (kIsWeb) {
      final current = await getIncomeCategories();
      current.removeWhere((c) => c.toLowerCase() == name.toLowerCase());
      await saveIncomeCategoryOrder(current);
      return;
    }
    try {
      final db = await instance.database;
      await db.delete('income_categories', where: 'name = ?', whereArgs: [name]);
    } catch (_) {
      _webIncomeCategories.removeWhere((c) => c.toLowerCase() == name.toLowerCase());
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_incomeCategoryOrderPrefKey) ?? [];
      savedOrder.removeWhere((c) => c.toLowerCase() == name.toLowerCase());
      await prefs.setStringList(_incomeCategoryOrderPrefKey, savedOrder);
    } catch (_) {}
  }

  // --- Payment Method Management ---
  Future<List<String>> getPaymentMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList(_paymentMethodOrderPrefKey);

    if (kIsWeb) {
      if (savedOrder != null && savedOrder.isNotEmpty) {
        _webPaymentMethods
          ..clear()
          ..addAll(savedOrder);
        return List<String>.from(_webPaymentMethods);
      }
      _webPaymentMethods
        ..clear()
        ..addAll(defaultPaymentMethods);
      await prefs.setStringList(_paymentMethodOrderPrefKey, _webPaymentMethods);
      return List<String>.from(_webPaymentMethods);
    }

    List<String> rawList = [];
    try {
      final db = await instance.database;
      final res = await db.query('payment_methods', orderBy: 'id ASC');
      rawList = res.map((e) => e['name'] as String).toList();
    } catch (_) {
      rawList = List<String>.from(_webPaymentMethods);
    }

    if (savedOrder != null && savedOrder.isNotEmpty) {
      final ordered = <String>[];
      for (final item in savedOrder) {
        if (rawList.contains(item)) {
          ordered.add(item);
        }
      }
      for (final item in rawList) {
        if (!ordered.contains(item)) {
          ordered.add(item);
        }
      }
      return ordered;
    }

    return rawList;
  }

  Future<void> savePaymentMethodOrder(List<String> order) async {
    final cleanOrder = List<String>.from(order);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_paymentMethodOrderPrefKey, cleanOrder);
    } catch (_) {}
    _webPaymentMethods
      ..clear()
      ..addAll(cleanOrder);
  }

  Future<void> addPaymentMethod(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (kIsWeb) {
      final current = await getPaymentMethods();
      if (!current.any((p) => p.toLowerCase() == trimmed.toLowerCase())) {
        current.add(trimmed);
      }
      await savePaymentMethodOrder(current);
      return;
    }
    try {
      final db = await instance.database;
      await db.insert(
        'payment_methods',
        {'name': trimmed},
        conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
      );
    } catch (_) {
      if (!_webPaymentMethods.any((p) => p.toLowerCase() == trimmed.toLowerCase())) {
        _webPaymentMethods.add(trimmed);
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_paymentMethodOrderPrefKey) ?? [];
      if (!savedOrder.any((p) => p.toLowerCase() == trimmed.toLowerCase())) {
        savedOrder.add(trimmed);
        await prefs.setStringList(_paymentMethodOrderPrefKey, savedOrder);
      }
    } catch (_) {}
  }

  Future<void> updatePaymentMethod(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return;
    if (kIsWeb) {
      final current = await getPaymentMethods();
      final idx = current.indexWhere((p) => p.toLowerCase() == oldName.toLowerCase());
      if (idx != -1) current[idx] = trimmed;
      await savePaymentMethodOrder(current);
      for (int i = 0; i < _webExpenses.length; i++) {
        if (_webExpenses[i].paymentMethod.toLowerCase() == oldName.toLowerCase()) {
          _webExpenses[i] = Expense(
            id: _webExpenses[i].id,
            amount: _webExpenses[i].amount,
            category: _webExpenses[i].category,
            paymentMethod: trimmed,
            comment: _webExpenses[i].comment,
            expenseDate: _webExpenses[i].expenseDate,
            createdAt: _webExpenses[i].createdAt,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
        }
      }
      return;
    }

    try {
      final db = await instance.database;
      await db.update('payment_methods', {'name': trimmed}, where: 'name = ?', whereArgs: [oldName]);
      await db.update('expenses', {'payment_method': trimmed}, where: 'payment_method = ?', whereArgs: [oldName]);
    } catch (_) {
      final idx = _webPaymentMethods.indexWhere((p) => p.toLowerCase() == oldName.toLowerCase());
      if (idx != -1) {
        _webPaymentMethods[idx] = trimmed;
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_paymentMethodOrderPrefKey) ?? [];
      final idx = savedOrder.indexWhere((p) => p.toLowerCase() == oldName.toLowerCase());
      if (idx != -1) {
        savedOrder[idx] = trimmed;
        await prefs.setStringList(_paymentMethodOrderPrefKey, savedOrder);
      }
    } catch (_) {}
  }

  Future<void> deletePaymentMethod(String name) async {
    if (kIsWeb) {
      final current = await getPaymentMethods();
      current.removeWhere((p) => p.toLowerCase() == name.toLowerCase());
      await savePaymentMethodOrder(current);
      return;
    }
    try {
      final db = await instance.database;
      await db.delete('payment_methods', where: 'name = ?', whereArgs: [name]);
    } catch (_) {
      _webPaymentMethods.removeWhere((p) => p.toLowerCase() == name.toLowerCase());
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_paymentMethodOrderPrefKey) ?? [];
      savedOrder.removeWhere((p) => p.toLowerCase() == name.toLowerCase());
      await prefs.setStringList(_paymentMethodOrderPrefKey, savedOrder);
    } catch (_) {}
  }

  // --- Budget Management ---
  Future<T> _withWebBudgets<T>(
    T Function(List<Budget>) operation, {
    bool save = false,
  }) {
    final userId = _supabaseClient?.auth.currentUser?.id;
    final key = 'web_budgets_${userId ?? 'guest'}';
    final result = _webBudgetOperation.then((_) async {
      final prefs = SharedPreferencesAsync();
      final stored = await prefs.getString(key);
      final budgets = stored == null
          ? <Budget>[]
          : (jsonDecode(stored) as List)
                .map((value) => Budget.fromMap(value as Map<String, dynamic>))
                .toList();
      final value = operation(budgets);
      if (save) {
        await prefs.setString(
          key,
          jsonEncode(budgets.map((budget) => budget.toMap()).toList()),
        );
      }
      return value;
    });
    _webBudgetOperation = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<List<Budget>> getBudgets() async {
    if (kIsWeb) {
      return _withWebBudgets(
        (budgets) => budgets..sort((a, b) => a.category.compareTo(b.category)),
      );
    }
    final db = await instance.database;
    final res = await db.query('budgets', orderBy: 'category ASC');
    return res.map((e) => Budget.fromMap(e)).toList();
  }

  Future<Budget> setBudget(String category, double monthlyLimit) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final trimmedCategory = category.trim();

    if (kIsWeb) {
      return _withWebBudgets((budgets) {
        final idx = budgets.indexWhere((b) => b.category == trimmedCategory);
        if (idx != -1) {
          final updated = budgets[idx].copyWith(
            monthlyLimit: monthlyLimit,
            updatedAt: now,
          );
          budgets[idx] = updated;
          return updated;
        }
        final id = budgets.fold(now - 1, (maxId, budget) {
          final existingId = budget.id ?? 0;
          return existingId > maxId ? existingId : maxId;
        }) + 1;
        final newBudget = Budget(
          id: id,
          category: trimmedCategory,
          monthlyLimit: monthlyLimit,
          createdAt: now,
          updatedAt: now,
        );
        budgets.add(newBudget);
        return newBudget;
      }, save: true);
    }

    final db = await instance.database;
    final existing = await db.query('budgets', where: 'category = ?', whereArgs: [trimmedCategory]);
    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      await db.update(
        'budgets',
        {'monthly_limit': monthlyLimit, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      return Budget(
        id: id,
        category: trimmedCategory,
        monthlyLimit: monthlyLimit,
        createdAt: existing.first['created_at'] as int,
        updatedAt: now,
      );
    } else {
      final id = await db.insert('budgets', {
        'category': trimmedCategory,
        'monthly_limit': monthlyLimit,
        'created_at': now,
        'updated_at': now,
      });
      return Budget(
        id: id,
        category: trimmedCategory,
        monthlyLimit: monthlyLimit,
        createdAt: now,
        updatedAt: now,
      );
    }
  }

  Future<int> deleteBudget(int id) async {
    if (kIsWeb) {
      return _withWebBudgets((budgets) {
        final count = budgets.length;
        budgets.removeWhere((b) => b.id == id);
        return count - budgets.length;
      }, save: true);
    }
    final db = await instance.database;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteBudgetByCategory(String category) async {
    if (kIsWeb) {
      return _withWebBudgets((budgets) {
        final count = budgets.length;
        budgets.removeWhere((b) => b.category == category);
        return count - budgets.length;
      }, save: true);
    }
    final db = await instance.database;
    return await db.delete('budgets', where: 'category = ?', whereArgs: [category]);
  }

  // ==============================================================================
  // PAYMENT REMINDERS (Offline SQLite + Supabase Cloud)
  // ==============================================================================

  Future<List<PaymentReminder>> getPaymentReminders({String? userId}) async {
    final isCloud = await StoragePreferenceService.isCloud();
    final client = _supabaseClient;
    final currentUser = client?.auth.currentUser;

    List<PaymentReminder> localList = [];
    if (!kIsWeb) {
      try {
        final db = await instance.database;
        final res = await db.query(
          'payment_reminders',
          orderBy: 'next_due_date ASC',
        );
        localList = res.map((m) => PaymentReminder.fromMap(m)).toList();
      } catch (e) {
        debugPrint('Local getPaymentReminders error: $e');
      }
    } else {
      localList = List.from(_webReminders);
      localList.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    }

    if (isCloud && currentUser != null && client != null) {
      try {
        final res = await client
            .from('payment_reminders')
            .select()
            .eq('user_id', currentUser.id)
            .order('next_due_date', ascending: true);
        final cloudList = (res as List).map((m) => PaymentReminder.fromMap(m)).toList();

        if (!kIsWeb) {
          final db = await instance.database;
          await db.delete('payment_reminders');
          if (cloudList.isNotEmpty) {
            final batch = db.batch();
            for (final rem in cloudList) {
              batch.insert(
                'payment_reminders',
                rem.toMap(),
                conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
              );
            }
            await batch.commit(noResult: true);
          }
        }

        if (kIsWeb) {
          _webReminders.clear();
          _webReminders.addAll(cloudList);
        }

        return cloudList;
      } catch (e) {
        debugPrint('Cloud getPaymentReminders error: $e');
      }
    }

    return localList;
  }

  Future<void> savePaymentReminder(PaymentReminder reminder) async {
    final isCloud = await StoragePreferenceService.isCloud();
    final client = _supabaseClient;
    final currentUser = client?.auth.currentUser;
    final payload = reminder.copyWith(userId: currentUser?.id ?? reminder.userId);

    if (kIsWeb) {
      _webReminders.removeWhere((r) => r.id == payload.id);
      _webReminders.add(payload);
    } else {
      try {
        final db = await instance.database;
        await db.insert(
          'payment_reminders',
          payload.toMap(),
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
        );
      } catch (e) {
        debugPrint('Local savePaymentReminder error: $e');
      }
    }

    if (isCloud && currentUser != null && client != null) {
      try {
        await client
            .from('payment_reminders')
            .upsert(payload.toMap());
      } catch (e) {
        debugPrint('Cloud savePaymentReminder error: $e');
      }
    }
  }

  Future<void> deletePaymentReminder(String id) async {
    final isCloud = await StoragePreferenceService.isCloud();
    final client = _supabaseClient;
    final currentUser = client?.auth.currentUser;

    if (kIsWeb) {
      _webReminders.removeWhere((r) => r.id == id);
    } else {
      try {
        final db = await instance.database;
        await db.delete('payment_reminders', where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        debugPrint('Local deletePaymentReminder error: $e');
      }
    }

    if (isCloud && currentUser != null && client != null) {
      try {
        await client
            .from('payment_reminders')
            .delete()
            .eq('id', id);
      } catch (e) {
        debugPrint('Cloud deletePaymentReminder error: $e');
      }
    }
  }

  Future<void> updateReminderNotificationTimestamps(
    String id, {
    int? dayBefore,
    int? dueDay,
  }) async {
    final updates = <String, dynamic>{};
    if (dayBefore != null) updates['notified_day_before_at'] = dayBefore;
    if (dueDay != null) updates['notified_due_day_at'] = dueDay;
    if (updates.isEmpty) return;

    if (!kIsWeb) {
      try {
        final db = await instance.database;
        await db.update('payment_reminders', updates, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        debugPrint('updateReminderNotificationTimestamps local error: $e');
      }
    } else {
      final idx = _webReminders.indexWhere((r) => r.id == id);
      if (idx != -1) {
        final r = _webReminders[idx];
        _webReminders[idx] = r.copyWith(
          notifiedDayBeforeAt: dayBefore != null ? DateTime.fromMillisecondsSinceEpoch(dayBefore) : null,
          notifiedDueDayAt: dueDay != null ? DateTime.fromMillisecondsSinceEpoch(dueDay) : null,
        );
      }
    }

    final isCloud = await StoragePreferenceService.isCloud();
    final client = _supabaseClient;
    final currentUser = client?.auth.currentUser;
    if (isCloud && currentUser != null && client != null) {
      try {
        await client
            .from('payment_reminders')
            .update(updates)
            .eq('id', id);
      } catch (e) {
        debugPrint('updateReminderNotificationTimestamps cloud error: $e');
      }
    }
  }
}
