import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/expense_provider.dart';
import 'providers/budget_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/history_screen.dart';
import 'screens/search_screen.dart';
import 'screens/budget_screen.dart';
import 'widgets/add_expense_sheet.dart';
import 'widgets/sms_tester_sheet.dart';
import 'widgets/google_sheets_sync_sheet.dart';
import 'widgets/export_data_sheet.dart';
import 'widgets/budget_alert_banner.dart';
import 'widgets/set_budget_sheet.dart';
import 'services/transaction_detection_service.dart';
import 'utils/category_icons.dart';
import 'widgets/category_icon_picker_dialog.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CategoryIcons.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
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
      title: 'Apex Spend',
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
        cardTheme: CardTheme(
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
      home: const MainScreen(),
    );
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
    const BudgetScreen(),
    const _SettingsPlaceholder(),
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
                    setState(() => _currentIndex = 2);
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF131B2E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.trending_up, color: Color(0xFF85F8C4), size: 20),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Apex Spend',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF131B2E),
                  letterSpacing: -0.4,
                ),
              ),
              if (_currentIndex == 2) ...[
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
                    fontSize: 17,
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
              const SizedBox(width: 4),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF85F8C4), width: 2),
                  image: const DecorationImage(
                    image: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80'),
                    fit: BoxFit.cover,
                  ),
                ),
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
                _buildNavItem(1, Icons.bar_chart_outlined, Icons.bar_chart, 'Expenses'),
                const SizedBox(width: 54), // Space for center floating button
                _buildNavItem(2, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Budgets'),
                _buildNavItem(3, Icons.settings_outlined, Icons.settings, 'Settings'),
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
      onTap: () => setState(() => _currentIndex = index),
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

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
      children: [
        const SizedBox(height: 12),
        const Text(
          'Settings & Preferences',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.security, color: Color(0xFF006948)),
                title: const Text('Security & Biometrics', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.sms_outlined, color: Color(0xFF4B41E1)),
                title: const Text('SMS Auto-Detection Rules', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const SmsTesterSheet(),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.category_outlined, color: Color(0xFF006948)),
                title: const Text('Categories & Payment Methods', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCategoryPaymentManager(context),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF006948)),
                title: const Text('Category Budgets & Spending Limits', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const SetBudgetSheet(),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: Color(0xFF4B41E1)),
                title: const Text('Transaction History Ledger', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined, color: Color(0xFF0F9D58)),
                title: const Text('Google Sheets Cloud Sync', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const GoogleSheetsSyncSheet(),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.file_download_outlined, color: Color(0xFF4B41E1)),
                title: const Text('Export Ledger Data', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const ExportDataSheet(),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.currency_exchange, color: Color(0xFF008096)),
                title: const Text('Currency & Formatting', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFBA1A1A)),
                title: const Text('Clear All Expenses', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFBA1A1A))),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.white,
                      title: const Text('Clear All Expenses?'),
                      content: const Text('This will remove all recorded transactions from the ledger.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Clear All', style: TextStyle(color: Color(0xFFBA1A1A))),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    final messenger = ScaffoldMessenger.of(context);
                    await Provider.of<ExpenseProvider>(context, listen: false).clearAll();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('All expenses cleared')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCategoryPaymentManager(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _CategoryPaymentManagerSheet(),
    );
  }
}

class CategoryPaymentManagerSheet extends StatefulWidget {
  const CategoryPaymentManagerSheet({super.key});

  @override
  State<CategoryPaymentManagerSheet> createState() => _CategoryPaymentManagerSheetState();
}

typedef _CategoryPaymentManagerSheet = CategoryPaymentManagerSheet;

class _CategoryPaymentManagerSheetState extends State<CategoryPaymentManagerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _categorySortMode = 'custom'; // 'custom', 'most_used', 'az'
  String _paymentMethodSortMode = 'custom'; // 'custom', 'most_used', 'az'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _promptAdd(BuildContext context, bool isCategory) {
    final controller = TextEditingController();
    String selectedIconKey = isCategory ? 'category' : '';
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedIconData = isCategory
              ? (CategoryIcons.availableIcons.firstWhere(
                  (opt) => opt.key == selectedIconKey,
                  orElse: () => const CategoryIconOption(key: 'category', label: 'General', icon: Icons.category),
                ).icon)
              : Icons.category;

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              isCategory ? 'Add New Category' : 'Add Payment Method',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF131B2E)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: isCategory ? 'Category Name' : 'Payment Method Name',
                    hintText: isCategory ? 'e.g. Subscriptions, Fuel' : 'e.g. NetBanking, Wallet',
                    filled: true,
                    fillColor: const Color(0xFFF2F3FF),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                if (isCategory) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await CategoryIconPickerDialog.show(
                        context,
                        currentIconKey: selectedIconKey,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedIconKey = picked.key;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F3FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF006948).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(selectedIconData, color: const Color(0xFF006948), size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Select Icon',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                              ),
                            ],
                          ),
                          const Row(
                            children: [
                              Text(
                                'Choose',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF006948)),
                              ),
                              Icon(Icons.chevron_right, size: 18, color: Color(0xFF006948)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF6D7A72))),
              ),
              ElevatedButton(
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    final provider = Provider.of<ExpenseProvider>(context, listen: false);
                    if (isCategory) {
                      await CategoryIcons.setCustomIcon(text, selectedIconKey);
                      await provider.addCategory(text);
                    } else {
                      await provider.addPaymentMethod(text);
                    }
                    if (mounted) setState(() {});
                    if (ctx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006948),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _promptEdit(BuildContext context, bool isCategory, String currentName) {
    final controller = TextEditingController(text: currentName);
    String selectedIconKey = isCategory ? CategoryIcons.getKeyForCategory(currentName) : '';
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedIconData = isCategory
              ? (CategoryIcons.availableIcons.firstWhere(
                  (opt) => opt.key == selectedIconKey,
                  orElse: () => const CategoryIconOption(key: 'category', label: 'General', icon: Icons.category),
                ).icon)
              : Icons.category;

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              isCategory ? 'Edit Category' : 'Edit Payment Method',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF131B2E)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: isCategory ? 'Category Name' : 'Payment Method Name',
                    filled: true,
                    fillColor: const Color(0xFFF2F3FF),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                if (isCategory) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await CategoryIconPickerDialog.show(
                        context,
                        currentIconKey: selectedIconKey,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedIconKey = picked.key;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F3FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF006948).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(selectedIconData, color: const Color(0xFF006948), size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Change Icon',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                              ),
                            ],
                          ),
                          const Row(
                            children: [
                              Text(
                                'Choose',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF006948)),
                              ),
                              Icon(Icons.chevron_right, size: 18, color: Color(0xFF006948)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF6D7A72))),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newText = controller.text.trim();
                  if (newText.isNotEmpty) {
                    final provider = Provider.of<ExpenseProvider>(context, listen: false);
                    if (isCategory) {
                      if (newText != currentName) {
                        await CategoryIcons.renameCategory(currentName, newText);
                        await provider.updateCategory(currentName, newText);
                      }
                      await CategoryIcons.setCustomIcon(newText, selectedIconKey);
                    } else {
                      if (newText != currentName) {
                        await provider.updatePaymentMethod(currentName, newText);
                      }
                    }
                    if (mounted) setState(() {});
                    if (ctx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006948),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, bool isCategory, String name) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $name?'),
        content: Text('Are you sure you want to remove "$name" from ${isCategory ? "categories" : "payment methods"}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6D7A72))),
          ),
          TextButton(
            onPressed: () async {
              final provider = Provider.of<ExpenseProvider>(context, listen: false);
              if (isCategory) {
                await CategoryIcons.deleteCategory(name);
                await provider.deleteCategory(name);
              } else {
                await provider.deletePaymentMethod(name);
              }
              if (mounted) setState(() {});
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF006948).withValues(alpha: 0.12) : const Color(0xFFF2F3FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF006948) : Colors.black12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? const Color(0xFF006948) : const Color(0xFF6D7A72),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF006948) : const Color(0xFF6D7A72),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);

    List<String> categories;
    if (_categorySortMode == 'most_used') {
      categories = provider.getSortedCategories(mostUsedFirst: true);
    } else if (_categorySortMode == 'az') {
      categories = List<String>.from(provider.categories)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } else {
      categories = List<String>.from(provider.categories);
    }

    List<String> paymentMethods;
    if (_paymentMethodSortMode == 'most_used') {
      paymentMethods = provider.getSortedPaymentMethods(mostUsedFirst: true);
    } else if (_paymentMethodSortMode == 'az') {
      paymentMethods = List<String>.from(provider.paymentMethods)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } else {
      paymentMethods = List<String>.from(provider.paymentMethods);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Categories & Methods',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                  ),
                  Text(
                    'Drag ⠿ to reorder • Tap pencil to edit',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72)),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF3D4A42)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF006948),
            unselectedLabelColor: const Color(0xFF6D7A72),
            indicatorColor: const Color(0xFF006948),
            tabs: const [
              Tab(text: 'Categories'),
              Tab(text: 'Payment Methods'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Categories tab
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildSortChip(
                                    label: 'Drag & Drop',
                                    icon: Icons.drag_indicator,
                                    isSelected: _categorySortMode == 'custom',
                                    onTap: () => setState(() => _categorySortMode = 'custom'),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSortChip(
                                    label: 'Most Used',
                                    icon: Icons.local_fire_department,
                                    isSelected: _categorySortMode == 'most_used',
                                    onTap: () async {
                                      final sorted = provider.getSortedCategories(mostUsedFirst: true);
                                      await provider.setCustomCategoryOrder(sorted);
                                      setState(() => _categorySortMode = 'most_used');
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSortChip(
                                    label: 'A-Z',
                                    icon: Icons.sort_by_alpha,
                                    isSelected: _categorySortMode == 'az',
                                    onTap: () async {
                                      final sorted = List<String>.from(provider.categories)
                                        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                                      await provider.setCustomCategoryOrder(sorted);
                                      setState(() => _categorySortMode = 'az');
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _promptAdd(context, true),
                            icon: const Icon(Icons.add, size: 16, color: Colors.white),
                            label: const Text('Add Category', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF006948),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: categories.length,
                        onReorder: (oldIndex, newIndex) async {
                          setState(() => _categorySortMode = 'custom');
                          await provider.reorderCategories(oldIndex, newIndex);
                        },
                        itemBuilder: (ctx, i) {
                          final cat = categories[i];
                          final usageCount = provider.getCategoryUsageCount(cat);
                          final catIcon = CategoryIcons.get(cat);

                          return Container(
                            key: ValueKey('cat_$cat'),
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0x0F000000)),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              onTap: () => _promptEdit(context, true, cat),
                              leading: Tooltip(
                                message: 'Tap to change icon',
                                child: InkWell(
                                  onTap: () async {
                                    final currentKey = CategoryIcons.getKeyForCategory(cat);
                                    final picked = await CategoryIconPickerDialog.show(
                                      context,
                                      currentIconKey: currentKey,
                                    );
                                    if (picked != null && mounted) {
                                      await CategoryIcons.setCustomIcon(cat, picked.key);
                                      setState(() {});
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF006948).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(catIcon, size: 20, color: const Color(0xFF006948)),
                                        Positioned(
                                          bottom: 1,
                                          right: 1,
                                          child: Container(
                                            padding: const EdgeInsets.all(1.5),
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.edit, size: 8, color: Color(0xFF006948)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(cat, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  ),
                                  if (usageCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEAEDFF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${usageCount}x',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3323CC)),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                usageCount > 0 ? '$usageCount txns • Drag ⠿ to reorder' : 'Not used yet • Drag ⠿ to reorder',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF6D7A72)),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 19, color: Color(0xFF006948)),
                                    tooltip: 'Edit name & icon',
                                    onPressed: () => _promptEdit(context, true, cat),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFBA1A1A)),
                                    tooltip: 'Delete',
                                    onPressed: () => _confirmDelete(context, true, cat),
                                  ),
                                  ReorderableDragStartListener(
                                    index: i,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                      child: const Icon(Icons.drag_indicator, size: 22, color: Color(0xFF6D7A72)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                // Payment Methods tab
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildSortChip(
                                    label: 'Drag & Drop',
                                    icon: Icons.drag_indicator,
                                    isSelected: _paymentMethodSortMode == 'custom',
                                    onTap: () => setState(() => _paymentMethodSortMode = 'custom'),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSortChip(
                                    label: 'Most Used',
                                    icon: Icons.local_fire_department,
                                    isSelected: _paymentMethodSortMode == 'most_used',
                                    onTap: () async {
                                      final sorted = provider.getSortedPaymentMethods(mostUsedFirst: true);
                                      await provider.setCustomPaymentMethodOrder(sorted);
                                      setState(() => _paymentMethodSortMode = 'most_used');
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSortChip(
                                    label: 'A-Z',
                                    icon: Icons.sort_by_alpha,
                                    isSelected: _paymentMethodSortMode == 'az',
                                    onTap: () async {
                                      final sorted = List<String>.from(provider.paymentMethods)
                                        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                                      await provider.setCustomPaymentMethodOrder(sorted);
                                      setState(() => _paymentMethodSortMode = 'az');
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _promptAdd(context, false),
                            icon: const Icon(Icons.add, size: 16, color: Colors.white),
                            label: const Text('Add Method', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF006948),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: paymentMethods.length,
                        onReorder: (oldIndex, newIndex) async {
                          setState(() => _paymentMethodSortMode = 'custom');
                          await provider.reorderPaymentMethods(oldIndex, newIndex);
                        },
                        itemBuilder: (ctx, i) {
                          final pm = paymentMethods[i];
                          final usageCount = provider.getPaymentMethodUsageCount(pm);
                          final pmIcon = CategoryIcons.getPaymentMethodIcon(pm);

                          return Container(
                            key: ValueKey('pm_$pm'),
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0x0F000000)),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              onTap: () => _promptEdit(context, false, pm),
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3323CC).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(pmIcon, size: 20, color: const Color(0xFF3323CC)),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(pm, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  ),
                                  if (usageCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEAEDFF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${usageCount}x',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3323CC)),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                usageCount > 0 ? '$usageCount txns • Drag ⠿ to reorder' : 'Not used yet • Drag ⠿ to reorder',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF6D7A72)),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 19, color: Color(0xFF006948)),
                                    tooltip: 'Edit name',
                                    onPressed: () => _promptEdit(context, false, pm),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFBA1A1A)),
                                    tooltip: 'Delete',
                                    onPressed: () => _confirmDelete(context, false, pm),
                                  ),
                                  ReorderableDragStartListener(
                                    index: i,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                      child: const Icon(Icons.drag_indicator, size: 22, color: Color(0xFF6D7A72)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

