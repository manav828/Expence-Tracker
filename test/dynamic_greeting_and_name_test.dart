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

    testWidgets('DashboardScreen displays simple time greeting without user name', (tester) async {
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

      final hour = DateTime.now().hour;
      final expectedGreeting = hour < 12
          ? 'Good morning'
          : hour < 17
              ? 'Good afternoon'
              : 'Good evening';

      expect(find.text(expectedGreeting), findsOneWidget);
      expect(find.textContaining('Manav'), findsNothing);
      expect(find.textContaining('Alex'), findsNothing);
      expect(
        find.image(const AssetImage('assets/illustrations/first-transaction.webp')),
        findsOneWidget,
      );
      final addTransaction = find.text('Add your first transaction');
      expect(addTransaction, findsOneWidget);
      await tester.tap(addTransaction);
      await tester.pumpAndSettle();
      expect(find.text('Entries (1)'), findsOneWidget);
    });
  });
}
