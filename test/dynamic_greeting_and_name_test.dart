import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/reminder_provider.dart';
import 'package:expense_tracker/providers/split_provider.dart';
import 'package:expense_tracker/screens/dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dynamic Greeting and Profile Name Customization Tests', () {
    late ExpenseProvider expenseProvider;
    late BudgetProvider budgetProvider;
    late ReminderProvider reminderProvider;
    late SplitProvider splitProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AuthService.instance.initUserCache();

      expenseProvider = ExpenseProvider();
      budgetProvider = BudgetProvider();
      reminderProvider = ReminderProvider();
      splitProvider = SplitProvider();

      expenseProvider.setExpensesForTesting([]);
      budgetProvider.setBudgetsForTesting([]);
      reminderProvider.setRemindersForTesting([]);
    });

    test('AuthService.updateDisplayName updates cached display name and notifier', () async {
      final auth = AuthService.instance;
      expect(auth.userDisplayName, 'Guest User');

      await auth.updateDisplayName('Manav');
      expect(auth.userDisplayName, 'Manav');
      expect(auth.userNameNotifier.value, 'Manav');

      await auth.updateDisplayName('Manav Satasiya');
      expect(auth.userDisplayName, 'Manav Satasiya');
      expect(auth.userNameNotifier.value, 'Manav Satasiya');
    });

    testWidgets('DashboardScreen displays dynamic greeting and reacts to name updates', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await AuthService.instance.updateDisplayName('Manav');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: expenseProvider),
            ChangeNotifierProvider.value(value: budgetProvider),
            ChangeNotifierProvider.value(value: reminderProvider),
            ChangeNotifierProvider.value(value: splitProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DashboardScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check that greeting contains Manav
      expect(find.textContaining('Manav'), findsOneWidget);

      // Verify that there is NO hardcoded "Alex"
      expect(find.textContaining('Alex'), findsNothing);

      // Tap on the greeting to open the personalization dialog
      final greetingFinder = find.textContaining('Manav');
      await tester.tap(greetingFinder);
      await tester.pumpAndSettle();

      // Check dialog exists
      expect(find.text('Personalize Your Name'), findsOneWidget);
      expect(find.text('Save Name'), findsOneWidget);

      // Change name to Rahul
      await tester.enterText(find.byType(TextField), 'Rahul');
      await tester.tap(find.text('Save Name'));
      await tester.pumpAndSettle();

      // Greeting should now update dynamically to Rahul
      expect(find.textContaining('Rahul'), findsOneWidget);
      expect(AuthService.instance.userDisplayName, 'Rahul');
    });
  });
}
