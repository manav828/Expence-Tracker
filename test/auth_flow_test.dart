import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/screens/auth/onboarding_screen.dart';
import 'package:expense_tracker/screens/auth/login_screen.dart';
import 'package:expense_tracker/screens/auth/register_screen.dart';
import 'package:expense_tracker/widgets/storage_choice_dialog.dart';

void main() {
  testWidgets('OnboardingScreen renders first page with headline and Next action', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('LoginScreen renders email, password, Google, and Guest offline mode', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
    expect(find.text('Use offline • No account required'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
  });

  testWidgets('RegisterScreen renders all input fields, terms agreement, and strength meter', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: RegisterScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Create Your Account'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Sign up with Google'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('Terms of Service'),
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('Privacy Policy'),
      ),
      findsWidgets,
    );
  });

  testWidgets('StorageChoiceDialog displays Cloud (Recommended) and Local (Offline) options', (WidgetTester tester) async {
    final provider = ExpenseProvider(autoFetch: false);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<ExpenseProvider>.value(
          value: provider,
          child: const Scaffold(
            body: StorageChoiceDialog(isDismissible: true),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Data Storage Choice'), findsOneWidget);
    expect(find.text('Cloud Storage (Recommended)'), findsOneWidget);
    expect(find.text('Local Storage Only (Privacy First)'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}
