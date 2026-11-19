import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/screens/analytics_screen.dart';

void main() {
  testWidgets('AnalyticsScreen renders custom date range selector, calendar, and ledger', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final provider = ExpenseProvider(autoFetch: false);

    final now = DateTime.now();
    provider.setExpensesForTesting([
      Expense(
        id: 1,
        amount: 450.0,
        category: 'Food & Dining',
        paymentMethod: 'UPI',
        comment: 'Lunch with team',
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      ),
      Expense(
        id: 2,
        amount: 2500.0,
        category: 'Tech & Gear',
        paymentMethod: 'Card',
        comment: 'Mechanical Keyboard',
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      ),
    ], categories: ['Food & Dining', 'Tech & Gear', 'Transport']);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<ExpenseProvider>.value(
          value: provider,
          child: const AnalyticsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Date Range Selector pills
    expect(find.text('This Month'), findsWidgets);
    expect(find.text('Last Month'), findsOneWidget);
    expect(find.text('Last 30 Days'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    // Verify Total Expenses Card
    expect(find.text('TOTAL EXPENSES'), findsOneWidget);
    expect(find.textContaining('2,950.00'), findsWidgets);
    expect(find.textContaining('2 transactions'), findsOneWidget);

    // Verify 3-Way Mode Switcher
    expect(find.text('Ledger'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Breakdown'), findsOneWidget);

    // Verify Category filter chips are present in Ledger view
    expect(find.textContaining('Food & Dining'), findsWidgets);
    expect(find.textContaining('Tech & Gear'), findsWidgets);

    // Verify Transactions Ledger & record entries
    expect(find.text('Lunch with team'), findsOneWidget);
    expect(find.text('Mechanical Keyboard'), findsOneWidget);

    // Switch to Calendar mode
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('<₹2000'), findsOneWidget);

    // Switch to Breakdown mode
    await tester.tap(find.text('Breakdown'));
    await tester.pumpAndSettle();
    expect(find.text('Categories'), findsOneWidget);

    // Switch back to Ledger mode and verify continuous timeline custom paints
    await tester.tap(find.text('Ledger'));
    await tester.pumpAndSettle();

    // Verify CustomPaint widgets used for timeline vertical tracks are present
    final customPaints = find.byType(CustomPaint);
    expect(customPaints, findsWidgets);

    // Open Filter & Sort bottom sheet via tune icon
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Filter & Sort Ledger'), findsOneWidget);
    // User created payment methods should be present
    expect(find.text('All'), findsWidgets);
    expect(find.text('UPI'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);

    // Static/hardcoded methods should NOT exist
    expect(find.text('Credit Card'), findsNothing);
    expect(find.text('Debit Card'), findsNothing);
    expect(find.text('Net Banking'), findsNothing);
  });

  testWidgets('AnalyticsScreen strictly separates income from expenses in Hero card, Calendar, and Breakdown', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final provider = ExpenseProvider(autoFetch: false);
    final now = DateTime.now();

    provider.setExpensesForTesting([
      Expense(
        id: 1,
        amount: 1200.0,
        category: 'Food & Dining',
        paymentMethod: 'UPI',
        comment: 'Dinner',
        type: TransactionType.expense,
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      ),
      Expense(
        id: 2,
        amount: 800.0,
        category: 'Transport',
        paymentMethod: 'UPI',
        comment: 'Cab ride',
        type: TransactionType.expense,
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      ),
      Expense(
        id: 3,
        amount: 45000.0,
        category: 'Salary',
        paymentMethod: 'Bank',
        comment: 'Monthly Salary',
        type: TransactionType.income,
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      ),
    ], categories: ['Food & Dining', 'Transport'], incomeCategories: ['Salary']);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<ExpenseProvider>.value(
          value: provider,
          child: const AnalyticsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Total Expenses Hero Card strictly shows 2,000.00 (NOT 47,000.00!)
    expect(find.text('TOTAL EXPENSES'), findsOneWidget);
    expect(find.textContaining('2,000.00'), findsWidgets);
    expect(find.textContaining('47,000'), findsNothing);
    expect(find.textContaining('2 transactions'), findsOneWidget);

    // 2. Verify Highest day card shows 2,000, NOT 47,000 or 45,000!
    expect(find.text('Highest day'), findsOneWidget);
    final highestDayFinder = find.ancestor(
      of: find.text('Highest day'),
      matching: find.byType(Container),
    ).first;
    expect(
      find.descendant(of: highestDayFinder, matching: find.textContaining('2,000')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: highestDayFinder, matching: find.textContaining('45,000')),
      findsNothing,
    );

    // 3. Switch to Breakdown tab
    await tester.tap(find.text('Breakdown'));
    await tester.pumpAndSettle();

    // Verify Expense Breakdown & Income Breakdown cards are separate
    expect(find.text('Expense Breakdown'), findsOneWidget);
    expect(find.text('Income Breakdown'), findsOneWidget);
    expect(find.textContaining('Salary'), findsOneWidget);

    // 4. Switch to Calendar tab and verify day outflows
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    // Income should display with + and not -
    expect(find.text('+₹45000.00'), findsOneWidget);
    expect(find.text('-₹45000.00'), findsNothing);
  });
}
