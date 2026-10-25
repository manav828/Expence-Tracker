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
    expect(find.text('₹2950.00'), findsOneWidget);
    expect(find.text('2 Transactions'), findsOneWidget);

    // Verify Where Your Money Went Section
    expect(find.text('Where Your Money Went'), findsOneWidget);
    expect(find.text('Food & Dining'), findsWidgets);
    expect(find.text('Tech & Gear'), findsWidgets);

    // Verify Daily Spending Calendar is preserved
    expect(find.text('Daily Spending Calendar'), findsOneWidget);

    // Verify Transactions Ledger & record entries
    expect(find.text('Transactions Ledger'), findsOneWidget);
    expect(find.text('Lunch with team'), findsOneWidget);
    expect(find.text('Mechanical Keyboard'), findsOneWidget);
  });
}
