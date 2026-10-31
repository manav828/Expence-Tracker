import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/expense_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/split_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/search_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/split/split_screen.dart';
import 'screens/split/join_group_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/user_profile_avatar.dart';
import 'widgets/add_expense_sheet.dart';
import 'widgets/sms_tester_sheet.dart';
import 'widgets/budget_alert_banner.dart';
import 'services/transaction_detection_service.dart';
import 'utils/category_icons.dart';
import 'services/auth_service.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'widgets/storage_choice_dialog.dart';
import 'services/storage_preference_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CategoryIcons.init();
  await Supabase.initialize(
    url: 'https://kqchjyfnvzfcxvhaonqz.supabase.co',
    publishableKey: 'sb_publishable_r7uEuebZL7Ed74YQzWlTqg_VnmFZ6It',
  );
  await AuthService.instance.initUserCache();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => SplitProvider()),
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
      title: 'ExpenCircle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme).apply(
          bodyColor: const Color(0xFF131B2E),
          displayColor: const Color(0xFF131B2E),
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF8FF),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF006948), // Imperial Pine Green
          onPrimary: Colors.white,
          primaryContainer: Color(0xFF00855D),
          onPrimaryContainer: Color(0xFFF5FFF7),
          secondary: Color(0xFF4B41E1), // Electric Indigo
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFF645EFB),
          tertiary: Color(0xFF008096), // Ocean Teal
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF131B2E),
          onSurfaceVariant: Color(0xFF3D4A42),
          outline: Color(0xFF6D7A72),
          outlineVariant: Color(0xFFBCCAC0),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x0A000000), width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      navigatorKey: appNavigatorKey,
      home: const AppRoot(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/main': (_) => const MainScreen(),
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
        backgroundColor: Color(0xFFFAF8FF),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF006948)),
        ),
      );
    }

    if (!_hasSeenOnboarding) {
      return const OnboardingScreen();
    }

    if (!_isAuthenticatedOrGuest) {
      return const LoginScreen();
    }

    return const MainScreen();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TransactionDetectionService.initialize(appNavigatorKey);
    _checkWebDeepLink();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StorageChoiceDialog.showIfNeeded(context);
    });
  }

  void _checkWebDeepLink() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kIsWeb) {
        final uri = Uri.base;
        final code = uri.queryParameters['code'] ?? uri.queryParameters['join'] ?? uri.queryParameters['split'];
        if (code != null && code.trim().isNotEmpty) {
          setState(() => _currentIndex = 2);
          appNavigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => JoinGroupScreen(prefilledCode: code.trim()),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        context.read<ExpenseProvider>().fetchExpenses(showLoading: false);
      }
    }
  }

  final List<Widget> _screens = [
    const DashboardScreen(),
    const AnalyticsScreen(),
    const SplitScreen(),
    const BudgetScreen(),
  ];

  void _showActionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Quick Action',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF131B2E),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF006948).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.add_circle, color: Color(0xFF006948)),
              ),
              title: const Text('Add Spend', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Manually record an expense or outflow'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const AddExpenseSheet(),
                );
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4B41E1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.sms, color: Color(0xFF4B41E1)),
              ),
              title: const Text('Bank SMS Auto-Log', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Test or parse HDFC/SBI bank transaction SMS'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const SmsTesterSheet(),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopAppBar(context),
            Consumer2<BudgetProvider, ExpenseProvider>(
              builder: (context, budgetProv, expenseProv, _) {
                final warning = budgetProv.recentOverspendWarning;
                if (warning == null) return const SizedBox.shrink();

                // Auto-clear false or stale warning if the category is not actually overspent
                final overspent = budgetProv.getOverspentBudgets(expenseProv.expenses);
                final isStillOverspent = overspent.any((p) => warning.contains(p.category));
                if (!isStillOverspent) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    budgetProv.clearRecentWarning();
                  });
                  return const SizedBox.shrink();
                }

                return BudgetAlertBanner(
                  message: warning,
                  onDismiss: () => budgetProv.clearRecentWarning(),
                  onViewBudgets: () {
                    budgetProv.clearRecentWarning();
                    setState(() => _currentIndex = 3);
                  },
                );
              },
            ),
            Expanded(child: _screens[_currentIndex]),
          ],
        ),
      ),
      bottomNavigationBar: _buildCustomBottomNav(context),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: Color(0x0D000000), width: 1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Logo & Title
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'screen/logos/logo.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'ExpenCircle',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF131B2E),
                  letterSpacing: -0.4,
                ),
              ),
              if (_currentIndex == 1) ...[
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 16,
                  color: const Color(0xFFBCCAC0).withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Analytics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF006948),
                    letterSpacing: -0.3,
                  ),
                ),
              ] else if (_currentIndex == 2) ...[
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 16,
                  color: const Color(0xFFBCCAC0).withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Split',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF006948),
                    letterSpacing: -0.3,
                  ),
                ),
              ] else if (_currentIndex == 3) ...[
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 16,
                  color: const Color(0xFFBCCAC0).withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Budgets',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF006948),
                    letterSpacing: -0.3,
                  ),
                ),
              ] else ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF85F8C4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF002114),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          // Search, Notification & Profile Avatar
          Row(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
                icon: const Icon(Icons.search_rounded, color: Color(0xFF3D4A42), size: 24),
                tooltip: 'Search & Filter',
              ),
              IconButton(
                onPressed: () {},
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications_none, color: Color(0xFF3D4A42), size: 24),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B41E1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              UserProfileAvatar(
                size: 34,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomBottomNav(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // White floating pill bar
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 24,
                  offset: Offset(0, 4),
                ),
              ],
              border: Border.all(color: const Color(0x0D000000), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
                _buildNavItem(1, Icons.bar_chart_outlined, Icons.bar_chart, 'Analytics'),
                const SizedBox(width: 54), // Space for center floating button
                _buildNavItem(2, Icons.group_outlined, Icons.group, 'Split'),
                _buildNavItem(3, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Budgets'),
              ],
            ),
          ),
          // Elevated Center '+' Button
          Positioned(
            top: -14,
            child: GestureDetector(
              onTap: () => _showActionModal(context),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF006948),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF006948).withValues(alpha: 0.42),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _currentIndex = index);
        if (index == 2) {
          context.read<SplitProvider>().loadGroups(isBackgroundRefresh: true);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? const Color(0xFF006948) : const Color(0xFF6D7A72),
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF006948) : const Color(0xFF6D7A72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
