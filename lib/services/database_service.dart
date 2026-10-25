import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_preference_service.dart';
import '../models/expense.dart';
import '../models/budget.dart';

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

  DatabaseService._init() {
    // Clean initial state: no dummy data
  }

  Future<void> clearAllExpenses() async {
    final isCloud = await StoragePreferenceService.isCloud();
    if (isCloud && Supabase.instance.client.auth.currentUser != null) {
      try {
        await Supabase.instance.client.from('user_expenses').delete().neq('id', 0);
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
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          payment_method TEXT NOT NULL,
          comment TEXT,
          expense_date INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_expense_date ON expenses(expense_date)');
    await db.execute('CREATE INDEX idx_category ON expenses(category)');
    await db.execute('CREATE INDEX idx_payment_method ON expenses(payment_method)');

    await _ensureMetaTables(db);
  }

  Future<void> _ensureMetaTables(sqflite.Database db) async {
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
    if (isCloud && Supabase.instance.client.auth.currentUser != null) {
      try {
        final client = Supabase.instance.client;
        final map = expense.toMap();
        map.remove('id');
        final res = await client.from('user_expenses').insert(map).select().single();
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
        expenseDate: expense.expenseDate,
        createdAt: expense.createdAt,
        updatedAt: expense.updatedAt,
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
      expenseDate: expense.expenseDate,
      createdAt: expense.createdAt,
      updatedAt: expense.updatedAt,
    );
  }

  Future<List<Expense>> getAllExpenses() async {
    final isCloud = await StoragePreferenceService.isCloud();
    if (isCloud && Supabase.instance.client.auth.currentUser != null) {
      try {
        final client = Supabase.instance.client;
        final res = await client.from('user_expenses').select().order('expense_date', ascending: false);
        final list = (res as List).map((m) => Expense.fromMap(m)).toList();
        return list;
      } catch (e) {
        debugPrint('Cloud getAllExpenses error, falling back to local: $e');
      }
    }

    if (kIsWeb) {
      final list = List<Expense>.from(_webExpenses);
      list.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
      return list;
    }

    final db = await instance.database;
    final result = await db.query('expenses', orderBy: 'expense_date DESC');
    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<int> updateExpense(Expense expense) async {
    final isCloud = await StoragePreferenceService.isCloud();
    if (isCloud && Supabase.instance.client.auth.currentUser != null && expense.id != null) {
      try {
        final client = Supabase.instance.client;
        final map = expense.toMap();
        map.remove('id');
        await client.from('user_expenses').update(map).eq('id', expense.id!);
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
    if (isCloud && Supabase.instance.client.auth.currentUser != null) {
      try {
        final client = Supabase.instance.client;
        await client.from('user_expenses').delete().eq('id', id);
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
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      debugPrint('syncLocalToCloud aborted: User is not authenticated.');
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
      final existingRes = await client.from('user_expenses').select('created_at, expense_date, amount, category');
      final existingSet = (existingRes as List).map((r) =>
        '${r['created_at']}_${r['expense_date']}_${(r['amount'] as num).toDouble()}_${r['category']}').toSet();

      for (final exp in localList) {
        final key = '${exp.createdAt}_${exp.expenseDate}_${exp.amount}_${exp.category}';
        if (existingSet.contains(key)) continue;

        final map = exp.toMap();
        map.remove('id');
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
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      debugPrint('syncCloudToLocal aborted: User is not authenticated.');
      return 0;
    }

    final res = await client.from('user_expenses').select();
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
}
