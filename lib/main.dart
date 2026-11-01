import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/category_icons.dart';
import 'core/utils/invite_code_parser.dart';
import 'providers/budget_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/split_provider.dart';
import 'providers/reminder_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/main_screen.dart';
import 'services/auth_service.dart';
import 'services/storage_preference_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Backward-compatible global function delegating to [InviteCodeParser].
String? extractInviteCode(Uri uri) => InviteCodeParser.extractInviteCode(uri);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CategoryIcons.init();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  await AuthService.instance.initUserCache();

  if (kIsWeb) {
    final initialCode = InviteCodeParser.extractInviteCode(Uri.base);
    if (initialCode != null && initialCode.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.keyPendingInviteCode, initialCode.toUpperCase());
        await prefs.setBool(AppConstants.keyOnboardingCompleted, true);
      } catch (_) {}
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => SplitProvider()),
        ChangeNotifierProvider(create: (_) => ReminderProvider()..loadReminders()),
      ],
      child: const ExpenseTrackerApp(),
    ),
  );
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: appNavigatorKey,
      home: const AppRoot(),
      routes: {
        AppConstants.routeLogin: (_) => const LoginScreen(),
        AppConstants.routeOnboarding: (_) => const OnboardingScreen(),
        AppConstants.routeMain: (_) => MainScreen(navigatorKey: appNavigatorKey),
      },
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _isLoading = true;
  bool _hasSeenOnboarding = false;
  bool _isAuthenticatedOrGuest = false;

  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        _checkAuthState();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAuthState() async {
    final seen = await AuthService.instance.hasCompletedOnboarding();
    final isGuest = await AuthService.instance.isGuest();
    final isAuth = AuthService.instance.isAuthenticated;

    if (isAuth) {
      await StoragePreferenceService.setMode(StorageMode.cloud);
    }

    if (mounted) {
      setState(() {
        _hasSeenOnboarding = seen;
        _isAuthenticatedOrGuest = isAuth || isGuest;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (!_hasSeenOnboarding) {
      return const OnboardingScreen();
    }

    if (!_isAuthenticatedOrGuest) {
      return const LoginScreen();
    }

    return MainScreen(navigatorKey: appNavigatorKey);
  }
}
