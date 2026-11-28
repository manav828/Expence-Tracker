import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_tracker/models/budget.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/payment_reminder.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/providers/reminder_provider.dart';
import 'package:expense_tracker/providers/split_provider.dart';
import 'package:expense_tracker/providers/trip_photo_provider.dart';
import 'package:expense_tracker/screens/analytics_screen.dart';
import 'package:expense_tracker/screens/budget_screen.dart';
import 'package:expense_tracker/screens/dashboard_screen.dart';
import 'package:expense_tracker/screens/search_screen.dart';
import 'package:expense_tracker/utils/session_manager.dart';
import 'package:expense_tracker/widgets/reminder_carousel_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('1. SessionManager.clearAllProviders wipes stale state across account switch', (tester) async {
    final now = DateTime.now();
    final expenseProvider = ExpenseProvider(autoFetch: false);
    final budgetProvider = BudgetProvider(autoFetch: false);
    final reminderProvider = ReminderProvider(autoFetch: false);
    final splitProvider = SplitProvider();
    final photoProvider = TripPhotoProvider();

    expenseProvider.setExpensesForTesting([
      Expense(
        id: 1,
        amount: 500,
        category: 'Food & Dining',
        paymentMethod: 'UPI',
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      ),
    ]);
    budgetProvider.setBudgetsForTesting([
      Budget(
        id: 1,
        category: 'Food & Dining',
        monthlyLimit: 4000,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      ),
    ]);
    reminderProvider.setRemindersForTesting([
      PaymentReminder(
        id: 'rem_1',
        title: 'Owner Bill',
        amount: 799,
        category: 'Bills',
        paymentMethod: 'UPI',
        frequency: ReminderFrequency.monthly,
        nextDueDate: now.add(const Duration(days: 1)),
      ),
    ]);

    late BuildContext capturedContext;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: expenseProvider),
          ChangeNotifierProvider.value(value: budgetProvider),
          ChangeNotifierProvider.value(value: reminderProvider),
          ChangeNotifierProvider.value(value: splitProvider),
          ChangeNotifierProvider.value(value: photoProvider),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(expenseProvider.expenses, hasLength(1));
    expect(budgetProvider.budgets, hasLength(1));
    expect(reminderProvider.reminders, hasLength(1));

    SessionManager.clearAllProviders(capturedContext);
    await tester.pump();

    expect(expenseProvider.expenses, isEmpty);
    expect(budgetProvider.budgets, isEmpty);
    expect(reminderProvider.reminders, isEmpty);
    expect(photoProvider.allPhotos, isEmpty);
  });

  testWidgets('2a. BudgetScreen hides On Track when no budgets exist (₹0 limit)', (tester) async {
    final budgetProvider = BudgetProvider(autoFetch: false)..setBudgetsForTesting([]);
    final expenseProvider = ExpenseProvider(autoFetch: false)..setExpensesForTesting([]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: budgetProvider),
          ChangeNotifierProvider.value(value: expenseProvider),
        ],
        child: const MaterialApp(home: BudgetScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Category Budgets Set'), findsOneWidget);
    expect(find.text('On Track'), findsNothing);
  });

  testWidgets('2b. BudgetScreen uses consistent On Track status at 76.3% across overview & category card', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime.now();
    final budgetProvider = BudgetProvider(autoFetch: false)
      ..setBudgetsForTesting([
        Budget(
          id: 1,
          category: 'Food & Dining',
          monthlyLimit: 4000.0,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      ]);
    final expenseProvider = ExpenseProvider(autoFetch: false)
      ..setExpensesForTesting([
        Expense(
          id: 1,
          amount: 3053.0, // 76.325% -> 76.3%
          category: 'Food & Dining',
          paymentMethod: 'UPI',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: budgetProvider),
          ChangeNotifierProvider.value(value: expenseProvider),
        ],
        child: const MaterialApp(home: BudgetScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('On Track'), findsOneWidget);
    expect(find.textContaining('On Track (76.3%)'), findsOneWidget);
    expect(find.text('Near Ceiling'), findsNothing);
    expect(find.textContaining('Safe'), findsNothing);
    expect(find.text('Well paced'), findsNothing);
  });

  testWidgets('3a. AnalyticsScreen All chip counts both expenses and income entries', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final expenseProvider = ExpenseProvider(autoFetch: false)
      ..setExpensesForTesting([
        Expense(
          id: 1,
          amount: 1200,
          category: 'Food & Dining',
          paymentMethod: 'UPI',
          type: TransactionType.expense,
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
        Expense(
          id: 2,
          amount: 800,
          category: 'Transport',
          paymentMethod: 'UPI',
          type: TransactionType.expense,
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
        Expense(
          id: 3,
          amount: 45000,
          category: 'Salary',
          paymentMethod: 'Transfer',
          type: TransactionType.income,
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      ]);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<ExpenseProvider>.value(
          value: expenseProvider,
          child: const AnalyticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('All (2)'), findsNothing);
  });

  testWidgets('3b. SearchScreen separates Spent and Income totals on mixed ledger', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime.now();
    final expenseProvider = ExpenseProvider(autoFetch: false)
      ..setExpensesForTesting([
        Expense(
          id: 1,
          amount: 1000.0,
          category: 'Transport',
          paymentMethod: 'UPI',
          type: TransactionType.expense,
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
        Expense(
          id: 2,
          amount: 5000.0,
          category: 'Salary',
          paymentMethod: 'Transfer',
          type: TransactionType.income,
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      ]);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<ExpenseProvider>.value(
          value: expenseProvider,
          child: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Spent:'), findsOneWidget);
    expect(find.textContaining('1,000.00'), findsWidgets);
    expect(find.textContaining('Income: +'), findsOneWidget);
    expect(find.textContaining('5,000.00'), findsWidgets);
    expect(find.textContaining('6,000.00'), findsNothing);
  });

  testWidgets('Home shows an expense-only monthly total on narrow screens', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    Expense transaction(int day, double amount, TransactionType type) {
      final timestamp = DateTime(now.year, now.month, day, 12).millisecondsSinceEpoch;
      return Expense(
        amount: amount,
        category: 'Food & Dining',
        paymentMethod: 'UPI',
        expenseDate: timestamp,
        createdAt: timestamp,
        updatedAt: timestamp,
        type: type,
      );
    }

    final expenses = ExpenseProvider(autoFetch: false)..setExpensesForTesting([
      transaction(2, 1500, TransactionType.expense),
      transaction(2, 500, TransactionType.expense),
      transaction(4, 12000, TransactionType.income),
      transaction(5, 7200, TransactionType.expense),
    ]);
    final budgets = BudgetProvider(autoFetch: false);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: expenses),
          ChangeNotifierProvider.value(value: budgets),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cumulative spending'), findsNothing);
    expect(find.text("THIS MONTH'S SPEND"), findsOneWidget);
    expect(find.text('₹9,200.00'), findsOneWidget);
    expect(find.text('3 expenses this month'), findsOneWidget);
  });

  testWidgets('4. ReminderCarouselBanner displays Due tomorrow urgency next to amount', (tester) async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1, hours: 9));
    final reminderProvider = ReminderProvider()
      ..setRemindersForTesting([
        PaymentReminder(
          id: 'rem_due_tmrw',
          title: 'Broadband Plan',
          amount: 799,
          category: 'Bills & Utilities',
          paymentMethod: 'UPI',
          frequency: ReminderFrequency.monthly,
          nextDueDate: tomorrow,
        ),
      ]);
    final expenseProvider = ExpenseProvider(autoFetch: false)..setExpensesForTesting([]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: reminderProvider),
          ChangeNotifierProvider.value(value: expenseProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ReminderCarouselBanner(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Broadband Plan'), findsOneWidget);
    expect(find.text('₹799'), findsOneWidget);
    expect(find.text('Due tomorrow'), findsOneWidget);
    expect(find.text('Mark Paid'), findsOneWidget);
    expect(find.text('Snooze'), findsOneWidget);
  });
}
