import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/invite_code_parser.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/split_provider.dart';
import '../providers/reminder_provider.dart';
import '../services/split_service.dart';
import '../services/transaction_detection_service.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/budget_alert_banner.dart';
import '../widgets/sms_tester_sheet.dart';
import '../widgets/storage_choice_dialog.dart';
import '../widgets/user_profile_avatar.dart';
import 'analytics_screen.dart';
import 'budget_screen.dart';
import 'dashboard_screen.dart';
import 'payment_reminders_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'split/join_group_screen.dart';
import 'split/split_group_detail_screen.dart';
import 'split/split_screen.dart';

class MainScreen extends StatefulWidget {
  final GlobalKey<NavigatorState>? navigatorKey;

  const MainScreen({super.key, this.navigatorKey});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  static String? _handledWebDeepLinkCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.navigatorKey != null) {
      TransactionDetectionService.initialize(widget.navigatorKey!);
    }

    if (kIsWeb) {
      final code = InviteCodeParser.extractInviteCode(Uri.base);
      if (code != null && code.trim().isNotEmpty) {
        _currentIndex = 2; // Immediately switch to Split tab for invite deep link
      }
    }

    _checkWebDeepLink();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StorageChoiceDialog.showIfNeeded(context);
    });
  }

  void _checkWebDeepLink() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        String? cleanCode = kIsWeb ? InviteCodeParser.extractInviteCode(Uri.base)?.toUpperCase() : null;
        cleanCode ??= prefs.getString(AppConstants.keyPendingInviteCode)?.trim().toUpperCase();

        if (cleanCode == null || cleanCode.isEmpty) return;
        if (_handledWebDeepLinkCode == cleanCode) return;
        _handledWebDeepLinkCode = cleanCode;

        if (mounted) {
          setState(() {
            _currentIndex = 2;
          });
        }

        if (!mounted) return;
        final navState = widget.navigatorKey?.currentState ?? Navigator.of(context);
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null && mounted) {
          final group = await SplitService.instance.getGroupByInviteCode(cleanCode);
          if (group != null) {
            final members = await SplitService.instance.getMembers(group.id);
            final alreadyMember = members.any((m) => m.userId == currentUser.id);

            if (alreadyMember) {
              try {
                await prefs.remove(AppConstants.keyPendingInviteCode);
              } catch (_) {}

              await navState.push(
                MaterialPageRoute(
                  builder: (_) => SplitGroupDetailScreen(group: group),
                ),
              );
              if (mounted) {
                context.read<SplitProvider>().loadGroups();
              }
              return;
            }
          }
        }

        // If not logged in or NOT yet a member of this group:
        if (mounted) {
          await navState.push(
            MaterialPageRoute(
              builder: (_) => JoinGroupScreen(prefilledCode: cleanCode),
            ),
          );
          if (mounted) {
            context.read<SplitProvider>().loadGroups();
          }
        }
      } catch (e) {
        debugPrint('Error in _checkWebDeepLink: $e');
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

  final List<Widget> _screens = const [
    DashboardScreen(),
    AnalyticsScreen(),
    SplitScreen(),
    BudgetScreen(),
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
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.add_circle, color: AppColors.primary),
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
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.sms, color: AppColors.secondary),
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
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              if (_currentIndex == 1) ...[
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 16,
                  color: AppColors.outlineVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Analytics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.3,
                  ),
                ),
              ] else if (_currentIndex == 2) ...[
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 16,
                  color: AppColors.outlineVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Split',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.3,
                  ),
                ),
              ] else if (_currentIndex == 3) ...[
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 16,
                  color: AppColors.outlineVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Budgets',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.3,
                  ),
                ),
              ] else ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentMint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onAccentMint,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
                icon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 24),
                tooltip: 'Search & Filter',
              ),
              Consumer<ReminderProvider>(
                builder: (context, remProvider, _) {
                  final badgeCount = remProvider.notificationBadgeCount;
                  return IconButton(
                    tooltip: 'Payment Reminders & Bills',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PaymentRemindersScreen()),
                      );
                    },
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_outlined, color: AppColors.textSecondary, size: 24),
                        if (badgeCount > 0)
                          Positioned(
                            top: -2,
                            right: -3,
                            child: Container(
                              padding: const EdgeInsets.all(3.5),
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Text(
                                badgeCount > 9 ? '9+' : '$badgeCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
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
                const SizedBox(width: 54),
                _buildNavItem(2, Icons.group_outlined, Icons.group, 'Split'),
                _buildNavItem(3, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Budgets'),
              ],
            ),
          ),
          Positioned(
            top: -14,
            child: GestureDetector(
              onTap: () => _showActionModal(context),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.42),
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
              color: isSelected ? AppColors.primary : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
