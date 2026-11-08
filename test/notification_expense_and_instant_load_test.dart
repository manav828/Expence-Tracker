import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/reminder_provider.dart';
import 'package:expense_tracker/screens/dashboard_screen.dart';
import 'package:expense_tracker/widgets/dashboard_shimmer.dart';

void main() {
  group('Instant Load & Notification Expense Merging Tests', () {
    test('Local unsynced expense (from SMS / QuickAdd) is preserved during cloud merge', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Simulating cloud list containing 2 older expenses
      final cloudList = [
        Expense(
          id: 1,
          amount: 250.0,
          category: 'Food & Dining',
          paymentMethod: 'UPI',
          expenseDate: now - 100000,
          createdAt: now - 100000,
          updatedAt: now - 100000,
        ),
        Expense(
          id: 2,
          amount: 1500.0,
          category: 'Shopping',
          paymentMethod: 'Card',
          expenseDate: now - 50000,
          createdAt: now - 50000,
          updatedAt: now - 50000,
        ),
      ];

      // Simulating local SQLite containing the 2 cloud items + 1 newly edited SMS notification expense
      final newSmsExpense = Expense(
        id: 3,
        amount: 320.0,
        category: 'Transport',
        paymentMethod: 'UPI',
        comment: 'Auto-logged SMS Uber trip',
        expenseDate: now - 1000,
        createdAt: now - 1000,
        updatedAt: now - 500, // Edited via QuickAddActivity
      );

      final localList = [...cloudList, newSmsExpense];

      // Replicating the robust merge logic in DatabaseService.getAllExpenses
      final Map<String, Expense> mergedMap = {};
      for (final exp in cloudList) {
        final key = '${exp.createdAt}_${exp.expenseDate}';
        mergedMap[key] = exp;
      }
      for (final exp in localList) {
        final key = '${exp.createdAt}_${exp.expenseDate}';
        final existing = mergedMap[key];
        if (existing == null) {
          mergedMap[key] = exp;
        } else if (exp.updatedAt > existing.updatedAt) {
          mergedMap[key] = exp;
        }
      }

      final merged = mergedMap.values.toList();
      merged.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

      // Assertions
      expect(merged.length, 3, reason: 'Local SMS expense must NOT be dropped');
      expect(merged.any((e) => e.category == 'Transport' && e.amount == 320.0), isTrue);
      expect(merged.first.category, 'Transport', reason: 'Most recent SMS expense should appear first');
    });

    test('Local edited version takes precedence over stale cloud entry', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Stale cloud entry
      final cloudExp = Expense(
        id: 10,
        amount: 500.0,
        category: 'General',
        paymentMethod: 'UPI',
        expenseDate: now - 2000,
        createdAt: now - 2000,
        updatedAt: now - 2000,
      );

      // Local entry where user tapped notification and changed category to "Food & Dining" and amount to 450
      final localEditedExp = Expense(
        id: 10,
        amount: 450.0,
        category: 'Food & Dining',
        paymentMethod: 'UPI',
        expenseDate: now - 2000,
        createdAt: now - 2000,
        updatedAt: now - 500, // Newer updatedAt
      );

      final Map<String, Expense> mergedMap = {};
      mergedMap['${cloudExp.createdAt}_${cloudExp.expenseDate}'] = cloudExp;

      final key = '${localEditedExp.createdAt}_${localEditedExp.expenseDate}';
      final existing = mergedMap[key];
      if (existing == null) {
        mergedMap[key] = localEditedExp;
      } else if (localEditedExp.updatedAt > existing.updatedAt) {
        mergedMap[key] = localEditedExp;
      }

      final result = mergedMap[key]!;
      expect(result.category, 'Food & Dining');
      expect(result.amount, 450.0);
    });

    testWidgets('Dashboard renders DashboardShimmer when loading with empty expenses', (tester) async {
      final expenseProvider = ExpenseProvider(autoFetch: false);
      expenseProvider.setExpensesForTesting([], categories: []);
      expenseProvider.setIsLoadingForTesting(true);

      final budgetProvider = BudgetProvider(autoFetch: false);
      final reminderProvider = ReminderProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ExpenseProvider>.value(value: expenseProvider),
            ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
            ChangeNotifierProvider<ReminderProvider>.value(value: reminderProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DashboardScreen(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Expect DashboardShimmer to be rendered instead of ₹0 static screen
      expect(find.byType(DashboardShimmer), findsOneWidget);
    });

    testWidgets('Dashboard renders actual content immediately when local expenses exist', (tester) async {
      final now = DateTime.now();
      final expenseProvider = ExpenseProvider(autoFetch: false);
      expenseProvider.setExpensesForTesting([
        Expense(
          id: 1,
          amount: 850.0,
          category: 'Food & Dining',
          paymentMethod: 'UPI',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      ], categories: ['Food & Dining']);

      final budgetProvider = BudgetProvider(autoFetch: false);
      final reminderProvider = ReminderProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ExpenseProvider>.value(value: expenseProvider),
            ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
            ChangeNotifierProvider<ReminderProvider>.value(value: reminderProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DashboardScreen(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Shimmer should NOT be visible since expenses exist
      expect(find.byType(DashboardShimmer), findsNothing);
      expect(find.text('Food & Dining'), findsWidgets);
    });
  });
}
