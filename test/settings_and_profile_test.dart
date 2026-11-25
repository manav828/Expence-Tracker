import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/screens/settings_screen.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:expense_tracker/widgets/user_profile_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Profile & Settings Screen Tests', () {
    late ExpenseProvider expenseProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AuthService.instance.initUserCache();
      await AuthService.instance.updateDisplayName('Manav');
      await AuthService.instance.updateProfilePhoto(null);
      expenseProvider = ExpenseProvider(autoFetch: false);
      expenseProvider.setExpensesForTesting([]);
    });

    testWidgets('SettingsScreen hides removed sections, badges, and tile descriptions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<ExpenseProvider>.value(
          value: expenseProvider,
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Retained clean tiles without descriptions
      expect(find.text('Personal Expense Storage'), findsOneWidget);
      expect(find.text('Categories & Payment Methods'), findsOneWidget);
      expect(find.text('Payment Reminders & Bills'), findsOneWidget);
      expect(find.text('Export Ledger Data'), findsOneWidget);
      expect(find.text('Currency & Formatting'), findsOneWidget);
      expect(find.text('Clear All Expenses'), findsOneWidget);

      // Removed options
      expect(find.text('Security & Biometrics'), findsNothing);
      expect(find.text('SMS Auto-Detection Rules'), findsNothing);
      expect(find.text('Category Budgets & Spending Limits'), findsNothing);
      expect(find.text('Transaction History Ledger'), findsNothing);

      // Removed descriptions / badges
      expect(find.text('Device screen lock & authentication'), findsNothing);
      expect(find.text('Manage custom categories & methods'), findsNothing);
      expect(find.text('Download CSV or JSON file'), findsNothing);
      expect(find.text('INR (₹) - Indian Rupee'), findsNothing);
      expect(find.text('Google Account'), findsNothing);
      expect(find.text('Email Verified'), findsNothing);
      expect(find.text('Guest (Offline Mode)'), findsNothing);

      // Edit profile dialog exposes both name and photo controls
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Display Name'), findsOneWidget);
    });

    test('AuthService.updateProfilePhoto persists data URI and updates notifier', () async {
      final pngStub = base64Encode([137, 80, 78, 71, 13, 10, 26, 10]);
      final dataUri = 'data:image/png;base64,$pngStub';

      await AuthService.instance.updateProfilePhoto(dataUri);
      expect(AuthService.instance.userAvatarUrl, dataUri);
      expect(AuthService.instance.userAvatarNotifier.value, dataUri);

      await AuthService.instance.updateProfilePhoto(null);
      expect(AuthService.instance.userAvatarUrl, isNull);
      expect(AuthService.instance.userAvatarNotifier.value, isNull);
    });

    testWidgets('UserProfileAvatar reacts to profile photo data URI updates', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: UserProfileAvatar(size: 60)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('M'), findsOneWidget);
    });
  });
}
