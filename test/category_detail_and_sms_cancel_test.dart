import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/screens/category_detail_screen.dart';
import 'package:expense_tracker/widgets/add_expense_sheet.dart';

Expense createTestExpense({
  int? id,
  required double amount,
  required String category,
  required String paymentMethod,
  required DateTime dateTime,
  String? comment,
}) {
  final ms = dateTime.millisecondsSinceEpoch;
  return Expense(
    id: id,
    amount: amount,
    category: category,
    paymentMethod: paymentMethod,
    comment: comment,
    expenseDate: ms,
    createdAt: ms,
    updatedAt: ms,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExpenseProvider Category Helper Methods', () {
    test('getExpensesForCategory correctly filters by category and date range', () {
      final provider = ExpenseProvider(autoFetch: false);
      final now = DateTime.now();

      final e1 = createTestExpense(
        id: 1,
        amount: 250.0,
        category: 'Food & Dining',
        paymentMethod: 'UPI',
        dateTime: now,
      );
      final e2 = createTestExpense(
        id: 2,
        amount: 500.0,
        category: 'Shopping',
        paymentMethod: 'Card',
        dateTime: now,
      );
      final e3 = createTestExpense(
        id: 3,
        amount: 150.0,
        category: 'Food & Dining',
        paymentMethod: 'Cash',
        dateTime: now.subtract(const Duration(days: 40)),
      );

      provider.setExpensesForTesting([e1, e2, e3]);

      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final foodExpenses = provider.getExpensesForCategory('Food & Dining', monthStart, monthEnd);
      expect(foodExpenses.length, 1);
      expect(foodExpenses.first.id, 1);
    });

    test('getCategoryWeeklyTotals sums correctly for each weekday', () {
      final provider = ExpenseProvider(autoFetch: false);
      final now = DateTime.now();
      final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));

      final e = createTestExpense(
        id: 1,
        amount: 300.0,
        category: 'Food & Dining',
        paymentMethod: 'UPI',
        dateTime: monday.add(const Duration(hours: 10)),
      );

      provider.setExpensesForTesting([e]);

      final weekly = provider.getCategoryWeeklyTotals('Food & Dining');
      expect(weekly.length, 7);
      expect(weekly[0], 300.0); // Monday is index 0
    });

    test('getCategoryDailyTotals aggregates daily spending in month', () {
      final provider = ExpenseProvider(autoFetch: false);
      final now = DateTime.now();
      final e1 = createTestExpense(
        id: 1,
        amount: 100.0,
        category: 'Shopping',
        paymentMethod: 'Card',
        dateTime: DateTime(now.year, now.month, 5, 12),
      );
      final e2 = createTestExpense(
        id: 2,
        amount: 200.0,
        category: 'Shopping',
        paymentMethod: 'Card',
        dateTime: DateTime(now.year, now.month, 5, 16),
      );

      provider.setExpensesForTesting([e1, e2]);

      final daily = provider.getCategoryDailyTotals('Shopping', now.year, now.month);
      expect(daily[5], 300.0);
    });
  });

  group('CategoryDetailScreen Widget Tests', () {
    testWidgets('Renders CategoryDetailScreen with category, timeframe, charts, and entries', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final expenseProvider = ExpenseProvider(autoFetch: false);
      final budgetProvider = BudgetProvider(autoFetch: false);
      final now = DateTime.now();

      final e1 = createTestExpense(
        id: 1,
        amount: 350.0,
        category: 'Food & Dining',
        paymentMethod: 'UPI',
        dateTime: now,
        comment: 'Lunch with friends',
      );
      final e2 = createTestExpense(
        id: 2,
        amount: 150.0,
        category: 'Food & Dining',
        paymentMethod: 'Cash',
        dateTime: now.subtract(const Duration(hours: 3)),
        comment: 'Coffee',
      );

      expenseProvider.setExpensesForTesting([e1, e2], categories: ['Food & Dining', 'Shopping', 'Transport']);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: expenseProvider),
            ChangeNotifierProvider.value(value: budgetProvider),
          ],
          child: const MaterialApp(
            home: CategoryDetailScreen(initialCategory: 'Food & Dining'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Screen Title and Category
      expect(find.text('Category Details'), findsOneWidget);
      expect(find.text('Food & Dining'), findsWidgets);
      expect(find.text('₹500.00'), findsOneWidget);
      expect(find.text('2 entries'), findsOneWidget);

      // Check Calendar Filter Card (From / To labels and Month dropdown)
      expect(find.text('From: '), findsOneWidget);
      expect(find.text('To:     '), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);

      // Check Bar / Line Toggle
      expect(find.text('Bar'), findsOneWidget);
      expect(find.text('Line'), findsOneWidget);

      // Tap Line to switch to Line Chart
      await tester.tap(find.text('Line'));
      await tester.pumpAndSettle();

      // Check Expense Entries
      expect(find.text('All Entries (2)'), findsOneWidget);
      expect(find.text('Lunch with friends'), findsOneWidget);
      expect(find.text('Coffee'), findsOneWidget);

      // Open Dropdown and switch to Week
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Week').last);
      await tester.pumpAndSettle();

      expect(find.text('This Week'), findsWidgets);

      // Tap Category Selector to open SearchableSelectionSheet
      await tester.tap(find.text('Category'));
      await tester.pumpAndSettle();
      expect(find.text('Select Category'), findsOneWidget);
    });
  });

  group('SMS Auto-Detected Cancel Tests', () {
    testWidgets('Tapping Cancel on auto-detected transaction does NOT save into history', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final expenseProvider = ExpenseProvider(autoFetch: false);
      final budgetProvider = BudgetProvider(autoFetch: false);
      expenseProvider.setExpensesForTesting([], categories: ['Shopping', 'Food & Dining']);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: expenseProvider),
            ChangeNotifierProvider.value(value: budgetProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AddExpenseSheet(
                initialAmount: 499.0,
                initialCategory: 'Shopping',
                initialPaymentMethod: 'UPI',
                initialComment: 'Swiggy Instamart',
                isAutoDetected: true,
                autoSaveOnDismiss: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Cancel and Save Spend buttons exist
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save Spend'), findsOneWidget);
      expect(find.text('Transaction Auto-Detected'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Ensure NO expense was added to provider history
      expect(expenseProvider.expenses.isEmpty, true);
    });

    testWidgets('Dismissing popup when autoSaveOnDismiss is false does NOT save into history', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final expenseProvider = ExpenseProvider(autoFetch: false);
      final budgetProvider = BudgetProvider(autoFetch: false);
      expenseProvider.setExpensesForTesting([], categories: ['Shopping', 'Food & Dining']);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: expenseProvider),
            ChangeNotifierProvider.value(value: budgetProvider),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => AddExpenseSheet(
                        initialAmount: 499.0,
                        initialCategory: 'Shopping',
                        initialPaymentMethod: 'UPI',
                        initialComment: 'Swiggy Instamart',
                        isAutoDetected: true,
                        autoSaveOnDismiss: false,
                      ),
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Transaction Auto-Detected'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel to dismiss
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Ensure NO expense was logged
      expect(expenseProvider.expenses.isEmpty, true);
    });
  });
}
