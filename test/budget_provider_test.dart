import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/budget.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/budget_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Category Budgets & Overspend Tests', () {
    late BudgetProvider budgetProvider;
    final now = DateTime.now();

    setUp(() {
      budgetProvider = BudgetProvider(autoFetch: false);
      budgetProvider.setBudgetsForTesting([
        Budget(
          id: 1,
          category: 'Food & Dining',
          monthlyLimit: 5000.0,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
        Budget(
          id: 2,
          category: 'Transport',
          monthlyLimit: 2000.0,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      ]);
    });

    test('Initial budgets and totals are correct', () {
      expect(budgetProvider.budgets.length, 2);
      expect(budgetProvider.getTotalBudgetLimit(), 7000.0);
      expect(budgetProvider.getBudgetForCategory('Food & Dining')?.monthlyLimit, 5000.0);
      expect(budgetProvider.getBudgetForCategory('NonExistent'), isNull);
    });

    test('Progress calculation: On Track (< 80%)', () {
      final expenses = [
        Expense(
          id: 1,
          amount: 2500.0, // 50% of 5000
          category: 'Food & Dining',
          paymentMethod: 'UPI',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      ];

      final foodBudget = budgetProvider.getBudgetForCategory('Food & Dining')!;
      final progress = budgetProvider.getProgressForBudget(foodBudget, expenses);

      expect(progress.spentThisMonth, 2500.0);
      expect(progress.remaining, 2500.0);
      expect(progress.percentage, 50.0);
      expect(progress.isOverspent, false);
      expect(progress.isNearLimit, false);
    });

    test('Progress calculation: Near Limit (80% - 99%)', () {
      final expenses = [
        Expense(
          id: 1,
          amount: 4200.0, // 84% of 5000
          category: 'Food & Dining',
          paymentMethod: 'UPI',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      ];

      final foodBudget = budgetProvider.getBudgetForCategory('Food & Dining')!;
      final progress = budgetProvider.getProgressForBudget(foodBudget, expenses);

      expect(progress.percentage, 84.0);
      expect(progress.isOverspent, false);
      expect(progress.isNearLimit, true);
    });

    test('Progress calculation: Overspent (>= 100%)', () {
      final expenses = [
        Expense(
          id: 1,
          amount: 5500.0, // 110% of 5000
          category: 'Food & Dining',
          paymentMethod: 'Card',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      ];

      final foodBudget = budgetProvider.getBudgetForCategory('Food & Dining')!;
      final progress = budgetProvider.getProgressForBudget(foodBudget, expenses);

      expect(progress.spentThisMonth, 5500.0);
      expect(progress.percentage, 110.0);
      expect(progress.isOverspent, true);
      expect(progress.isNearLimit, false);

      final overspentList = budgetProvider.getOverspentBudgets(expenses);
      expect(overspentList.length, 1);
      expect(overspentList.first.category, 'Food & Dining');
    });

    test('Overspend detection alert when adding expense', () {
      final currentExpenses = [
        Expense(
          id: 1,
          amount: 4500.0,
          category: 'Food & Dining',
          paymentMethod: 'UPI',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      ];

      // Add 800 expense -> total 5300 (exceeds 5000 limit)
      final newExpense = Expense(
        id: 2,
        amount: 800.0,
        category: 'Food & Dining',
        paymentMethod: 'UPI',
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      );

      final alert = budgetProvider.checkForOverspend(newExpense, currentExpenses);
      expect(alert, isNotNull);
      expect(alert!.contains('Budget exceeded for Food & Dining'), true);
      expect(budgetProvider.recentOverspendWarning, isNotNull);

      // Clear warning
      budgetProvider.clearRecentWarning();
      expect(budgetProvider.recentOverspendWarning, isNull);
    });

    test('checkForOverspend does NOT double-count when expense is already in currentExpenses list', () {
      final nowTime = DateTime.now().millisecondsSinceEpoch;
      // Budget limit is 5000
      final expense = Expense(
        id: 10,
        amount: 1500.0,
        category: 'Food & Dining',
        paymentMethod: 'UPI',
        expenseDate: nowTime,
        createdAt: nowTime,
        updatedAt: nowTime,
      );

      // List ALREADY contains the expense (as happens after provider.addExpense)
      final expensesList = [expense];

      final alert = budgetProvider.checkForOverspend(expense, expensesList);
      // 1500 < 5000 -> must NOT trigger alert, must NOT be 3000!
      expect(alert, isNull);
      expect(budgetProvider.recentOverspendWarning, isNull);
    });

    test('clearRecentWarningIfResolved clears warning when category is within limit', () {
      final nowTime = DateTime.now().millisecondsSinceEpoch;
      // Force set a warning
      budgetProvider.checkForOverspend(
        Expense(amount: 6000.0, category: 'Food & Dining', paymentMethod: 'UPI', expenseDate: nowTime, createdAt: nowTime, updatedAt: nowTime),
        [],
      );
      expect(budgetProvider.recentOverspendWarning, isNotNull);

      // Expenses within limit (1500 < 5000)
      final withinLimitExpenses = [
        Expense(id: 1, amount: 1500.0, category: 'Food & Dining', paymentMethod: 'UPI', expenseDate: nowTime, createdAt: nowTime, updatedAt: nowTime),
      ];
      budgetProvider.clearRecentWarningIfResolved(withinLimitExpenses);
      expect(budgetProvider.recentOverspendWarning, isNull);
    });
  });
}
