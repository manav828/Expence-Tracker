import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_preference_service.dart';
import '../models/expense.dart';
import '../models/budget.dart';
import '../models/payment_reminder.dart';

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
    'Salary',
    'General',
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
  final List<String> _webCategories = List<String>.from(defaultCategories);
  final List<String> _webPaymentMethods = List<String>.from(defaultPaymentMethods);
  final List<Budget> _webBudgets = [];
  int _nextWebBudgetId = 1;
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

  /// Clears only local SQLite tables (or Web in-memory stores) for expenses and
  /// payment reminders on logout/switch-user without wiping cloud Supabase data.
  Future<void> clearLocalDatabaseOnly() async {
    if (kIsWeb) {
      _webExpenses.clear();
      _webReminders.clear();
      return;
    }
    try {
      final db = await instance.database;
      await db.delete('expenses');
      await db.delete('payment_reminders');
    } catch (e) {
      debugPrint('Local clearLocalDatabaseOnly error: $e');
    }
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
      } catch (e) {
        debugPrint('Cloud clearAllExpenses error: $e');
      }
    }
    if (kIsWeb) {
      _webExpenses.clear();
      return;
    }
    final db = await instance.database;
    await db.delete('expenses');
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
  }

  Future<Expense> insertExpense(Expense expense) async {
    final isCloud = await StoragePreferenceService.isCloud();
    final client = _supabaseClient;
    final currentUser = client?.auth.currentUser;
    if (isCloud && currentUser != null && client != null) {
      try {
        final map = expense.toMap();
        map.remove('id');
        map['user_id'] = currentUser.id;
        Map<String, dynamic> res;
        try {
          res = await client.from('user_expenses').insert(map).select().single();
        } catch (insertErr) {
          final errStr = insertErr.toString().toLowerCase();
          if (errStr.contains('type') && map.containsKey('type')) {
            debugPrint('type column missing on user_expenses table, retrying without type');
            final fallbackMap = Map<String, dynamic>.from(map)..remove('type');
            res = await client.from('user_expenses').insert(fallbackMap).select().single();
          } else if (errStr.contains('receipt_url') && map.containsKey('receipt_url')) {
            debugPrint('receipt_url column missing on user_expenses table, retrying without receipt_url');
            final fallbackMap = Map<String, dynamic>.from(map)..remove('receipt_url');
            res = await client.from('user_expenses').insert(fallbackMap).select().single();
          } else {
            rethrow;
          }
        }
        final cloudExpense = Expense.fromMap(res);
        if (kIsWeb) {
          _webExpenses.add(cloudExpense);
        } else {
          final db = await instance.database;
          await db.insert('expenses', cloudExpense.toMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
        return cloudExpense;
      } catch (e) {
        debugPrint('Cloud insert error, falling back to local: $e');
      }
    }

    if (kIsWeb) {
      final newExpense = Expense(
        id: _nextWebId++,
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
      _webExpenses.add(newExpense);
      return newExpense;
    }

    final db = await instance.database;
    final id = await db.insert('expenses', expense.toMap());
    return Expense(
      id: id,
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
  }

  Future<List<Expense>> getAllExpenses() async {
    // 1. Always read local SQLite first (safe, instant, zero data loss)
    List<Expense> localList = [];
    if (kIsWeb) {
      localList = List<Expense>.from(_webExpenses);
    } else {
      try {
        final db = await instance.database;
        final result = await db.query('expenses', orderBy: 'expense_date DESC');
        localList = result.map((json) => Expense.fromMap(json)).toList();
      } catch (e) {
        debugPrint('Local SQLite query error: $e');
      }
    }

    final isCloud = await StoragePreferenceService.isCloud();
    final client = _supabaseClient;
    final currentUser = client?.auth.currentUser;
    if (isCloud && currentUser != null && client != null) {
      try {
        // Query user's expenses or legacy entries with null user_id
        final res = await client
            .from('user_expenses')
            .select()
            .or('user_id.eq.${currentUser.id},user_id.is.null')
            .order('expense_date', ascending: false);
        final cloudList = (res as List).map((m) => Expense.fromMap(m)).toList();

        // If legacy rows had null user_id, claim them for this user
        if (cloudList.any((e) => e.userId == null)) {
          Future.microtask(() async {
            try {
              await client.from('user_expenses').update({'user_id': currentUser.id}).isFilter('user_id', null);
            } catch (_) {}
          });
        }

        // If cloud has entries, mirror to local SQLite and return cloud entries
        if (cloudList.isNotEmpty) {
          if (!kIsWeb) {
            _syncLocalAndCloudInBackground(currentUser.id, cloudList);
          }
          return cloudList;
        }

        // If cloud is empty but we have local expenses:
        // Return local expenses immediately so the user NEVER loses their view!
        // And automatically push them to Cloud in the background!
        if (localList.isNotEmpty) {
          Future.microtask(() async {
            try {
              await syncLocalToCloud();
            } catch (e) {
              debugPrint('Auto sync local to cloud error: $e');
            }
          });
          return localList;
        }
      } catch (e) {
        debugPrint('Cloud getAllExpenses error, falling back to local: $e');
      }
    }

    localList.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    return localList;
  }

  void _syncLocalAndCloudInBackground(String userId, List<Expense> cloudList) {
    if (kIsWeb) return;
    Future.microtask(() async {
      try {
        final db = await instance.database;

        // 1. Mirror all cloud entries into local SQLite cache
        final batch = db.batch();
        for (final exp in cloudList) {
          batch.insert(
            'expenses',
            exp.toMap(),
            conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);

        // 2. Mirror any offline-created local entries to cloud
        final localRes = await db.query('expenses');
        final localList = localRes.map((m) => Expense.fromMap(m)).toList();
        final cloudKeys = cloudList.map((r) =>
          '${r.createdAt}_${r.expenseDate}_${r.amount}_${r.category}').toSet();

        final client = _supabaseClient;
        if (client == null) return;
        for (final exp in localList) {
          final key = '${exp.createdAt}_${exp.expenseDate}_${exp.amount}_${exp.category}';
          if (!cloudKeys.contains(key)) {
            final map = exp.toMap();
            map.remove('id');
            map['user_id'] = userId;
            await client.from('user_expenses').insert(map);
            cloudKeys.add(key);
          }
        }
      } catch (e) {
        debugPrint('Background two-way mirror error: $e');
      }
    });
  }

  Future<int> updateExpense(Expense expense) async {
    final isCloud = await StoragePreferenceService.isCloud();
    final client = _supabaseClient;
    final currentUser = client?.auth.currentUser;
    if (isCloud && currentUser != null && client != null && expense.id != null) {
      try {
        final map = expense.toMap();
        map.remove('id');
        map['user_id'] = currentUser.id;
        try {
          await client
              .from('user_expenses')
              .update(map)
              .eq('id', expense.id!)
              .eq('user_id', currentUser.id);
        } catch (updateErr) {
          final errStr = updateErr.toString().toLowerCase();
          if (errStr.contains('type') && map.containsKey('type')) {
            debugPrint('type column missing on user_expenses table, updating without type');
            final fallbackMap = Map<String, dynamic>.from(map)..remove('type');
            await client
                .from('user_expenses')
                .update(fallbackMap)
                .eq('id', expense.id!)
                .eq('user_id', currentUser.id);
          } else if (errStr.contains('receipt_url') && map.containsKey('receipt_url')) {
            debugPrint('receipt_url column missing on user_expenses table, updating without receipt_url');
            final fallbackMap = Map<String, dynamic>.from(map)..remove('receipt_url');
            await client
                .from('user_expenses')
                .update(fallbackMap)
                .eq('id', expense.id!)
                .eq('user_id', currentUser.id);
          } else {
            rethrow;
          }
        }
      } catch (e) {
        debugPrint('Cloud updateExpense error: $e');
      }
    }

    if (kIsWeb) {
      final idx = _webExpenses.indexWhere((e) => e.id == expense.id);
      if (idx != -1) {
        _webExpenses[idx] = expense;
        return 1;
      }
      return 0;
    }

    final db = await instance.database;
    return db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final isCloud = await StoragePreferenceService.isCloud();
    final client = _supabaseClient;
    final currentUser = client?.auth.currentUser;
    if (isCloud && currentUser != null && client != null) {
      try {
        await client
            .from('user_expenses')
            .delete()
            .eq('id', id)
            .eq('user_id', currentUser.id);
      } catch (e) {
        debugPrint('Cloud deleteExpense error: $e');
      }
    }

    if (kIsWeb) {
      _webExpenses.removeWhere((e) => e.id == id);
      return 1;
    }

    final db = await instance.database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> syncLocalToCloud() async {
    final client = _supabaseClient;
    final currentUser = client?.auth.currentUser;
    if (client == null || currentUser == null) {
      debugPrint('syncLocalToCloud aborted: User is not authenticated or Supabase uninitialized.');
      return 0;
    }

    List<Expense> localList;
    if (kIsWeb) {
      localList = List<Expense>.from(_webExpenses);
    } else {
      final db = await instance.database;
      final res = await db.query('expenses');
      localList = res.map((m) => Expense.fromMap(m)).toList();
    }
    if (localList.isEmpty) return 0;

    int count = 0;
    try {
      final existingRes = await client
          .from('user_expenses')
          .select('created_at, expense_date, amount, category')
          .eq('user_id', currentUser.id);
      final existingSet = (existingRes as List).map((r) =>
        '${r['created_at']}_${r['expense_date']}_${(r['amount'] as num).toDouble()}_${r['category']}').toSet();

      for (final exp in localList) {
        final key = '${exp.createdAt}_${exp.expenseDate}_${exp.amount}_${exp.category}';
        if (existingSet.contains(key)) continue;

        final map = exp.toMap();
        map.remove('id');
        map['user_id'] = currentUser.id;
        await client.from('user_expenses').insert(map);
        existingSet.add(key);
        count++;
      }
    } catch (e) {
      debugPrint('syncLocalToCloud error: $e');
    }
    return count;
  }

  Future<int> syncCloudToLocal() async {
    final client = _supabaseClient;
    final currentUser = client?.auth.currentUser;
    if (client == null || currentUser == null) {
      debugPrint('syncCloudToLocal aborted: User is not authenticated or Supabase uninitialized.');
      return 0;
    }

    final res = await client
        .from('user_expenses')
        .select()
        .eq('user_id', currentUser.id);
    final cloudList = (res as List).map((m) => Expense.fromMap(m)).toList();
    if (cloudList.isEmpty) return 0;

    int imported = 0;
    if (kIsWeb) {
      for (final exp in cloudList) {
        final exists = _webExpenses.any((e) =>
          e.createdAt == exp.createdAt && e.amount == exp.amount && e.category == exp.category);
        if (!exists) {
          _webExpenses.add(exp);
          imported++;
        }
      }
    } else {
      final db = await instance.database;
      final localRes = await db.query('expenses');
      final localList = localRes.map((m) => Expense.fromMap(m)).toList();

      for (final exp in cloudList) {
        final exists = localList.any((e) =>
          e.createdAt == exp.createdAt && e.amount == exp.amount && e.category == exp.category);
        if (!exists) {
          final map = exp.toMap();
          map.remove('id');
          await db.insert('expenses', map);
          imported++;
        }
      }
    }
    return imported;
  }

  // --- Category Management ---
  static const String _categoryOrderPrefKey = 'custom_category_order_v1';
  static const String _paymentMethodOrderPrefKey = 'custom_payment_method_order_v1';

  Future<List<String>> getCategories() async {
    List<String> rawList;
    if (kIsWeb) {
      rawList = List<String>.from(_webCategories);
    } else {
      final db = await instance.database;
      final res = await db.query('categories', orderBy: 'id ASC');
      rawList = res.map((e) => e['name'] as String).toList();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_categoryOrderPrefKey);
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
    } catch (_) {}

    return rawList;
  }

  Future<void> saveCategoryOrder(List<String> order) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_categoryOrderPrefKey, order);
    } catch (_) {}
    if (kIsWeb) {
      _webCategories
        ..clear()
        ..addAll(order);
    }
  }

  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (kIsWeb) {
      if (!_webCategories.contains(trimmed)) _webCategories.add(trimmed);
      await saveCategoryOrder(_webCategories);
      return;
    }
    final db = await instance.database;
    await db.insert(
      'categories',
      {'name': trimmed},
      conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_categoryOrderPrefKey) ?? [];
      if (!savedOrder.contains(trimmed)) {
        savedOrder.add(trimmed);
        await prefs.setStringList(_categoryOrderPrefKey, savedOrder);
      }
    } catch (_) {}
  }

  Future<void> updateCategory(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return;
    if (kIsWeb) {
      final idx = _webCategories.indexOf(oldName);
      if (idx != -1) _webCategories[idx] = trimmed;
      await saveCategoryOrder(_webCategories);
      for (int i = 0; i < _webExpenses.length; i++) {
        if (_webExpenses[i].category == oldName) {
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

    final db = await instance.database;
    await db.update('categories', {'name': trimmed}, where: 'name = ?', whereArgs: [oldName]);
    await db.update('expenses', {'category': trimmed}, where: 'category = ?', whereArgs: [oldName]);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_categoryOrderPrefKey) ?? [];
      final idx = savedOrder.indexOf(oldName);
      if (idx != -1) {
        savedOrder[idx] = trimmed;
        await prefs.setStringList(_categoryOrderPrefKey, savedOrder);
      }
    } catch (_) {}
  }

  Future<void> deleteCategory(String name) async {
    if (kIsWeb) {
      _webCategories.remove(name);
      await saveCategoryOrder(_webCategories);
      return;
    }
    final db = await instance.database;
    await db.delete('categories', where: 'name = ?', whereArgs: [name]);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_categoryOrderPrefKey) ?? [];
      if (savedOrder.remove(name)) {
        await prefs.setStringList(_categoryOrderPrefKey, savedOrder);
      }
    } catch (_) {}
  }

  // --- Payment Method Management ---
  Future<List<String>> getPaymentMethods() async {
    List<String> rawList;
    if (kIsWeb) {
      rawList = List<String>.from(_webPaymentMethods);
    } else {
      final db = await instance.database;
      final res = await db.query('payment_methods', orderBy: 'id ASC');
      rawList = res.map((e) => e['name'] as String).toList();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_paymentMethodOrderPrefKey);
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
    } catch (_) {}

    return rawList;
  }

  Future<void> savePaymentMethodOrder(List<String> order) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_paymentMethodOrderPrefKey, order);
    } catch (_) {}
    if (kIsWeb) {
      _webPaymentMethods
        ..clear()
        ..addAll(order);
    }
  }

  Future<void> addPaymentMethod(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (kIsWeb) {
      if (!_webPaymentMethods.contains(trimmed)) _webPaymentMethods.add(trimmed);
      await savePaymentMethodOrder(_webPaymentMethods);
      return;
    }
    final db = await instance.database;
    await db.insert(
      'payment_methods',
      {'name': trimmed},
      conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_paymentMethodOrderPrefKey) ?? [];
      if (!savedOrder.contains(trimmed)) {
        savedOrder.add(trimmed);
        await prefs.setStringList(_paymentMethodOrderPrefKey, savedOrder);
      }
    } catch (_) {}
  }

  Future<void> updatePaymentMethod(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return;
    if (kIsWeb) {
      final idx = _webPaymentMethods.indexOf(oldName);
      if (idx != -1) _webPaymentMethods[idx] = trimmed;
      await savePaymentMethodOrder(_webPaymentMethods);
      for (int i = 0; i < _webExpenses.length; i++) {
        if (_webExpenses[i].paymentMethod == oldName) {
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

    final db = await instance.database;
    await db.update('payment_methods', {'name': trimmed}, where: 'name = ?', whereArgs: [oldName]);
    await db.update('expenses', {'payment_method': trimmed}, where: 'payment_method = ?', whereArgs: [oldName]);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_paymentMethodOrderPrefKey) ?? [];
      final idx = savedOrder.indexOf(oldName);
      if (idx != -1) {
        savedOrder[idx] = trimmed;
        await prefs.setStringList(_paymentMethodOrderPrefKey, savedOrder);
      }
    } catch (_) {}
  }

  Future<void> deletePaymentMethod(String name) async {
    if (kIsWeb) {
      _webPaymentMethods.remove(name);
      await savePaymentMethodOrder(_webPaymentMethods);
      return;
    }
    final db = await instance.database;
    await db.delete('payment_methods', where: 'name = ?', whereArgs: [name]);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_paymentMethodOrderPrefKey) ?? [];
      if (savedOrder.remove(name)) {
        await prefs.setStringList(_paymentMethodOrderPrefKey, savedOrder);
      }
    } catch (_) {}
  }

  // --- Budget Management ---
  Future<List<Budget>> getBudgets() async {
    if (kIsWeb) {
      final list = List<Budget>.from(_webBudgets);
      list.sort((a, b) => a.category.compareTo(b.category));
      return list;
    }
    final db = await instance.database;
    final res = await db.query('budgets', orderBy: 'category ASC');
    return res.map((e) => Budget.fromMap(e)).toList();
  }

  Future<Budget> setBudget(String category, double monthlyLimit) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final trimmedCategory = category.trim();

    if (kIsWeb) {
      final idx = _webBudgets.indexWhere((b) => b.category == trimmedCategory);
      if (idx != -1) {
        final updated = _webBudgets[idx].copyWith(
          monthlyLimit: monthlyLimit,
          updatedAt: now,
        );
        _webBudgets[idx] = updated;
        return updated;
      } else {
        final newBudget = Budget(
          id: _nextWebBudgetId++,
          category: trimmedCategory,
          monthlyLimit: monthlyLimit,
          createdAt: now,
          updatedAt: now,
        );
        _webBudgets.add(newBudget);
        return newBudget;
      }
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
      _webBudgets.removeWhere((b) => b.id == id);
      return 1;
    }
    final db = await instance.database;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteBudgetByCategory(String category) async {
    if (kIsWeb) {
      _webBudgets.removeWhere((b) => b.category == category);
      return 1;
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
            .order('next_due_date', ascending: true);
        final cloudList = (res as List).map((m) => PaymentReminder.fromMap(m)).toList();

        if (!kIsWeb && cloudList.isNotEmpty) {
          final db = await instance.database;
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

        if (kIsWeb) {
          _webReminders.clear();
          _webReminders.addAll(cloudList);
        }

        if (cloudList.isNotEmpty) {
          return cloudList;
        }
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
