import 'package:flutter/foundation.dart';
import '../core/errors/error_handler.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../services/database_service.dart';

class BudgetProgress {
  final Budget budget;
  final double spentThisMonth;
  final double remaining;
  final double percentage; // 0.0 to 100.0+
  final bool isOverspent;
  final bool isNearLimit; // 80% - 99.9%

  const BudgetProgress({
    required this.budget,
    required this.spentThisMonth,
    required this.remaining,
    required this.percentage,
    required this.isOverspent,
    required this.isNearLimit,
  });

  String get category => budget.category;
  double get limit => budget.monthlyLimit;
}

class BudgetProvider with ChangeNotifier {
  List<Budget> _budgets = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _recentOverspendWarning;

  List<Budget> get budgets => _budgets;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get recentOverspendWarning => _recentOverspendWarning;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  BudgetProvider({bool autoFetch = true}) {
    if (autoFetch) {
      fetchBudgets();
    }
  }

  @visibleForTesting
  void setBudgetsForTesting(List<Budget> list) {
    _budgets = List.from(list);
    notifyListeners();
  }

  void clearRecentWarning() {
    _recentOverspendWarning = null;
    notifyListeners();
  }

  Future<void> fetchBudgets() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _budgets = await DatabaseService.instance.getBudgets();
    } catch (e, st) {
      ErrorHandler.log('BudgetProvider.fetchBudgets', e, st);
      _errorMessage = ErrorHandler.getUserMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setBudget(String category, double monthlyLimit) async {
    final updated = await DatabaseService.instance.setBudget(category, monthlyLimit);
    final idx = _budgets.indexWhere((b) => b.category == category);
    if (idx != -1) {
      _budgets[idx] = updated;
    } else {
      _budgets.add(updated);
      _budgets.sort((a, b) => a.category.compareTo(b.category));
    }
    notifyListeners();
  }

  Future<void> deleteBudget(int id) async {
    await DatabaseService.instance.deleteBudget(id);
    _budgets.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  Future<void> deleteBudgetByCategory(String category) async {
    final target = category.trim().toLowerCase();
    await DatabaseService.instance.deleteBudgetByCategory(category);
    _budgets.removeWhere((b) => b.category.trim().toLowerCase() == target);
    notifyListeners();
  }

  Budget? getBudgetForCategory(String category) {
    final target = category.trim().toLowerCase();
    try {
      return _budgets.firstWhere((b) => b.category.trim().toLowerCase() == target);
    } catch (_) {
      return null;
    }
  }

  double getMonthlySpentForCategory(String category, List<Expense> expenses) {
    final now = DateTime.now();
    final target = category.trim().toLowerCase();
    return expenses.where((e) {
      final d = e.dateTime;
      return e.category.trim().toLowerCase() == target && d.year == now.year && d.month == now.month;
    }).fold(0.0, (sum, item) => sum + item.amount);
  }

  BudgetProgress getProgressForBudget(Budget budget, List<Expense> expenses) {
    final spent = getMonthlySpentForCategory(budget.category, expenses);
    final limit = budget.monthlyLimit;
    final percentage = limit > 0 ? double.parse(((spent / limit) * 100).toStringAsFixed(2)) : 0.0;
    final remaining = (limit - spent).clamp(-double.infinity, limit);
    final isOverspent = spent > limit;
    final isNearLimit = percentage >= 80.0 && !isOverspent;

    return BudgetProgress(
      budget: budget,
      spentThisMonth: spent,
      remaining: remaining,
      percentage: percentage,
      isOverspent: isOverspent,
      isNearLimit: isNearLimit,
    );
  }

  List<BudgetProgress> getAllBudgetProgress(List<Expense> expenses) {
    return _budgets.map((b) => getProgressForBudget(b, expenses)).toList();
  }

  List<BudgetProgress> getOverspentBudgets(List<Expense> expenses) {
    return getAllBudgetProgress(expenses).where((p) => p.isOverspent).toList();
  }

  double getTotalBudgetLimit() {
    return _budgets.fold(0.0, (sum, b) => sum + b.monthlyLimit);
  }

  double getTotalBudgetSpent(List<Expense> expenses) {
    final now = DateTime.now();
    final budgetedCategories = _budgets.map((b) => b.category).toSet();
    return expenses.where((e) {
      final d = e.dateTime;
      return budgetedCategories.contains(e.category) && d.year == now.year && d.month == now.month;
    }).fold(0.0, (sum, item) => sum + item.amount);
  }

  /// Checks whether adding an expense caused an overspending condition
  String? checkForOverspend(Expense newExpense, List<Expense> currentExpenses) {
    final budget = getBudgetForCategory(newExpense.category);
    if (budget == null) return null;

    final now = DateTime.now();
    final newExpDate = newExpense.dateTime;
    // Only applies to current month expenses
    if (newExpDate.year != now.year || newExpDate.month != now.month) return null;

    // Detect if newExpense has already been inserted into currentExpenses
    final alreadyIncluded = currentExpenses.any((e) =>
        identical(e, newExpense) ||
        (newExpense.id != null && e.id == newExpense.id) ||
        (e.createdAt == newExpense.createdAt &&
            e.amount == newExpense.amount &&
            e.category == newExpense.category));

    final currentCategorySpent = getMonthlySpentForCategory(newExpense.category, currentExpenses);
    final totalSpentWithNew = alreadyIncluded
        ? currentCategorySpent
        : currentCategorySpent + newExpense.amount;

    if (totalSpentWithNew > budget.monthlyLimit) {
      final excess = totalSpentWithNew - budget.monthlyLimit;
      final warning = '⚠️ Budget exceeded for ${budget.category}! Limit: ₹${budget.monthlyLimit.toStringAsFixed(0)} • Spent: ₹${totalSpentWithNew.toStringAsFixed(0)} (Over by ₹${excess.toStringAsFixed(0)})';
      _recentOverspendWarning = warning;
      notifyListeners();
      return warning;
    } else {
      // If no longer overspent, clear warning for this category
      if (_recentOverspendWarning != null && _recentOverspendWarning!.contains(budget.category)) {
        _recentOverspendWarning = null;
        notifyListeners();
      }
    }
    return null;
  }

  /// Automatically clears any stale recent warning if that category is not currently overspent
  void clearRecentWarningIfResolved(List<Expense> expenses) {
    if (_recentOverspendWarning == null) return;
    final overspent = getOverspentBudgets(expenses);
    final isStillOverspent = overspent.any((p) => _recentOverspendWarning!.contains(p.category));
    if (!isStillOverspent) {
      _recentOverspendWarning = null;
      notifyListeners();
    }
  }
}
