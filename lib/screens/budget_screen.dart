import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';
import '../widgets/set_budget_sheet.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  void _openSetBudgetSheet(BuildContext context, {Budget? budget, String? category, double? initialAmount}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SetBudgetSheet(
        budgetToEdit: budget,
        initialCategory: category,
        initialAmount: initialAmount,
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'dining':
      case 'dining & restaurants':
      case 'food & dining':
      case 'food':
        return Icons.restaurant;
      case 'groceries':
      case 'groceries & essentials':
        return Icons.shopping_cart;
      case 'housing':
      case 'housing & utilities':
      case 'rent':
        return Icons.roofing;
      case 'health':
      case 'health & wellness':
      case 'wellness':
        return Icons.favorite_border;
      case 'transport':
      case 'transport & fuel':
        return Icons.directions_car;
      case 'entertainment':
      case 'entertainment & streaming':
        return Icons.tv;
      case 'shopping':
        return Icons.shopping_bag;
      case 'tech & gear':
      case 'tech':
        return Icons.devices;
      case 'bills & utilities':
        return Icons.receipt;
      case 'investment':
        return Icons.trending_up;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryBaseColor(String category) {
    switch (category.toLowerCase()) {
      case 'housing':
      case 'housing & utilities':
        return const Color(0xFF006948);
      case 'groceries':
      case 'groceries & essentials':
        return const Color(0xFFF59E0B);
      case 'dining':
      case 'dining & restaurants':
      case 'food & dining':
        return const Color(0xFFBA1A1A);
      case 'health':
      case 'health & wellness':
      case 'wellness':
        return const Color(0xFF006577);
      case 'transport':
      case 'transport & fuel':
        return const Color(0xFF4B41E1);
      case 'entertainment':
      case 'entertainment & streaming':
        return const Color(0xFF008096);
      case 'shopping':
        return const Color(0xFFE91E63);
      case 'tech & gear':
        return const Color(0xFF645EFB);
      default:
        return const Color(0xFF006948);
    }
  }

  String _formatCompactAmount(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}k';
    } else {
      return '₹${amount.toStringAsFixed(0)}';
    }
  }

  String _formatPercent(double p) {
    if (p < 100.0 && p >= 99.95) {
      return '99.9';
    }
    final s = p.toStringAsFixed(1);
    if (s.endsWith('.0')) {
      return p.toStringAsFixed(0);
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = context.watch<BudgetProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();

    if (budgetProvider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF006948)));
    }

    final budgets = budgetProvider.budgets;
    final List<Expense> expenses = expenseProvider.expenses;
    final allProgress = budgetProvider.getAllBudgetProgress(expenses);
    final overspentList = budgetProvider.getOverspentBudgets(expenses);

    final totalBudget = budgetProvider.getTotalBudgetLimit();
    final totalSpent = budgetProvider.getTotalBudgetSpent(expenses);
    final overallPercentage = totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0.0;

    // Remaining days in month
    final now = DateTime.now();
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = (lastDayOfMonth - now.day).clamp(0, 31);

    // Month display string (e.g. Sep 2026)
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final currentMonthStr = '${monthNames[now.month - 1]} ${now.year}';

    // Sort active budget progress by risk: overspent first, then near limit, then safe
    final sortedProgress = List<BudgetProgress>.from(allProgress)..sort((a, b) {
      if (a.isOverspent && !b.isOverspent) return -1;
      if (!a.isOverspent && b.isOverspent) return 1;
      if (a.isNearLimit && !b.isNearLimit) return -1;
      if (!a.isNearLimit && b.isNearLimit) return 1;
      return b.percentage.compareTo(a.percentage);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          // 1. Header with Cycle Pill Selector & Add Budget Button
          _buildCycleHeader(context, currentMonthStr, daysRemaining),
          const SizedBox(height: 16),

          // 2. Hero Visual Donut Breakdown Card
          _buildHeroDonutCard(
            totalBudget: totalBudget,
            totalSpent: totalSpent,
            overallPercentage: overallPercentage,
            allProgress: sortedProgress,
          ),
          const SizedBox(height: 16),

          // 3. Overspent Alert Banner
          if (overspentList.isNotEmpty) ...[
            _buildOverspendAlertBanner(context, overspentList),
            const SizedBox(height: 16),
          ],

          // 4. Active Category Budgets Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Active Categories',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF131B2E),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAEDFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${budgets.length} Budgets',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3D4A42),
                      ),
                    ),
                  ),
                ],
              ),
              const Text(
                'Sorted by risk',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6D7A72),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4b. Category Budget Cards or Empty State
          if (budgets.isEmpty)
            _buildNoBudgetsPlaceholder(context)
          else
            for (var progress in sortedProgress) ...[
              _buildEnvelopeCard(context, progress, daysRemaining),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  // 1. Cycle Pill Selector & Add Button
  Widget _buildCycleHeader(BuildContext context, String currentMonthStr, int daysRemaining) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFBCCAC0).withValues(alpha: 0.3)),
                boxShadow: const [
                  BoxShadow(color: Color(0x06131B2E), blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month, size: 15, color: Color(0xFF006948)),
                  const SizedBox(width: 6),
                  Text(
                    currentMonthStr,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF131B2E),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more, size: 15, color: Color(0xFF6D7A72)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$daysRemaining days left',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6D7A72),
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _openSetBudgetSheet(context),
          icon: const Icon(Icons.add, size: 16, color: Colors.white),
          label: const Text(
            'Add Budget',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF006948),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            elevation: 2,
            shadowColor: const Color(0x40006948),
          ),
        ),
      ],
    );
  }

  // 2. Hero Visual Donut Breakdown Card
  Widget _buildHeroDonutCard({
    required double totalBudget,
    required double totalSpent,
    required double overallPercentage,
    required List<BudgetProgress> allProgress,
  }) {
    final isExceeded = totalSpent > totalBudget && totalBudget > 0;
    final remaining = (totalBudget - totalSpent).clamp(0.0, totalBudget);

    String healthLabel;
    Color healthBadgeBg;
    Color healthBadgeText;

    if (isExceeded) {
      healthLabel = 'Over Budget';
      healthBadgeBg = const Color(0xFFFFDAD6);
      healthBadgeText = const Color(0xFFBA1A1A);
    } else if (overallPercentage >= 75) {
      healthLabel = 'Near Ceiling';
      healthBadgeBg = const Color(0xFFFEF3C7);
      healthBadgeText = const Color(0xFFB45309);
    } else {
      healthLabel = 'On Track';
      healthBadgeBg = const Color(0xFF85F8C4).withValues(alpha: 0.4);
      healthBadgeText = const Color(0xFF006948);
    }

    // Top categories for donut legend
    final legendItems = allProgress.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFBCCAC0).withValues(alpha: 0.2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A131B2E),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OVERALL HEALTH',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Color(0xFF6D7A72),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    totalBudget > 0
                        ? '${overallPercentage.toStringAsFixed(1)}% of monthly ceiling deployed'
                        : 'No category budgets active',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6D7A72),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: healthBadgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  healthLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: healthBadgeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Donut Chart & Legend Row
          Row(
            children: [
              // Custom Donut Ring
              SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(130, 130),
                      painter: BudgetDonutPainter(
                        items: allProgress,
                        totalBudget: totalBudget > 0 ? totalBudget : 1.0,
                        strokeWidth: 12.0,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isExceeded ? 'EXCEEDED' : 'REMAINING',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: Color(0xFF6D7A72),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          isExceeded
                              ? '₹${(totalSpent - totalBudget).toStringAsFixed(0)}'
                              : '₹${remaining.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: isExceeded ? const Color(0xFFBA1A1A) : const Color(0xFF131B2E),
                          ),
                        ),
                        Text(
                          'of ${_formatCompactAmount(totalBudget)} cap',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6D7A72),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),

              // Donut Legend
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: legendItems.isEmpty
                      ? [
                          const Text(
                            'Create category limits to visualize your monthly ceiling',
                            style: TextStyle(fontSize: 11, color: Color(0xFF6D7A72)),
                          )
                        ]
                      : legendItems.map((item) {
                          final color = item.isOverspent
                              ? const Color(0xFFBA1A1A)
                              : _getCategoryBaseColor(item.category);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.category,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF131B2E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatCompactAmount(item.spentThisMonth),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: item.isOverspent
                                        ? const Color(0xFFBA1A1A)
                                        : const Color(0xFF131B2E),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. Overspent Alert Banner
  Widget _buildOverspendAlertBanner(BuildContext context, List<BudgetProgress> overspent) {
    final topOverspent = overspent.first;
    final excess = topOverspent.spentThisMonth - topOverspent.limit;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDAD6).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBA1A1A).withValues(alpha: 0.25)),
        boxShadow: const [
          BoxShadow(color: Color(0x06BA1A1A), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0x20BA1A1A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error, color: Color(0xFFBA1A1A), size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Color(0xFF131B2E)),
                children: [
                  TextSpan(
                    text: topOverspent.category,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' exceeds cap by '),
                  TextSpan(
                    text: '₹${excess.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFBA1A1A)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _openSetBudgetSheet(context, budget: topOverspent.budget),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDAD6).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Adjust',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFBA1A1A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4b. Category Envelope Card (Pill Envelope Architecture)
  Widget _buildEnvelopeCard(BuildContext context, BudgetProgress progress, int daysRemaining) {
    final percent = progress.percentage;
    final isOver = progress.isOverspent;
    final isNear = progress.isNearLimit;

    Color cardBorder;
    Color iconBg;
    Color iconColor;
    Color badgeBg;
    Color badgeText;
    String badgeLabel;
    Color meterFill;
    String footerLeftText;
    Color footerLeftColor;
    String footerRightText;

    final categoryIcon = _getCategoryIcon(progress.category);

    if (isOver) {
      final excess = progress.spentThisMonth - progress.limit;
      cardBorder = const Color(0xFFBA1A1A).withValues(alpha: 0.25);
      iconBg = const Color(0xFFFFDAD6).withValues(alpha: 0.6);
      iconColor = const Color(0xFFBA1A1A);
      badgeBg = const Color(0xFFFFDAD6).withValues(alpha: 0.7);
      badgeText = const Color(0xFFBA1A1A);
      badgeLabel = 'Overspend (${_formatPercent(percent)}%)';
      meterFill = const Color(0xFFBA1A1A);
      footerLeftText = 'Exceeded by ₹${excess.toStringAsFixed(0)}';
      footerLeftColor = const Color(0xFFBA1A1A);
      footerRightText = 'Tap to edit';
    } else if (isNear) {
      final left = progress.limit - progress.spentThisMonth;
      cardBorder = const Color(0xFFF59E0B).withValues(alpha: 0.3);
      iconBg = const Color(0xFFFEF3C7);
      iconColor = const Color(0xFFB45309);
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFFB45309);
      badgeLabel = '${_formatPercent(percent)}% used';
      meterFill = const Color(0xFFF59E0B);
      footerLeftText = '₹${left.toStringAsFixed(0)} left to spend';
      footerLeftColor = const Color(0xFFB45309);
      footerRightText = '$daysRemaining days left';
    } else {
      final left = progress.limit - progress.spentThisMonth;
      cardBorder = const Color(0xFFBCCAC0).withValues(alpha: 0.22);
      iconBg = const Color(0xFF85F8C4).withValues(alpha: 0.4);
      iconColor = const Color(0xFF006948);
      badgeBg = const Color(0xFF85F8C4).withValues(alpha: 0.4);
      badgeText = const Color(0xFF006948);
      badgeLabel = 'Safe (${_formatPercent(percent)}%)';
      meterFill = const Color(0xFF006948);
      footerLeftText = '₹${left.toStringAsFixed(0)} left';
      footerLeftColor = const Color(0xFF006948);
      footerRightText = percent < 35 ? 'Low activity' : 'Well paced';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: isOver ? 1.4 : 1.0),
        boxShadow: const [
          BoxShadow(color: Color(0x06131B2E), blurRadius: 6, offset: Offset(0, 1)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSetBudgetSheet(context, budget: progress.budget),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Icon + Names + Status Badge
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(categoryIcon, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            progress.category,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF131B2E),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '₹${progress.spentThisMonth.toStringAsFixed(0)} spent of ₹${progress.limit.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6D7A72),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: badgeText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Micro Meter Bar
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAEDFF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (percent / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: meterFill,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Footer Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      footerLeftText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: footerLeftColor,
                      ),
                    ),
                    Text(
                      footerRightText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6D7A72),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoBudgetsPlaceholder(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBCCAC0).withValues(alpha: 0.2)),
        boxShadow: const [
          BoxShadow(color: Color(0x04131B2E), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFEAEDFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_outlined, size: 32, color: Color(0xFF006948)),
          ),
          const SizedBox(height: 12),
          const Text(
            'No Category Budgets Set',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap "+ Add Budget" above to set a monthly limit for any category.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72)),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for the Multi-Segment Donut Chart
class BudgetDonutPainter extends CustomPainter {
  final List<BudgetProgress> items;
  final double totalBudget;
  final double strokeWidth;

  BudgetDonutPainter({
    required this.items,
    required this.totalBudget,
    this.strokeWidth = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track ring
    final bgPaint = Paint()
      ..color = const Color(0xFFEAEDFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    if (items.isEmpty || totalBudget <= 0) return;

    // Start angle from top (-90 degrees)
    double currentAngle = -3.141592653589793 / 2;

    for (var item in items) {
      if (item.spentThisMonth <= 0) continue;

      final sweepAngle = (item.spentThisMonth / totalBudget).clamp(0.0, 1.0) * (2 * 3.141592653589793);
      if (sweepAngle <= 0.02) continue;

      Color segmentColor;
      if (item.isOverspent) {
        segmentColor = const Color(0xFFBA1A1A);
      } else {
        segmentColor = _getSegmentColor(item.category);
      }

      final segmentPaint = Paint()
        ..color = segmentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        sweepAngle,
        false,
        segmentPaint,
      );

      currentAngle += sweepAngle;
    }
  }

  Color _getSegmentColor(String category) {
    switch (category.toLowerCase()) {
      case 'housing':
      case 'housing & utilities':
        return const Color(0xFF006948);
      case 'groceries':
      case 'groceries & essentials':
        return const Color(0xFFF59E0B);
      case 'dining':
      case 'dining & restaurants':
      case 'food & dining':
        return const Color(0xFFBA1A1A);
      case 'health':
      case 'health & wellness':
        return const Color(0xFF006577);
      case 'transport':
      case 'transport & fuel':
        return const Color(0xFF4B41E1);
      default:
        return const Color(0xFF645EFB);
    }
  }

  @override
  bool shouldRepaint(covariant BudgetDonutPainter oldDelegate) => true;
}
