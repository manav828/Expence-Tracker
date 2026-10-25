import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/expense.dart';
import '../models/search_filter.dart';
import '../services/database_service.dart';
import '../services/google_sheets_service.dart';

class ExpenseProvider with ChangeNotifier {
  List<Expense> _expenses = [];
  bool _isLoading = false;
  List<String> _categories = [];
  List<String> _paymentMethods = [];

  List<Expense> get expenses => _expenses;
  bool get isLoading => _isLoading;
  List<String> get categories => _categories;
  List<String> get paymentMethods => _paymentMethods;

  ExpenseProvider({bool autoFetch = true}) {
    if (autoFetch) {
      fetchExpenses();
    }
  }

  @visibleForTesting
  void setExpensesForTesting(List<Expense> list, {List<String>? categories}) {
    _expenses = List.from(list);
    if (categories != null) {
      _categories = List.from(categories);
    }
    notifyListeners();
  }

  Future<void> fetchExpenses({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }

    _expenses = await DatabaseService.instance.getAllExpenses();
    _categories = await DatabaseService.instance.getCategories();
    _paymentMethods = await DatabaseService.instance.getPaymentMethods();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> reloadForStorageMode() async {
    await fetchExpenses();
  }

  Future<int> syncLocalToCloud() async {
    final count = await DatabaseService.instance.syncLocalToCloud();
    await fetchExpenses();
    return count;
  }

  Future<int> syncCloudToLocal() async {
    final count = await DatabaseService.instance.syncCloudToLocal();
    await fetchExpenses();
    return count;
  }

  Future<void> addCategory(String name) async {
    await DatabaseService.instance.addCategory(name);
    _categories = await DatabaseService.instance.getCategories();
    notifyListeners();
  }

  Future<void> updateCategory(String oldName, String newName) async {
    await DatabaseService.instance.updateCategory(oldName, newName);
    _categories = await DatabaseService.instance.getCategories();
    _expenses = await DatabaseService.instance.getAllExpenses();
    notifyListeners();
  }

  Future<void> deleteCategory(String name) async {
    await DatabaseService.instance.deleteCategory(name);
    _categories = await DatabaseService.instance.getCategories();
    notifyListeners();
  }

  Future<void> addPaymentMethod(String name) async {
    await DatabaseService.instance.addPaymentMethod(name);
    _paymentMethods = await DatabaseService.instance.getPaymentMethods();
    notifyListeners();
  }

  Future<void> updatePaymentMethod(String oldName, String newName) async {
    await DatabaseService.instance.updatePaymentMethod(oldName, newName);
    _paymentMethods = await DatabaseService.instance.getPaymentMethods();
    _expenses = await DatabaseService.instance.getAllExpenses();
    notifyListeners();
  }

  Future<void> deletePaymentMethod(String name) async {
    await DatabaseService.instance.deletePaymentMethod(name);
    _paymentMethods = await DatabaseService.instance.getPaymentMethods();
    notifyListeners();
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _categories.length) return;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > _categories.length) newIndex = _categories.length;
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, item);
    notifyListeners();
    await DatabaseService.instance.saveCategoryOrder(_categories);
  }

  Future<void> reorderPaymentMethods(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _paymentMethods.length) return;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > _paymentMethods.length) newIndex = _paymentMethods.length;
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = _paymentMethods.removeAt(oldIndex);
    _paymentMethods.insert(newIndex, item);
    notifyListeners();
    await DatabaseService.instance.savePaymentMethodOrder(_paymentMethods);
  }

  Future<void> setCustomCategoryOrder(List<String> newOrder) async {
    _categories = List<String>.from(newOrder);
    notifyListeners();
    await DatabaseService.instance.saveCategoryOrder(_categories);
  }

  Future<void> setCustomPaymentMethodOrder(List<String> newOrder) async {
    _paymentMethods = List<String>.from(newOrder);
    notifyListeners();
    await DatabaseService.instance.savePaymentMethodOrder(_paymentMethods);
  }

  int getCategoryUsageCount(String category) {
    final lower = category.toLowerCase().trim();
    return _expenses.where((e) => e.category.toLowerCase().trim() == lower).length;
  }

  int getPaymentMethodUsageCount(String method) {
    final lower = method.toLowerCase().trim();
    return _expenses.where((e) => e.paymentMethod.toLowerCase().trim() == lower).length;
  }

  List<String> getSortedCategories({bool mostUsedFirst = true}) {
    final list = List<String>.from(_categories);
    final countMap = <String, int>{};
    for (var c in list) {
      countMap[c] = getCategoryUsageCount(c);
    }
    list.sort((a, b) {
      final countA = countMap[a] ?? 0;
      final countB = countMap[b] ?? 0;
      if (mostUsedFirst) {
        final diff = countB.compareTo(countA);
        return diff != 0 ? diff : a.toLowerCase().compareTo(b.toLowerCase());
      } else {
        final diff = countA.compareTo(countB);
        return diff != 0 ? diff : a.toLowerCase().compareTo(b.toLowerCase());
      }
    });
    return list;
  }

  List<String> getSortedPaymentMethods({bool mostUsedFirst = true}) {
    final list = List<String>.from(_paymentMethods);
    final countMap = <String, int>{};
    for (var m in list) {
      countMap[m] = getPaymentMethodUsageCount(m);
    }
    list.sort((a, b) {
      final countA = countMap[a] ?? 0;
      final countB = countMap[b] ?? 0;
      if (mostUsedFirst) {
        final diff = countB.compareTo(countA);
        return diff != 0 ? diff : a.toLowerCase().compareTo(b.toLowerCase());
      } else {
        final diff = countA.compareTo(countB);
        return diff != 0 ? diff : a.toLowerCase().compareTo(b.toLowerCase());
      }
    });
    return list;
  }

  static const MethodChannel _widgetChannel = MethodChannel('com.manav.expense/widget');

  void _notifyWidgetUpdate() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        _widgetChannel.invokeMethod('updateWidget');
      } catch (_) {}
    }
  }

  Future<void> addExpense(Expense expense) async {
    final newExpense = await DatabaseService.instance.insertExpense(expense);
    _expenses.insert(0, newExpense);
    
    // Maintain descending date order
    _expenses.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    notifyListeners();
    _notifyWidgetUpdate();

    // Trigger cloud sync in background
    GoogleSheetsService.instance.syncExpenseIfEnabled(newExpense);
  }

  Future<Map<String, dynamic>> syncAllToGoogleSheets() async {
    return await GoogleSheetsService.instance.syncAllExpenses(_expenses);
  }

  Future<void> updateExpense(Expense expense) async {
    await DatabaseService.instance.updateExpense(expense);
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index != -1) {
      _expenses[index] = expense;
      _expenses.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
      notifyListeners();
      _notifyWidgetUpdate();
    }
  }

  Future<void> deleteExpense(int id) async {
    await DatabaseService.instance.deleteExpense(id);
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
    _notifyWidgetUpdate();
  }

  Future<void> clearAll() async {
    await DatabaseService.instance.clearAllExpenses();
    _expenses.clear();
    notifyListeners();
    _notifyWidgetUpdate();
  }

  // --- Analytics Helpers ---

  double get totalExpenses {
    return _expenses.fold(0.0, (sum, item) => sum + item.amount);
  }

  Map<String, double> get categoryTotals {
    final map = <String, double>{};
    for (var e in _expenses) {
      map[e.category] = (map[e.category] ?? 0.0) + e.amount;
    }
    return map;
  }

  double get expensesThisMonth {
    final now = DateTime.now();
    return _expenses.where((e) {
      final d = e.dateTime;
      return d.year == now.year && d.month == now.month;
    }).fold(0.0, (sum, item) => sum + item.amount);
  }

  double get expensesThisWeek {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _expenses
        .where((e) => e.dateTime.isAfter(weekAgo))
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get expensesToday {
    final now = DateTime.now();
    return _expenses.where((e) {
      final d = e.dateTime;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).fold(0.0, (sum, item) => sum + item.amount);
  }

  List<double> getWeeklySpendByDay() {
    final now = DateTime.now();
    // Monday of current week
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final result = List<double>.filled(7, 0.0);
    for (var e in _expenses) {
      final d = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
      final diff = d.difference(monday).inDays;
      if (diff >= 0 && diff < 7) {
        result[diff] += e.amount;
      }
    }
    return result;
  }

  Map<int, double> getDailyTotalsForMonth(int year, int month) {
    final map = <int, double>{};
    for (var e in _expenses) {
      final d = e.dateTime;
      if (d.year == year && d.month == month) {
        map[d.day] = (map[d.day] ?? 0.0) + e.amount;
      }
    }
    return map;
  }

  List<Expense> getExpensesForMonth(int year, int month) {
    return _expenses.where((e) {
      final d = e.dateTime;
      return d.year == year && d.month == month;
    }).toList();
  }

  double getTotalExpensesForMonth(int year, int month) {
    double sum = 0.0;
    for (var e in _expenses) {
      final d = e.dateTime;
      if (d.year == year && d.month == month) {
        sum += e.amount;
      }
    }
    return sum;
  }

  Map<String, double> getCategoryTotalsForMonth(int year, int month) {
    final map = <String, double>{};
    for (var e in _expenses) {
      final d = e.dateTime;
      if (d.year == year && d.month == month) {
        map[e.category] = (map[e.category] ?? 0.0) + e.amount;
      }
    }
    return map;
  }

  List<Expense> getExpensesForDate(DateTime date) {
    return _expenses.where((e) {
      final d = e.dateTime;
      return d.year == date.year && d.month == date.month && d.day == date.day;
    }).toList();
  }

  /// Advanced Search & Filtering engine
  List<Expense> searchExpenses(SearchFilter filter) {
    final now = DateTime.now();
    DateTime? filterStart;
    DateTime? filterEnd;

    switch (filter.datePreset) {
      case DateRangePreset.all:
        break;
      case DateRangePreset.today:
        filterStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
        filterEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case DateRangePreset.thisWeek:
        final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        filterStart = DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
        filterEnd = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999);
        break;
      case DateRangePreset.thisMonth:
        filterStart = DateTime(now.year, now.month, 1, 0, 0, 0);
        filterEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        break;
      case DateRangePreset.last30Days:
        final startDay = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
        filterStart = DateTime(startDay.year, startDay.month, startDay.day, 0, 0, 0);
        filterEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case DateRangePreset.custom:
        if (filter.customStartDate != null) {
          filterStart = DateTime(
            filter.customStartDate!.year,
            filter.customStartDate!.month,
            filter.customStartDate!.day,
            0,
            0,
            0,
          );
        }
        if (filter.customEndDate != null) {
          filterEnd = DateTime(
            filter.customEndDate!.year,
            filter.customEndDate!.month,
            filter.customEndDate!.day,
            23,
            59,
            59,
            999,
          );
        }
        break;
    }

    final query = filter.query.trim().toLowerCase();

    final results = _expenses.where((e) {
      // 1. Full-text search
      if (query.isNotEmpty) {
        final matchesCategory = e.category.toLowerCase().contains(query);
        final matchesComment = e.comment?.toLowerCase().contains(query) ?? false;
        final matchesPayment = e.paymentMethod.toLowerCase().contains(query);
        final matchesAmount = e.amount.toString().contains(query);
        if (!matchesCategory && !matchesComment && !matchesPayment && !matchesAmount) {
          return false;
        }
      }

      // 2. Date filtering
      if (filterStart != null && e.dateTime.isBefore(filterStart)) {
        return false;
      }
      if (filterEnd != null && e.dateTime.isAfter(filterEnd)) {
        return false;
      }

      // 3. Category filtering
      if (filter.categories.isNotEmpty && !filter.categories.contains(e.category)) {
        return false;
      }

      // 4. Payment method filtering
      if (filter.paymentMethods.isNotEmpty && !filter.paymentMethods.contains(e.paymentMethod)) {
        return false;
      }

      // 5. Amount range filtering
      if (filter.minAmount != null && e.amount < filter.minAmount!) {
        return false;
      }
      if (filter.maxAmount != null && e.amount > filter.maxAmount!) {
        return false;
      }

      return true;
    }).toList();

    // Sorting
    switch (filter.sortBy) {
      case ExpenseSortOption.dateDesc:
        results.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
        break;
      case ExpenseSortOption.dateAsc:
        results.sort((a, b) => a.expenseDate.compareTo(b.expenseDate));
        break;
      case ExpenseSortOption.amountDesc:
        results.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case ExpenseSortOption.amountAsc:
        results.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }

    return results;
  }

  // --- Category Detail Helpers ---

  /// Get expenses for a specific category within a date range
  List<Expense> getExpensesForCategory(String category, DateTime start, DateTime end) {
    final lower = category.toLowerCase().trim();
    return _expenses.where((e) {
      if (e.category.toLowerCase().trim() != lower) return false;
      final d = e.dateTime;
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList()
      ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
  }

  /// Daily totals for a category in a specific month → {day: total}
  Map<int, double> getCategoryDailyTotals(String category, int year, int month) {
    final lower = category.toLowerCase().trim();
    final map = <int, double>{};
    for (var e in _expenses) {
      final d = e.dateTime;
      if (e.category.toLowerCase().trim() == lower && d.year == year && d.month == month) {
        map[d.day] = (map[d.day] ?? 0.0) + e.amount;
      }
    }
    return map;
  }

  /// Weekly totals for a category (current week, Mon=0 .. Sun=6)
  List<double> getCategoryWeeklyTotals(String category) {
    final lower = category.toLowerCase().trim();
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final result = List<double>.filled(7, 0.0);
    for (var e in _expenses) {
      if (e.category.toLowerCase().trim() != lower) continue;
      final d = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
      final diff = d.difference(monday).inDays;
      if (diff >= 0 && diff < 7) {
        result[diff] += e.amount;
      }
    }
    return result;
  }

  /// Monthly totals for a category in a year → {month: total}
  Map<int, double> getCategoryMonthlyTotals(String category, int year) {
    final lower = category.toLowerCase().trim();
    final map = <int, double>{};
    for (var e in _expenses) {
      final d = e.dateTime;
      if (e.category.toLowerCase().trim() == lower && d.year == year) {
        map[d.month] = (map[d.month] ?? 0.0) + e.amount;
      }
    }
    return map;
  }

  /// Totals for a category over the last N months → {monthOffset: total}
  /// monthOffset 0 = current month, 1 = last month, 2 = two months ago
  Map<int, double> getCategoryRecentMonthsTotals(String category, int monthCount) {
    final lower = category.toLowerCase().trim();
    final now = DateTime.now();
    final map = <int, double>{};
    for (int i = 0; i < monthCount; i++) {
      final target = DateTime(now.year, now.month - i, 1);
      double total = 0.0;
      for (var e in _expenses) {
        final d = e.dateTime;
        if (e.category.toLowerCase().trim() == lower && d.year == target.year && d.month == target.month) {
          total += e.amount;
        }
      }
      map[i] = total;
    }
    return map;
  }
}
