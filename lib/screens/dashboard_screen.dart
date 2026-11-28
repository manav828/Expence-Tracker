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
              if (provider.expenses.isNotEmpty) ...[
                _buildTopSpendHeroCard(context, provider),
                const SizedBox(height: 10),
              ],

              // 3. Payment Reminders & Upcoming Bills Carousel Banner
              const ReminderCarouselBanner(margin: EdgeInsets.only(bottom: 10)),

              // 4. Monthly Category Budget Snapshot Card
              _buildBudgetSnapshotCard(context, provider),

              if (provider.expenses.isEmpty)
                _buildFirstTransactionCard(context)
              else ...[
                _buildWhereYouSpendCard(context, provider),
                const SizedBox(height: 16),
                _buildVerifiedLedgerSection(context, provider),
              ],
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
    final monthlyExpenses = provider
        .getExpensesForMonth(now.year, now.month)
        .where((expense) => expense.isExpense)
        .toList();
    final thisMonthSpend = provider.expensesThisMonth;
    final prevMonth = DateTime(now.year, now.month - 1);
    final prevMonthSpend = provider
        .getExpensesForMonth(prevMonth.year, prevMonth.month)
        .where((expense) => expense.isExpense)
        .fold(0.0, (sum, expense) => sum + expense.amount);
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    final String comparisonText;
    final IconData comparisonIcon;
    if (prevMonthSpend > 0) {
      final change = ((thisMonthSpend - prevMonthSpend) / prevMonthSpend * 100).round();
      comparisonText = '${change.abs()}% vs last month total';
      comparisonIcon = change == 0
          ? Icons.remove_rounded
          : change < 0
              ? Icons.arrow_downward_rounded
              : Icons.arrow_upward_rounded;
    } else if (monthlyExpenses.isNotEmpty) {
      final entry = monthlyExpenses.length == 1 ? 'expense' : 'expenses';
      comparisonText = '${monthlyExpenses.length} $entry this month';
      comparisonIcon = Icons.receipt_long_outlined;
    } else {
      comparisonText = 'No expenses this month';
      comparisonIcon = Icons.check_circle_outline_rounded;
    }

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "THIS MONTH'S SPEND",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: AppColors.primaryLight,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          currency.format(thisMonthSpend),
          style: const TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w800,
            color: AppColors.onPrimary,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primaryBorder,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(comparisonIcon, size: 14, color: AppColors.primaryDeep),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  comparisonText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryContainer],
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (monthlyExpenses.isEmpty) return summary;
          final chart = _buildCumulativeSpendChart(context, now, monthlyExpenses, currency);
          if (constraints.maxWidth >= 620) {
            return Row(
              children: [
                Expanded(child: summary),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: chart),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [summary, const SizedBox(height: 16), chart],
          );
        },
      ),
    );
  }

  Widget _buildCumulativeSpendChart(
    BuildContext context,
    DateTime now,
    List<Expense> expenses,
    NumberFormat currency,
  ) {
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final spendByDay = List<double>.filled(lastDay + 1, 0);
    var lastRecordedDay = now.day;
    for (final expense in expenses) {
      final day = expense.dateTime.day;
      spendByDay[day] += expense.amount;
      lastRecordedDay = math.max(lastRecordedDay, day);
    }

    var runningTotal = 0.0;
    final spots = <FlSpot>[];
    for (var day = 1; day <= lastRecordedDay; day++) {
      runningTotal += spendByDay[day];
      spots.add(FlSpot(day.toDouble(), runningTotal));
    }
    final low = spots.fold(0.0, (lowest, spot) => math.min(lowest, spot.y));
    final high = spots.fold(0.0, (highest, spot) => math.max(highest, spot.y));
    final targetInterval = math.max(1.0, (high - low) / 2);
    final power = math.pow(10, (math.log(targetInterval) / math.ln10).floor()).toDouble();
    final interval = [power, power * 2, power * 5, power * 10]
        .firstWhere((tick) => tick >= targetInterval);
    final axisCurrency = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');
    final dateFormat = DateFormat('d MMM');
    const axisStyle = TextStyle(color: AppColors.primaryLight, fontSize: 10);
    final scaledAxisWidth = MediaQuery.textScalerOf(context).scale(10) * 5.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cumulative spending',
          style: TextStyle(color: AppColors.onPrimary, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        const Text(
          'Running total of expenses by date',
          style: TextStyle(color: AppColors.primaryLight, fontSize: 11),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 116 + MediaQuery.textScalerOf(context).scale(14),
          child: LineChart(
            LineChartData(
              minX: 1,
              maxX: lastDay.toDouble(),
              minY: (low / interval).floor() * interval,
              maxY: math.max(interval, (high / interval).ceil() * interval),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: Color(0x40FFFFFF),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: scaledAxisWidth,
                    interval: interval,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 6,
                      child: Text(axisCurrency.format(value), style: axisStyle),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: MediaQuery.textScalerOf(context).scale(14) + 8,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final day = value.toInt();
                      if (day != 1 && day != 15 && day != lastDay) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 6,
                        fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
                        child: Text(
                          dateFormat.format(DateTime(now.year, now.month, day)),
                          style: axisStyle,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => AppColors.primaryDeep,
                  getTooltipItems: (touched) => [
                    for (final spot in touched)
                      LineTooltipItem(
                        '${dateFormat.format(DateTime(now.year, now.month, spot.x.toInt()))}\n'
                        '${currency.format(spot.y)} total',
                        const TextStyle(color: AppColors.onPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isStepLineChart: true,
                  lineChartStepData: const LineChartStepData(
                    stepDirection: LineChartStepData.stepDirectionForward,
                  ),
                  color: AppColors.accentMint,
                  barWidth: 2.5,
                  dotData: FlDotData(checkToShowDot: (spot, _) => spot == spots.last),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.accentMint.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
            _buildSectionHeader(context, Icons.pie_chart, 'Where you spend', 'chart'),
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

  Widget _buildSectionHeader(
    BuildContext context,
    IconData icon,
    String title,
    String analyticsMode,
  ) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => _openAnalytics(context, analyticsMode),
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
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 15, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFirstTransactionCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/illustrations/first-transaction.webp',
            width: 136,
            height: 136,
            excludeFromSemantics: true,
          ),
          const SizedBox(height: 8),
          Text(
            'No transactions yet',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Start with something simple, like a coffee, a bill, or your salary.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => AddExpenseSheet.showForNewEntry(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add your first transaction'),
          ),
        ],
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
            _buildSectionHeader(context, Icons.swap_horiz_rounded, 'Recent transactions', 'list'),
          const SizedBox(height: 14),

          for (int i = 0; i < recentItems.length; i++) ...[
            if (i > 0)
              const Divider(height: 16, thickness: 0.7, color: Color(0xFFF1F5F9)),
            _buildTransactionRow(context, recentItems[i]),
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
