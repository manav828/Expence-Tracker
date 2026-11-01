import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/models/payment_reminder.dart';
import 'package:expense_tracker/providers/reminder_provider.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/split_provider.dart';
import 'package:expense_tracker/screens/dashboard_screen.dart';
import 'package:expense_tracker/screens/payment_reminders_screen.dart';
import 'package:expense_tracker/widgets/reminder_carousel_banner.dart';
import 'package:expense_tracker/widgets/add_edit_reminder_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Payment Reminder UI & Flow Tests', () {
    late ReminderProvider reminderProvider;
    late ExpenseProvider expenseProvider;
    late BudgetProvider budgetProvider;
    late SplitProvider splitProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      reminderProvider = ReminderProvider();
      expenseProvider = ExpenseProvider(autoFetch: false);
      budgetProvider = BudgetProvider(autoFetch: false);
      splitProvider = SplitProvider();

      expenseProvider.setExpensesForTesting([]);
      budgetProvider.setBudgetsForTesting([]);
    });

    testWidgets('Dashboard renders ReminderCarouselBanner when reminders exist', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));

      reminderProvider.setRemindersForTesting([
        PaymentReminder(
          id: 'rem-1',
          title: 'Flat Rent',
          amount: 15000.0,
          category: 'Bills & Utilities',
          paymentMethod: 'UPI',
          frequency: ReminderFrequency.monthly,
          nextDueDate: tomorrow,
          isActive: true,
        ),
        PaymentReminder(
          id: 'rem-2',
          title: 'Wi-Fi Internet',
          amount: 999.0,
          category: 'Bills & Utilities',
          paymentMethod: 'UPI',
          frequency: ReminderFrequency.monthly,
          nextDueDate: now.add(const Duration(days: 4)),
          isActive: true,
        ),
      ]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: reminderProvider),
            ChangeNotifierProvider.value(value: expenseProvider),
            ChangeNotifierProvider.value(value: budgetProvider),
            ChangeNotifierProvider.value(value: splitProvider),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check banner exists
      expect(find.byType(ReminderCarouselBanner), findsOneWidget);
      expect(find.text('Flat Rent'), findsOneWidget);
      expect(find.textContaining('₹15,000'), findsOneWidget);
      expect(find.text('Mark Paid'), findsOneWidget);

      // Verify dismiss 'X' button works
      final dismissButton = find.byIcon(Icons.close_rounded);
      expect(dismissButton, findsOneWidget);
      await tester.tap(dismissButton);
      await tester.pumpAndSettle();

      // Banner should now be dismissed
      expect(reminderProvider.isBannerDismissed, isTrue);
      expect(find.text('Flat Rent'), findsNothing);
    });

    testWidgets('PaymentRemindersScreen renders summary and tabs', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));

      reminderProvider.setRemindersForTesting([
        PaymentReminder(
          id: 'rem-1',
          title: 'Electricity Bill',
          amount: 2450.0,
          category: 'Bills & Utilities',
          paymentMethod: 'UPI',
          frequency: ReminderFrequency.monthly,
          nextDueDate: tomorrow,
          isActive: true,
        ),
        PaymentReminder(
          id: 'rem-2',
          title: 'Old Gym Sub',
          amount: 1500.0,
          category: 'Health & Wellness',
          paymentMethod: 'Card',
          frequency: ReminderFrequency.monthly,
          nextDueDate: now.subtract(const Duration(days: 5)),
          isActive: false, // Paused
        ),
        PaymentReminder(
          id: 'rem-3',
          title: 'Annual Car Insurance',
          amount: 12000.0,
          category: 'General',
          paymentMethod: 'Card',
          frequency: ReminderFrequency.oneTime,
          nextDueDate: now.subtract(const Duration(days: 2)),
          isActive: true,
          isCompleted: true, // Completed
        ),
      ]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: reminderProvider),
            ChangeNotifierProvider.value(value: expenseProvider),
            ChangeNotifierProvider.value(value: splitProvider),
          ],
          child: const MaterialApp(
            home: PaymentRemindersScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header committed card
      expect(find.text('Monthly Fixed Bills Commitment'), findsOneWidget);
      expect(find.text('Electricity Bill'), findsWidgets);
      expect(find.text('₹2,450'), findsWidgets);

      // Switch to Paused tab
      await tester.tap(find.text('Paused (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Old Gym Sub'), findsWidgets);

      // Switch to Completed tab
      await tester.tap(find.text('Completed (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Annual Car Insurance'), findsWidgets);
    });

    testWidgets('AddEditReminderSheet renders frequency chips and controls', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: reminderProvider),
            ChangeNotifierProvider.value(value: expenseProvider),
            ChangeNotifierProvider.value(value: splitProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AddEditReminderSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Add Payment Reminder'), findsOneWidget);
      expect(find.text('Bill / Reminder Name'), findsOneWidget);
      expect(find.text('Amount (₹)'), findsOneWidget);
      expect(find.text('One-Time'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('Split with Group'), findsOneWidget);
      expect(find.text('Set Payment Reminder'), findsOneWidget);

      // Tap One-Time frequency chip
      await tester.tap(find.text('One-Time'));
      await tester.pumpAndSettle();
      expect(find.text('Due Date (One-Time)'), findsOneWidget);

      // Tap Weekly frequency chip
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      expect(find.text('Next Due Date (Repeats weekly)'), findsOneWidget);
    });
  });
}
