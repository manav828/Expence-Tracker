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
  });
}
