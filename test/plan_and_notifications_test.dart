import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_tracker/models/app_notification.dart';
import 'package:expense_tracker/models/budget.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/payment_reminder.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/providers/reminder_provider.dart';
import 'package:expense_tracker/providers/split_provider.dart';
import 'package:expense_tracker/providers/trip_photo_provider.dart';
import 'package:expense_tracker/screens/main_screen.dart';
import 'package:expense_tracker/screens/plan_screen.dart';
import 'package:expense_tracker/services/announcement_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'storage_mode_has_chosen_v1': true});
    AnnouncementService.instance.setAnnouncementsForTesting([]);
  });

  Widget wrapWithProviders({
    required Widget child,
    required ExpenseProvider expenseProvider,
    required BudgetProvider budgetProvider,
    required ReminderProvider reminderProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: expenseProvider),
        ChangeNotifierProvider.value(value: budgetProvider),
        ChangeNotifierProvider.value(value: reminderProvider),
        ChangeNotifierProvider(create: (_) => SplitProvider()),
        ChangeNotifierProvider(create: (_) => TripPhotoProvider()),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('Plan bottom tab combines Budgets and Bills & Reminders cleanly on one line', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime.now();
    final expenseProvider = ExpenseProvider(autoFetch: false)..setExpensesForTesting([]);
    final budgetProvider = BudgetProvider(autoFetch: false)..setBudgetsForTesting([]);
    final reminderProvider = ReminderProvider(autoFetch: false)
      ..setRemindersForTesting([
        PaymentReminder(
          id: 'r1',
          title: 'Broadband Bill',
          amount: 799,
          category: 'Bills & Utilities',
          paymentMethod: 'UPI',
          frequency: ReminderFrequency.monthly,
          nextDueDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
        ),
      ]);

    await tester.pumpWidget(
      wrapWithProviders(
        expenseProvider: expenseProvider,
        budgetProvider: budgetProvider,
        reminderProvider: reminderProvider,
        child: const MainScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Bottom navigation shows compact "Plan" label instead of wrapping
    expect(find.text('Plan'), findsOneWidget);

    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();

    expect(find.text('Budgets & Bills'), findsOneWidget);
    expect(find.byType(PlanScreen), findsOneWidget);
    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('Bills & Reminders'), findsOneWidget);

    // Switch to Bills & Reminders inside PlanScreen
    await tester.tap(find.text('Bills & Reminders'));
    await tester.pumpAndSettle();

    expect(find.text('Monthly Fixed Bills Commitment'), findsOneWidget);
    expect(find.text('Broadband Bill'), findsOneWidget);
    expect(find.text('Add Bill'), findsOneWidget);
  });

  testWidgets('Bell icon opens unified Notifications sheet with Reminders, Budget Alerts, and Promos', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime.now();
    final expenseProvider = ExpenseProvider(autoFetch: false)
      ..setExpensesForTesting([
        Expense(
          id: 1,
          amount: 3500,
          category: 'Food & Dining',
          paymentMethod: 'UPI',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      ]);
    final budgetProvider = BudgetProvider(autoFetch: false)
      ..setBudgetsForTesting([
        Budget(
          id: 1,
          category: 'Food & Dining',
          monthlyLimit: 4000,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      ]);
    final reminderProvider = ReminderProvider(autoFetch: false)
      ..setRemindersForTesting([
        PaymentReminder(
          id: 'r1',
          title: 'Rent Bill',
          amount: 12000,
          category: 'Bills & Utilities',
          paymentMethod: 'UPI',
          frequency: ReminderFrequency.monthly,
          nextDueDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
        ),
      ]);

    AnnouncementService.instance.setAnnouncementsForTesting([
      AppAnnouncement(
        id: 'promo_pro_launch',
        title: 'Founding Pro Offer',
        message: 'Lock in ExpenCircle Pro yearly at ₹499/year.',
        category: AnnouncementCategory.promo,
        ctaLabel: 'Explore Plan',
        ctaRoute: 'plan:0',
        startsAt: now.subtract(const Duration(hours: 1)),
        createdAt: now,
      ),
    ]);

    await tester.pumpWidget(
      wrapWithProviders(
        expenseProvider: expenseProvider,
        budgetProvider: budgetProvider,
        reminderProvider: reminderProvider,
        child: const MainScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Bell badge shows 3 alerts (1 due tomorrow bill + 1 >=80% budget + 1 promo)
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byTooltip('Notifications & Alerts'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('BILL REMINDERS (1)'), findsOneWidget);
    expect(find.text('BUDGET ALERTS (1)'), findsOneWidget);
    expect(find.text('UPDATES & OFFERS (1)'), findsOneWidget);
    expect(find.text('Rent Bill'), findsWidgets);
    expect(find.text('Near Limit (88%)'), findsOneWidget);
    expect(find.text('Founding Pro Offer'), findsOneWidget);

    // Clicking promo CTA routes into Plan -> Budgets and dismisses promo
    await tester.tap(find.text('Explore Plan'));
    await tester.pumpAndSettle();

    expect(find.text('Budgets & Bills'), findsOneWidget);
    expect(AnnouncementService.instance.unreadCount, 0);
  });
}
