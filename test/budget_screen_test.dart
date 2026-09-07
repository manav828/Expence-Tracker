import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/models/budget.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/screens/budget_screen.dart';
import 'package:expense_tracker/screens/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('BudgetScreen renders empty state without crashing', (tester) async {
    final budgetProvider = BudgetProvider(autoFetch: false);
    final expenseProvider = ExpenseProvider(autoFetch: false);

    budgetProvider.setBudgetsForTesting([]);
    expenseProvider.setExpensesForTesting([]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: budgetProvider),
          ChangeNotifierProvider.value(value: expenseProvider),
        ],
        child: const MaterialApp(
          home: BudgetScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No Category Budgets Set'), findsOneWidget);
    expect(find.text('Active Categories'), findsOneWidget);
    expect(find.text('Add Budget'), findsOneWidget);
  });

  testWidgets('BudgetScreen renders populated budgets and overspend without unbudgeted outflows', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime.now();
    final budgetProvider = BudgetProvider(autoFetch: false);
    final expenseProvider = ExpenseProvider(autoFetch: false);

    budgetProvider.setBudgetsForTesting([
      Budget(
        id: 1,
        category: 'Food & Dining',
        monthlyLimit: 3000.0,
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

    expenseProvider.setExpensesForTesting(
      [
        // Overspend in Food & Dining (3500 > 3000)
        Expense(
          id: 1,
          amount: 3500.0,
          category: 'Food & Dining',
          paymentMethod: 'UPI',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      ],
      categories: ['Food & Dining', 'Transport', 'Shopping'],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: budgetProvider),
          ChangeNotifierProvider.value(value: expenseProvider),
        ],
        child: const MaterialApp(
          home: BudgetScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify it doesn't render grey screen (no uncaught exceptions)
    expect(tester.takeException(), isNull);

    // Verify active elements exist
    expect(find.text('Active Categories'), findsOneWidget);
    expect(find.text('Food & Dining'), findsWidgets);
    expect(find.text('Transport'), findsWidgets);
    expect(find.text('Add Budget'), findsOneWidget);

    // Verify unbudgeted outflows is completely removed
    expect(find.text('Unbudgeted Outflows'), findsNothing);
  });

  testWidgets('BudgetScreen shows exact percentage with one decimal place (e.g. 99.9% used)', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime.now();
    final budgetProvider = BudgetProvider(autoFetch: false);
    final expenseProvider = ExpenseProvider(autoFetch: false);

    budgetProvider.setBudgetsForTesting([
      Budget(
        id: 1,
        category: 'Shopping',
        monthlyLimit: 1000.0,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      ),
    ]);

    expenseProvider.setExpensesForTesting(
      [
        Expense(
          id: 1,
          amount: 999.0, // 999 of 1000 = 99.9%
          category: 'Shopping',
          paymentMethod: 'UPI',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      ],
      categories: ['Shopping'],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: budgetProvider),
          ChangeNotifierProvider.value(value: expenseProvider),
        ],
        child: const MaterialApp(
          home: BudgetScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify 99.9% used is displayed exactly, not rounded to 100%
    expect(find.text('99.9% used'), findsOneWidget);
    expect(find.text('100% used'), findsNothing);
  });

  testWidgets('DashboardScreen displays Budget Safeguards with X dismiss button and dismisses when tapped', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime.now();
    final budgetProvider = BudgetProvider(autoFetch: false);
    final expenseProvider = ExpenseProvider(autoFetch: false);

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
        category: 'Shopping',
        monthlyLimit: 1000.0,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      ),
    ]);

    expenseProvider.setExpensesForTesting(
      [
        Expense(
          id: 1,
          amount: 4000.0,
          category: 'Food & Dining',
          paymentMethod: 'UPI',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
        Expense(
          id: 2,
          amount: 1099.0,
          category: 'Shopping',
          paymentMethod: 'UPI',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      ],
      categories: ['Food & Dining', 'Shopping'],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: budgetProvider),
          ChangeNotifierProvider.value(value: expenseProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DashboardScreen()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Budget Safeguards card is visible with percentage formatted
    expect(find.text('Budget Safeguards'), findsOneWidget);
    expect(find.text('₹4000 / ₹5000 (80%)'), findsOneWidget);
    expect(find.text('₹1099 / ₹1000 (109.9%)'), findsOneWidget);

    // Verify X dismiss button exists
    final dismissBtn = find.byTooltip('Dismiss');
    expect(dismissBtn, findsOneWidget);

    // Tap X to dismiss Budget Safeguards
    await tester.tap(dismissBtn);
    await tester.pumpAndSettle();

    // Verify Budget Safeguards card is removed/dismissed
    expect(find.text('Budget Safeguards'), findsNothing);
    expect(find.text('Budget Safeguards alert dismissed'), findsOneWidget);
  });
}
