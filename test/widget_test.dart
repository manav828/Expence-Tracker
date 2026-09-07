import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/models/budget.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/screens/budget_screen.dart';
import 'package:expense_tracker/screens/search_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SearchScreen renders properly with search bar and filter chips', (WidgetTester tester) async {
    final expenseProvider = ExpenseProvider(autoFetch: false);
    final budgetProvider = BudgetProvider(autoFetch: false);

    expenseProvider.setExpensesForTesting([
      Expense(
        id: 1,
        amount: 350.0,
        category: 'Food & Dining',
        paymentMethod: 'UPI',
        comment: 'Pizza lunch',
        expenseDate: DateTime.now().millisecondsSinceEpoch,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: expenseProvider),
          ChangeNotifierProvider.value(value: budgetProvider),
        ],
        child: const MaterialApp(
          home: SearchScreen(),
        ),
      ),
    );

    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('Search remarks, categories, payment...'), findsOneWidget);
    expect(find.text('Food & Dining'), findsOneWidget);
    expect(find.text('Pizza lunch'), findsOneWidget);
  });

  testWidgets('BudgetScreen renders properly with overview and active limits', (WidgetTester tester) async {
    final expenseProvider = ExpenseProvider(autoFetch: false);
    final budgetProvider = BudgetProvider(autoFetch: false);

    final now = DateTime.now();
    budgetProvider.setBudgetsForTesting([
      Budget(
        id: 1,
        category: 'Food & Dining',
        monthlyLimit: 5000.0,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      ),
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: expenseProvider),
          ChangeNotifierProvider.value(value: budgetProvider),
        ],
        child: const MaterialApp(
          home: BudgetScreen(),
        ),
      ),
    );

    expect(find.byType(BudgetScreen), findsOneWidget);
    expect(find.text('OVERALL HEALTH'), findsOneWidget);
    expect(find.text('Active Categories'), findsOneWidget);
    expect(find.text('Food & Dining'), findsWidgets);
  });
}
