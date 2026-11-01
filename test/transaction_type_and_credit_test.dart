import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/budget.dart';
import 'package:expense_tracker/models/search_filter.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/providers/budget_provider.dart';

Expense _makeTestExpense({
  int? id,
  required double amount,
  required String category,
  String paymentMethod = 'UPI',
  int? date,
  TransactionType type = TransactionType.expense,
}) {
  final now = date ?? DateTime.now().millisecondsSinceEpoch;
  return Expense(
    id: id,
    amount: amount,
    category: category,
    paymentMethod: paymentMethod,
    expenseDate: now,
    createdAt: now,
    updatedAt: now,
    type: type,
  );
}

void main() {
  group('TransactionType & Model Unit Tests', () {
    test('TransactionType enum values, toDbValue and fromDbValue work accurately', () {
      expect(TransactionType.expense.toDbValue(), 'expense');
      expect(TransactionType.income.toDbValue(), 'income');

      expect(TransactionType.fromDbValue('expense'), TransactionType.expense);
      expect(TransactionType.fromDbValue('income'), TransactionType.income);
      expect(TransactionType.fromDbValue('EXPENSE'), TransactionType.expense);
      expect(TransactionType.fromDbValue('INCOME'), TransactionType.income);
      expect(TransactionType.fromDbValue('credit'), TransactionType.income);
      expect(TransactionType.fromDbValue('debit'), TransactionType.expense);

      // Default safe fallback on null or unknown string
      expect(TransactionType.fromDbValue(null), TransactionType.expense);
      expect(TransactionType.fromDbValue('unknown_foo'), TransactionType.expense);
    });

    test('Expense model defaults to expense type with isExpense true', () {
      final exp = _makeTestExpense(
        amount: 250.0,
        category: 'Food & Dining',
      );

      expect(exp.type, TransactionType.expense);
      expect(exp.isExpense, true);
      expect(exp.isIncome, false);
    });

    test('Expense model correctly handles income type', () {
      final inc = _makeTestExpense(
        amount: 50000.0,
        category: 'Salary',
        paymentMethod: 'Bank Transfer',
        type: TransactionType.income,
      );

      expect(inc.type, TransactionType.income);
      expect(inc.isIncome, true);
      expect(inc.isExpense, false);

      final map = inc.toMap();
      expect(map['type'], 'income');

      final reconstructed = Expense.fromMap(map);
      expect(reconstructed.type, TransactionType.income);
      expect(reconstructed.isIncome, true);
    });

    test('Backward compatibility: fromMap without type column gracefully defaults to expense', () {
      final legacyMap = {
        'id': 42,
        'amount': 150.0,
        'category': 'Transport',
        'payment_method': 'Cash',
        'expense_date': 1700000000000,
        'created_at': 1700000000000,
        'updated_at': 1700000000000,
        // 'type' is deliberately missing
      };

      final legacyExpense = Expense.fromMap(legacyMap);
      expect(legacyExpense.type, TransactionType.expense);
      expect(legacyExpense.isExpense, true);
      expect(legacyExpense.isIncome, false);
    });

    test('copyWith preserves and updates type correctly', () {
      final base = _makeTestExpense(
        amount: 1000.0,
        category: 'Freelance',
        type: TransactionType.income,
      );

      final copied = base.copyWith(amount: 1200.0);
      expect(copied.type, TransactionType.income);
      expect(copied.amount, 1200.0);

      final toggled = copied.copyWith(type: TransactionType.expense);
      expect(toggled.type, TransactionType.expense);
      expect(toggled.isExpense, true);
    });
  });

  group('ExpenseProvider Financial & Cash Flow Analytics Tests', () {
    late ExpenseProvider provider;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    setUp(() {
      provider = ExpenseProvider(autoFetch: false);
    });

    test('Calculates totalExpenses, totalIncome, netSavings, and savingsRate', () {
      final testExpenses = [
        _makeTestExpense(
          id: 1,
          amount: 50000.0,
          category: 'Salary',
          paymentMethod: 'Transfer',
          date: nowMs,
          type: TransactionType.income,
        ),
        _makeTestExpense(
          id: 2,
          amount: 10000.0,
          category: 'Freelance',
          date: nowMs,
          type: TransactionType.income,
        ),
        _makeTestExpense(
          id: 3,
          amount: 15000.0,
          category: 'Rent',
          paymentMethod: 'Transfer',
          date: nowMs,
          type: TransactionType.expense,
        ),
        _makeTestExpense(
          id: 4,
          amount: 5000.0,
          category: 'Food & Dining',
          paymentMethod: 'Card',
          date: nowMs,
          type: TransactionType.expense,
        ),
      ];

      provider.setExpensesForTesting(testExpenses);

      expect(provider.totalIncome, 60000.0);
      expect(provider.totalExpenses, 20000.0);
      expect(provider.netSavings, 40000.0);
      expect(provider.savingsRate, closeTo(66.67, 0.01));
    });

    test('Zero income results in 0.0 savings rate without negative division panic', () {
      final testExpenses = [
        _makeTestExpense(
          id: 1,
          amount: 3000.0,
          category: 'Food',
          date: nowMs,
          type: TransactionType.expense,
        ),
      ];

      provider.setExpensesForTesting(testExpenses);

      expect(provider.totalIncome, 0.0);
      expect(provider.totalExpenses, 3000.0);
      expect(provider.netSavings, -3000.0);
      expect(provider.savingsRate, 0.0);
    });

    test('Separates categoryTotals (Expenses) from incomeCategoryTotals (Income)', () {
      final testExpenses = [
        _makeTestExpense(
          id: 1,
          amount: 40000.0,
          category: 'Salary',
          paymentMethod: 'Transfer',
          date: nowMs,
          type: TransactionType.income,
        ),
        _makeTestExpense(
          id: 2,
          amount: 2500.0,
          category: 'Food & Dining',
          date: nowMs,
          type: TransactionType.expense,
        ),
        _makeTestExpense(
          id: 3,
          amount: 1500.0,
          category: 'Transport',
          paymentMethod: 'Card',
          date: nowMs,
          type: TransactionType.expense,
        ),
      ];

      provider.setExpensesForTesting(testExpenses);

      final expTotals = provider.categoryTotals;
      final incTotals = provider.incomeCategoryTotals;

      expect(expTotals.containsKey('Salary'), false);
      expect(expTotals['Food & Dining'], 2500.0);
      expect(expTotals['Transport'], 1500.0);

      expect(incTotals.containsKey('Food & Dining'), false);
      expect(incTotals['Salary'], 40000.0);
    });

    test('Search filter properly isolates expenses vs income', () {
      final testExpenses = [
        _makeTestExpense(
          id: 1,
          amount: 50000.0,
          category: 'Salary',
          paymentMethod: 'Transfer',
          date: nowMs,
          type: TransactionType.income,
        ),
        _makeTestExpense(
          id: 2,
          amount: 1200.0,
          category: 'Food & Dining',
          date: nowMs,
          type: TransactionType.expense,
        ),
      ];

      provider.setExpensesForTesting(testExpenses);

      final incomeOnly = provider.searchExpenses(const SearchFilter(type: TransactionType.income));
      expect(incomeOnly.length, 1);
      expect(incomeOnly.first.category, 'Salary');

      final expenseOnly = provider.searchExpenses(const SearchFilter(type: TransactionType.expense));
      expect(expenseOnly.length, 1);
      expect(expenseOnly.first.category, 'Food & Dining');
    });
  });

  group('BudgetProvider Safeguards for Income', () {
    test('Budget limit calculations completely ignore income transactions', () {
      final budgetProvider = BudgetProvider(autoFetch: false);
      final now = DateTime.now();

      final foodBudget = Budget(
        category: 'Food & Dining',
        monthlyLimit: 5000.0,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      );
      budgetProvider.setBudgetsForTesting([foodBudget]);

      final transactions = [
        _makeTestExpense(
          id: 1,
          amount: 2000.0,
          category: 'Food & Dining',
          date: now.millisecondsSinceEpoch,
          type: TransactionType.expense,
        ),
        _makeTestExpense(
          id: 2,
          amount: 10000.0,
          category: 'Food & Dining',
          date: now.millisecondsSinceEpoch,
          type: TransactionType.income,
        ),
      ];

      final spent = budgetProvider.getMonthlySpentForCategory('Food & Dining', transactions);
      // Spent should strictly be 2000, not -8000 or 12000
      expect(spent, 2000.0);

      final progress = budgetProvider.getProgressForBudget(foodBudget, transactions);
      expect(progress.spentThisMonth, 2000.0);
      expect(progress.isOverspent, false);
    });
  });
}
