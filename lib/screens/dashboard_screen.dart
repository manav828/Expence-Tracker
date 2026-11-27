import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/receipt_attachment_sheet.dart';
import '../providers/budget_provider.dart';
import 'budget_screen.dart';
import 'analytics_screen.dart';
import 'category_detail_screen.dart';
import '../utils/category_icons.dart';
import '../widgets/reminder_carousel_banner.dart';
import '../widgets/dashboard_shimmer.dart';
import '../providers/split_provider.dart';
import '../models/split_models.dart';
import 'split/split_group_detail_screen.dart';
import '../core/theme/app_colors.dart';


class DashboardScreen extends StatefulWidget {
  final void Function(String analyticsMode)? onOpenAnalytics;

  const DashboardScreen({super.key, this.onOpenAnalytics});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isSafeguardsDismissed = false;

  void _openAnalytics(BuildContext context, String mode) {
    if (widget.onOpenAnalytics != null) {
      widget.onOpenAnalytics!(mode);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(mode == 'chart' ? 'Breakdown' : 'Ledger'),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF131B2E),
            elevation: 0,
          ),
          body: AnalyticsScreen(initialViewMode: mode),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadDismissedState();
  }

  String get _dismissedPrefKey {
    final now = DateTime.now();
    return 'budget_safeguards_dismissed_${now.year}_${now.month}';
  }

  Future<void> _loadDismissedState() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_dismissedPrefKey) ?? false;
    if (mounted && dismissed) {
      setState(() {
        _isSafeguardsDismissed = true;
      });
    }
  }

  Future<void> _setSafeguardsDismissed(bool dismissed) async {
    setState(() {
      _isSafeguardsDismissed = dismissed;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedPrefKey, dismissed);
  }

  void _dismissSafeguards(BuildContext context) {
    _setSafeguardsDismissed(true);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Budget Safeguards alert dismissed',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.primaryLight,
          onPressed: () => _setSafeguardsDismissed(false),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
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
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.expenses.isEmpty) {
          return const DashboardShimmer();
        }

        return RefreshIndicator(
          onRefresh: () => provider.fetchExpenses(showLoading: false),
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // 1. Executive Header & Greeting Pill
              _buildGreetingRow(context),
              const SizedBox(height: 14),

              // Active Trip Mode Banner
              Builder(
                builder: (context) {
                  SplitProvider? sp;
                  try {
                    sp = Provider.of<SplitProvider>(context);
                  } catch (_) {}
                  final activeGroup = sp?.activeTripGroup;
                  if (sp == null || !sp.isTripModeActive || activeGroup == null) {
                    return const SizedBox.shrink();
                  }
                  return _buildTripModeBanner(context, activeGroup, sp);
                },
              ),

              // 2. Top Spend Summary & Trend Graph Hero Card
              _buildTopSpendHeroCard(context, provider),
              const SizedBox(height: 10),

              // 3. Payment Reminders & Upcoming Bills Carousel Banner
              const ReminderCarouselBanner(margin: EdgeInsets.only(bottom: 10)),

              // 4. Monthly Category Budget Snapshot Card
              _buildBudgetSnapshotCard(context, provider),

              // 5. Compact "Where you spend" Segmented Category Card
              _buildWhereYouSpendCard(context, provider),
              const SizedBox(height: 16),

              // 6. Recent Transactions Ledger
              _buildVerifiedLedgerSection(context, provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTripModeBanner(BuildContext context, SplitGroup group, SplitProvider sp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D34), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24006948),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SplitGroupDetailScreen(group: group),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Trip Mode: ${group.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'New expenses route to this split group • Tap to view',
                        style: TextStyle(
                          color: Color(0xFFD1FAE5),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Open',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 1. Executive Header & Greeting Pill ---
  Widget _buildGreetingRow(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final dateRangeStr =
        '${DateFormat('MMM 1').format(firstDay)} – ${DateFormat('MMM d').format(lastDay)}';

    final hour = now.hour;
    final timeGreeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            timeGreeting,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF131B2E),
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F3FF),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Color(0xFF006577)),
              const SizedBox(width: 6),
              Text(
                dateRangeStr,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3D4A42),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 2. Monthly Category Budget Snapshot Card ---
  Widget _buildBudgetSnapshotCard(BuildContext context, ExpenseProvider provider) {
    if (_isSafeguardsDismissed) return const SizedBox.shrink();

    final budgetProvider = context.watch<BudgetProvider>();
    final budgets = budgetProvider.budgets;
    if (budgets.isEmpty) return const SizedBox.shrink();

    final allProgress = budgetProvider.getAllBudgetProgress(provider.expenses);
    final overspent = budgetProvider.getOverspentBudgets(provider.expenses);
    final topThree = allProgress.take(3).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: overspent.isNotEmpty ? const Color(0xFFFFCDD2) : const Color(0x0A000000),
            width: overspent.isNotEmpty ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Budget Safeguards',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const BudgetScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              'Manage',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Dismiss',
                      child: InkWell(
                        onTap: () => _dismissSafeguards(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F4F7),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0x10000000)),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 15,
                            color: Color(0xFF6D7A72),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            for (var p in topThree) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          p.category,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                        ),
                        Text(
                          '₹${p.spentThisMonth.toStringAsFixed(0)} / ₹${p.limit.toStringAsFixed(0)} (${_formatPercent(p.percentage)}%)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: p.isOverspent
                                ? const Color(0xFFBA1A1A)
                                : p.isNearLimit
                                    ? const Color(0xFFE65100)
                                    : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 6,
                        child: LinearProgressIndicator(
                          value: (p.percentage / 100).clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFFF2F4F7),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            p.isOverspent
                                ? const Color(0xFFBA1A1A)
                                : p.isNearLimit
                                    ? const Color(0xFFE65100)
                                    : const Color(0xFF00855D),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Palette for compact "Where you spend" segmented bar (matches mockup)
  static const List<Color> _spendSegmentPalette = [
    Color(0xFF4B41E1), // Indigo
    Color(0xFF0099B8), // Ocean Cyan
    Color(0xFFF59E0B), // Warm Amber
    Color(0xFF8B5CF6), // Violet
  ];
  static const Color _othersSegmentColor = Color(0xFFE2E8F0);

  // --- 2. Top Spend Summary & Trend Graph Hero Card ---
  Widget _buildTopSpendHeroCard(BuildContext context, ExpenseProvider provider) {
    final now = DateTime.now();
    final double thisMonthSpend = provider.expensesThisMonth;
    final prevMonthDate = DateTime(now.year, now.month - 1, 1);
    final double prevMonthSpend = provider
        .getExpensesForMonth(prevMonthDate.year, prevMonthDate.month)
        .where((e) => e.isExpense && e.amount > 0)
        .fold(0.0, (sum, e) => sum + e.amount);

    final inrFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');
    final inrFmtDecimal = NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN');

    final monthlyExpenses = provider.getExpensesForMonth(now.year, now.month);
    final validExpenses =
        monthlyExpenses.where((e) => e.isExpense && e.amount > 0).toList()
          ..sort((a, b) => a.expenseDate.compareTo(b.expenseDate));

    final points = _buildMonthTrajectoryPoints(validExpenses);
    final List<FlSpot> spots = points.isEmpty
        ? const [
            FlSpot(0, 0),
            FlSpot(1, 0),
            FlSpot(2, 0),
            FlSpot(3, 0),
          ]
        : List.generate(
            points.length,
            (i) => FlSpot(i.toDouble(), points[i].cumulativeAmount),
          );

    final double maxTrendY = points.isEmpty
        ? 100.0
        : math.max(1.0, points.last.cumulativeAmount * 1.25);

    // Comparison badge text
    final String comparisonText;
    final IconData comparisonIcon;
    if (prevMonthSpend > 0) {
      final pctChange = (((thisMonthSpend - prevMonthSpend) / prevMonthSpend) * 100).round();
      if (pctChange < 0) {
        comparisonText = '${pctChange.abs()}% vs last month';
        comparisonIcon = Icons.arrow_downward_rounded;
      } else if (pctChange > 0) {
        comparisonText = '$pctChange% vs last month';
        comparisonIcon = Icons.arrow_upward_rounded;
      } else {
        comparisonText = '0% vs last month';
        comparisonIcon = Icons.remove_rounded;
      }
    } else if (validExpenses.isNotEmpty) {
      comparisonText = '${validExpenses.length} ${validExpenses.length == 1 ? "entry" : "entries"} this month';
      comparisonIcon = Icons.trending_up_rounded;
    } else {
      comparisonText = 'No spend this month';
      comparisonIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF004D34),
            AppColors.primary,
            Color(0xFF00855D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Total Spend + Comparison Pill
          Expanded(
            flex: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "THIS MONTH'S SPEND",
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    inrFmtDecimal.format(thisMonthSpend),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA7F3D0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        comparisonIcon,
                        size: 13,
                        color: const Color(0xFF003825),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          comparisonText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF003825),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Right: Compact "Spending trend" Curve
          Expanded(
            flex: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Spending trend',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 76,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxTrendY,
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        enabled: points.isNotEmpty,
                        handleBuiltInTouches: true,
                        touchTooltipData: LineTouchTooltipData(
                          tooltipRoundedRadius: 8,
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final idx = spot.x.toInt();
                              if (idx < 0 || idx >= points.length) return null;
                              final pt = points[idx];
                              return LineTooltipItem(
                                '${DateFormat('d MMM').format(pt.date)}\n${inrFmt.format(pt.cumulativeAmount)}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.28,
                          color: points.isEmpty
                              ? Colors.white.withValues(alpha: 0.35)
                              : const Color(0xFFB5FCE0),
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: points.isNotEmpty,
                            checkToShowDot: (spot, barData) =>
                                spot.x.toInt() == spots.length - 1,
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                              radius: 4.5,
                              color: Colors.white,
                              strokeWidth: 3,
                              strokeColor: const Color(0x5585F8C4),
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF85F8C4).withValues(alpha: 0.32),
                                const Color(0xFF85F8C4).withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_TrajectoryDataPoint> _buildMonthTrajectoryPoints(List<Expense> validExpenses) {
    final List<_TrajectoryDataPoint> points = [];
    if (validExpenses.isEmpty) return points;

    final Map<DateTime, double> dailySpendMap = {};
    for (final exp in validExpenses) {
      if (exp.isExpense) {
        final dt = exp.dateTime;
        final dayKey = DateTime(dt.year, dt.month, dt.day);
        dailySpendMap[dayKey] = (dailySpendMap[dayKey] ?? 0.0) + exp.amount;
      }
    }
    if (dailySpendMap.isEmpty) return points;

    final sortedDays = dailySpendMap.keys.toList()..sort();
    final firstDay = sortedDays.first;
    final lastDay = sortedDays.last;
    final totalCalendarDays = lastDay.difference(firstDay).inDays + 1;

    if (sortedDays.length == 1 || totalCalendarDays <= 1) {
      points.add(_TrajectoryDataPoint(
        date: firstDay,
        cumulativeAmount: 0.0,
        daySpend: 0.0,
      ));
      points.add(_TrajectoryDataPoint(
        date: firstDay,
        cumulativeAmount: dailySpendMap[firstDay] ?? 0.0,
        daySpend: dailySpendMap[firstDay] ?? 0.0,
      ));
      return points;
    }

    double runningTotal = 0.0;
    for (int i = 0; i < totalCalendarDays; i++) {
      final currentDay = firstDay.add(Duration(days: i));
      final spend = dailySpendMap[currentDay] ?? 0.0;
      runningTotal += spend;
      points.add(_TrajectoryDataPoint(
        date: currentDay,
        cumulativeAmount: runningTotal,
        daySpend: spend,
      ));
    }
    return points;
  }

  // --- 3. Compact "Where you spend" Horizontal Segmented Card ---
  Widget _buildWhereYouSpendCard(BuildContext context, ExpenseProvider provider) {
    final double totalOutflow = provider.expensesThisMonth;
    final categoryMap = provider.categoryTotalsThisMonth;
    final sortedEntries = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<_CategorySpendSegment> segments = [];
    if (totalOutflow > 0 && sortedEntries.isNotEmpty) {
      final topCount = math.min(4, sortedEntries.length);
      for (int i = 0; i < topCount; i++) {
        final entry = sortedEntries[i];
        segments.add(_CategorySpendSegment(
          label: entry.key,
          amount: entry.value,
          color: _spendSegmentPalette[i % _spendSegmentPalette.length],
          isOthers: false,
        ));
      }
      if (sortedEntries.length > 4) {
        final othersAmount = sortedEntries
            .skip(4)
            .fold(0.0, (sum, e) => sum + e.value);
        if (othersAmount > 0) {
          segments.add(_CategorySpendSegment(
            label: 'Others',
            amount: othersAmount,
            color: _othersSegmentColor,
            isOthers: true,
          ));
        }
      }
    }

    final inrFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x0D000000), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08131B2E),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pie_chart, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Where you spend',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                  ],
                ),
              InkWell(
                onTap: () => _openAnalytics(context, 'chart'),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3D4A42),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 15, color: Color(0xFF3D4A42)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (segments.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No expenses recorded this month. Tap + to add one.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF6D7A72)),
                ),
              ],
            )
          else ...[
            // Horizontal Proportional Segmented Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 16,
                child: Row(
                  children: [
                    for (int i = 0; i < segments.length; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(
                        flex: math.max(
                          1,
                          ((segments[i].amount / totalOutflow) * 1000).round(),
                        ),
                        child: Container(color: segments[i].color),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Compact Horizontal Breakdown Columns
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < segments.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (segments[i].isOthers) {
                          _openAnalytics(context, 'chart');
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CategoryDetailScreen(
                                initialCategory: segments[i].label,
                              ),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: segments[i].color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  segments[i].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3D4A42),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${((segments[i].amount / totalOutflow) * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6D7A72),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              inrFmt.format(segments[i].amount),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF131B2E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
        ),
      ),
    );
  }

  // --- 4. Recent Transactions Ledger ---
  Widget _buildVerifiedLedgerSection(BuildContext context, ExpenseProvider provider) {
    final recentItems = provider.expenses.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x0D000000), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08131B2E),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Recent transactions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                  ],
                ),
              InkWell(
                onTap: () => _openAnalytics(context, 'list'),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3D4A42),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 15, color: Color(0xFF3D4A42)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (provider.expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F3FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_outlined, size: 24, color: AppColors.primary),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No transactions yet',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap + to log your first expense or income.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72)),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            for (int i = 0; i < recentItems.length; i++) ...[
              if (i > 0)
                const Divider(height: 16, thickness: 0.7, color: Color(0xFFF1F5F9)),
              _buildTransactionRow(context, recentItems[i]),
            ],
          ],
        ],
        ),
      ),
    );
  }

  Widget _buildTransactionRow(BuildContext context, Expense expense) {
    final dateStr = DateFormat('MMM d, hh:mm a').format(expense.dateTime);
    final title = expense.comment != null && expense.comment!.isNotEmpty
        ? expense.comment!
        : expense.category;
    final isInc = expense.isIncome;
    final iconColor = isInc ? AppColors.primary : _colorForCategory(expense.category);
    final amountStr = isInc
        ? '+₹${expense.amount.toStringAsFixed(2)}'
        : '₹${expense.amount.toStringAsFixed(2)}';

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AddExpenseSheet(expenseToEdit: expense),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(CategoryIcons.get(expense.category), color: iconColor, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF131B2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$dateStr • ${expense.paymentMethod}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF6D7A72)),
                  ),
                  if (expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => FullScreenReceiptViewer.show(
                        context,
                        imageUrl: expense.receiptUrl!,
                        title: '$title Receipt',
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.receipt_long, size: 12, color: AppColors.primary),
                          SizedBox(width: 3),
                          Text(
                            'Bill Attached',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              amountStr,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: isInc ? AppColors.primary : const Color(0xFF131B2E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('food') || lower.contains('dining')) {
      return const Color(0xFF0099B8);
    }
    if (lower.contains('bill') || lower.contains('utilit')) {
      return const Color(0xFF4B41E1);
    }
    if (lower.contains('transport') || lower.contains('travel')) {
      return const Color(0xFF8B5CF6);
    }
    if (lower.contains('rent') || lower.contains('home')) {
      return const Color(0xFFF59E0B);
    }
    return AppColors.primary;
  }
}

class _CategorySpendSegment {
  final String label;
  final double amount;
  final Color color;
  final bool isOthers;

  const _CategorySpendSegment({
    required this.label,
    required this.amount,
    required this.color,
    required this.isOthers,
  });
}

class _TrajectoryDataPoint {
  final DateTime date;
  final double cumulativeAmount;
  final double daySpend;

  const _TrajectoryDataPoint({
    required this.date,
    required this.cumulativeAmount,
    required this.daySpend,
  });
}
