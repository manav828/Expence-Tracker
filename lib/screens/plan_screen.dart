import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/reminder_provider.dart';
import 'budget_screen.dart';
import 'payment_reminders_screen.dart';

/// Unified Monthly Planning hub combining Category Budgets (sub-tab 0)
/// and Bills & Payment Reminders (sub-tab 1) under Tab 4 ("Plan").
class PlanScreen extends StatefulWidget {
  final int initialSubTab;
  final ValueNotifier<int>? subTabNotifier;

  const PlanScreen({
    super.key,
    this.initialSubTab = 0,
    this.subTabNotifier,
  });

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late int _activeSubTab;

  @override
  void initState() {
    super.initState();
    _activeSubTab = (widget.subTabNotifier?.value ?? widget.initialSubTab).clamp(0, 1);
    widget.subTabNotifier?.addListener(_onExternalTabChanged);
  }

  @override
  void dispose() {
    widget.subTabNotifier?.removeListener(_onExternalTabChanged);
    super.dispose();
  }

  void _onExternalTabChanged() {
    final next = widget.subTabNotifier?.value;
    if (next != null && next != _activeSubTab && mounted) {
      setState(() => _activeSubTab = next.clamp(0, 1));
    }
  }

  void _selectSubTab(int idx) {
    setState(() => _activeSubTab = idx);
    if (widget.subTabNotifier != null && widget.subTabNotifier!.value != idx) {
      widget.subTabNotifier!.value = idx;
    }
  }

  @override
  Widget build(BuildContext context) {
    final remProvider = context.watch<ReminderProvider>();
    final budgetProvider = context.watch<BudgetProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();

    final urgentBillsCount = remProvider.notificationBadgeCount;
    final budgetAlertCount = budgetProvider
        .getAllBudgetProgress(expenseProvider.expenses)
        .where((p) => p.isOverspent || p.isNearLimit)
        .length;

    return ColoredBox(
      color: AppColors.background,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0x0D000000), width: 1),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSubTabChip(
                      index: 0,
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Budgets',
                      badgeCount: budgetAlertCount,
                      badgeColor: const Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildSubTabChip(
                      index: 1,
                      icon: Icons.receipt_long_outlined,
                      label: 'Bills & Reminders',
                      badgeCount: urgentBillsCount,
                      badgeColor: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _activeSubTab,
              children: const [
                BudgetScreen(),
                PaymentRemindersScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabChip({
    required int index,
    required IconData icon,
    required String label,
    required int badgeCount,
    required Color badgeColor,
  }) {
    final isSelected = _activeSubTab == index;
    return InkWell(
      onTap: () => _selectSubTab(index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : badgeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
