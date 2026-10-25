import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/expense_provider.dart';
import '../widgets/add_expense_sheet.dart';
import '../providers/budget_provider.dart';
import 'budget_screen.dart';
import 'category_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isSafeguardsDismissed = false;

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
          textColor: const Color(0xFF85F8C4),
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
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // 1. Executive Header & Greeting Pill
            _buildGreetingRow(context),
            const SizedBox(height: 16),

            // 2. Monthly Category Budget Snapshot Card
            _buildBudgetSnapshotCard(context, provider),

            // 3. Category Expense Allocation Donut Card
            _buildCategoryDonutCard(context, provider),
            const SizedBox(height: 20),

            // 4. Cumulative Day-by-Day Escalation Trajectory Spline
            _buildTrajectoryCard(context, provider),
            const SizedBox(height: 20),

            // 5. Recent Verified Ledger
            _buildVerifiedLedgerSection(context, provider),
          ],
        );
      },
    );
  }

  // --- 1. Executive Header & Greeting Pill ---
  Widget _buildGreetingRow(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final dateRangeStr = '${DateFormat('MMM 1').format(firstDay)} – ${DateFormat('MMM d').format(lastDay)}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF006948),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'APEX PRIVATE LEDGER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: Color(0xFF3D4A42),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Good evening, Alex',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF131B2E),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
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
                        color: const Color(0xFF006948).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF006948), size: 18),
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
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF006948)),
                            ),
                            Icon(Icons.chevron_right, size: 16, color: Color(0xFF006948)),
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
                                    : const Color(0xFF006948),
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

  // Palette for dynamic category donut slices
  static const List<Color> _palette = [
    Color(0xFF6366F1),
    Color(0xFF10B981),
    Color(0xFF06B6D4),
    Color(0xFFF43F5E),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFF008096),
    Color(0xFF645EFB),
  ];

  // --- 4. Category Allocation Donut Card ---
  Widget _buildCategoryDonutCard(BuildContext context, ExpenseProvider provider) {
    final double totalOutflow = provider.totalExpenses;
    final categoryMap = provider.categoryTotals;
    final now = DateTime.now();
    final monthStr = DateFormat('MMM yyyy').format(now);

    final List<PieChartSectionData> sections = [];
    final List<Map<String, dynamic>> legendItems = [];

    if (categoryMap.isEmpty || totalOutflow == 0) {
      // Clean placeholder ring
      sections.add(
        PieChartSectionData(
          color: const Color(0xFFEAEDFF),
          value: 100,
          title: '',
          radius: 20,
        ),
      );
    } else {
      int idx = 0;
      categoryMap.forEach((category, amount) {
        final color = _palette[idx % _palette.length];
        final pct = (amount / totalOutflow) * 100;
        sections.add(
          PieChartSectionData(
            color: color,
            value: amount,
            title: '',
            radius: 22,
          ),
        );
        legendItems.add({
          'category': category,
          'amount': '₹${amount.toStringAsFixed(2)}',
          'pct': '${pct.toStringAsFixed(1)}%',
          'color': color,
        });
        idx++;
      });
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x0D000000), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08131B2E),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pie_chart, size: 18, color: Color(0xFF006948)),
                      const SizedBox(width: 6),
                      const Text(
                        'Category Allocation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF131B2E),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Breakdown of current monthly outflow',
                    style: TextStyle(fontSize: 11, color: Color(0xFF3D4A42)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEDFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${categoryMap.length} Segments',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3D4A42),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Donut Chart with Center Core
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 65,
                    startDegreeOffset: -90,
                    sections: sections,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'TOTAL OUTFLOW',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: Color(0xFF3D4A42),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${totalOutflow.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAEDFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        monthStr,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF3D4A42)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Micro Legend Pills Grid
          if (legendItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'No expenses recorded yet. Tap + to add an expense.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6D7A72)),
                ),
              ),
            )
          else
            GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.8,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: legendItems.length,
              itemBuilder: (context, i) {
                final item = legendItems[i];
                final categoryName = item['category'] as String;
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CategoryDetailScreen(initialCategory: categoryName),
                      ),
                    );
                  },
                  child: _buildLegendTile(
                    categoryName,
                    item['amount'] as String,
                    item['pct'] as String,
                    item['color'] as Color,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLegendTile(String title, String amount, String pct, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF131B2E)),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                amount,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
              ),
              Text(
                pct,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF3D4A42)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 5. Cumulative Day-by-Day Escalation Trajectory Spline ---
  Widget _buildTrajectoryCard(BuildContext context, ExpenseProvider provider) {
    final double totalOutflow = provider.totalExpenses;
    final now = DateTime.now();
    final todayLabel = DateFormat('MMM d').format(now);
    final inrFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');
    final inrFmtDecimal = NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN');

    // Build timeline points grouped by calendar day based on current month
    final List<_TrajectoryDataPoint> points = [];
    final monthlyExpenses = provider.getExpensesForMonth(now.year, now.month);
    final validExpenses = monthlyExpenses.where((e) => e.amount > 0).toList();

    if (validExpenses.isNotEmpty) {
      validExpenses.sort((a, b) => a.expenseDate.compareTo(b.expenseDate));

      // Group spending by calendar day
      final Map<DateTime, double> dailySpendMap = {};
      for (final exp in validExpenses) {
        final dt = exp.dateTime;
        final dayKey = DateTime(dt.year, dt.month, dt.day);
        dailySpendMap[dayKey] = (dailySpendMap[dayKey] ?? 0.0) + exp.amount;
      }

      final sortedDays = dailySpendMap.keys.toList()..sort();
      final firstDay = sortedDays.first;
      final lastDay = sortedDays.last;
      final totalCalendarDays = lastDay.difference(firstDay).inDays + 1;

      double runningTotal = 0.0;

      if (sortedDays.length == 1 || totalCalendarDays <= 1) {
        // Single day: start from 0 at start of day, step to total
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
      } else if (totalCalendarDays <= 60) {
        // Up to 2 months: continuous day-by-day progression
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
      } else {
        // For larger timeframes (> 60 days): sample ~40 points across the range
        const int maxSamplePoints = 40;
        final double stepDays = (totalCalendarDays - 1) / (maxSamplePoints - 1);
        final Set<DateTime> sampledDates = {};
        for (int i = 0; i < maxSamplePoints; i++) {
          final dayOffset = (i * stepDays).round();
          sampledDates.add(firstDay.add(Duration(days: dayOffset)));
        }
        sampledDates.add(lastDay);

        final sampledList = sampledDates.toList()..sort();
        for (final sampleDate in sampledList) {
          double sumUntil = 0.0;
          for (final entry in dailySpendMap.entries) {
            if (!entry.key.isAfter(sampleDate)) {
              sumUntil += entry.value;
            }
          }
          points.add(_TrajectoryDataPoint(
            date: sampleDate,
            cumulativeAmount: sumUntil,
            daySpend: dailySpendMap[sampleDate] ?? 0.0,
          ));
        }
      }
    }

    // Spots for fl_chart
    List<FlSpot> spots = [];
    if (points.isEmpty) {
      spots = const [
        FlSpot(0, 0),
        FlSpot(1, 0),
        FlSpot(2, 0),
        FlSpot(3, 0),
      ];
    } else {
      spots = List.generate(
        points.length,
        (i) => FlSpot(i.toDouble(), points[i].cumulativeAmount),
      );
    }

    // Determine target ceiling and range
    final double maxCeiling = totalOutflow > 5000 ? totalOutflow * 1.2 : 5000.0;
    final double chartMaxY = totalOutflow > 0 ? (totalOutflow * 1.15) : 5000.0;

    // Milestone indices for X-axis: Pick at most 4 evenly spaced date labels so text NEVER overlaps
    final List<int> milestoneIndices = [];
    if (points.isNotEmpty) {
      if (points.length <= 4) {
        milestoneIndices.addAll(List.generate(points.length, (i) => i));
      } else {
        const int labelCount = 4;
        for (int i = 0; i < labelCount; i++) {
          final idx = ((points.length - 1) * i / (labelCount - 1)).round();
          if (!milestoneIndices.contains(idx)) {
            milestoneIndices.add(idx);
          }
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x0D000000), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08131B2E),
            blurRadius: 16,
            offset: Offset(0, 4),
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
                  const Icon(Icons.show_chart, size: 20, color: Color(0xFF006948)),
                  const SizedBox(width: 8),
                  const Text(
                    'Spend Escalation Trajectory',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF131B2E),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF85F8C4).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  todayLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF002114),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            totalOutflow > 0
                ? 'Cumulative spend to date: ${inrFmtDecimal.format(totalOutflow)}'
                : 'No spend accrued yet this period',
            style: const TextStyle(fontSize: 11, color: Color(0xFF3D4A42)),
          ),
          const SizedBox(height: 14),
          // Interactive Glowing Milestone Card (Responsive, clean spacing)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF006948).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF006948).withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF006948),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$todayLabel Status',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                ),
                const Spacer(),
                Text(
                  'Accrued: ${inrFmt.format(totalOutflow)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF006948)),
                ),
                if (maxCeiling > totalOutflow) ...[
                  Text(
                    '  •  Target: ${inrFmt.format(maxCeiling)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6D7A72)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Spline Line Chart (Zero dots blob, zero date overlap, silky smooth)
          SizedBox(
            height: 155,
            child: points.isEmpty
                ? Center(
                    child: Text(
                      'Record transactions to view spending trajectory curve',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      maxY: chartMaxY,
                      minY: 0,
                      lineTouchData: LineTouchData(
                        handleBuiltInTouches: true,
                        touchTooltipData: LineTouchTooltipData(
                          tooltipRoundedRadius: 10,
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final idx = spot.x.toInt();
                              if (idx < 0 || idx >= points.length) return null;
                              final pt = points[idx];
                              final dateStr = DateFormat('d MMM yyyy').format(pt.date);
                              final accStr = inrFmt.format(pt.cumulativeAmount);
                              final dayStr = pt.daySpend > 0
                                  ? '\nDay Outflow: +${inrFmt.format(pt.daySpend)}'
                                  : '';
                              return LineTooltipItem(
                                '$dateStr\nCumulative: $accStr$dayStr',
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              );
                            }).toList();
                          },
                        ),
                        getTouchedSpotIndicator: (barData, spotIndexes) {
                          return spotIndexes.map((index) {
                            return TouchedSpotIndicatorData(
                              FlLine(
                                color: const Color(0xFF006948).withValues(alpha: 0.35),
                                strokeWidth: 1.5,
                                dashArray: [4, 4],
                              ),
                              FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                  radius: 5,
                                  color: const Color(0xFF006948),
                                  strokeWidth: 2.5,
                                  strokeColor: Colors.white,
                                ),
                              ),
                            );
                          }).toList();
                        },
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: const Color(0xFFBCCAC0).withValues(alpha: 0.25),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            interval: 1,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (!milestoneIndices.contains(idx) || idx < 0 || idx >= points.length) {
                                return const SizedBox.shrink();
                              }
                              final pt = points[idx];
                              final isLast = idx == points.length - 1;
                              final isToday = pt.date.year == now.year &&
                                  pt.date.month == now.month &&
                                  pt.date.day == now.day;
                              final label = (isLast && isToday)
                                  ? 'Today'
                                  : DateFormat('d MMM').format(pt.date);

                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6D7A72),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.2,
                          color: const Color(0xFF006948),
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            checkToShowDot: (spot, barData) {
                              // Only show single terminal milestone dot, no ugly blob of dots
                              if (points.length <= 4) return true;
                              return spot.x.toInt() == points.length - 1;
                            },
                            getDotPainter: (spot, percent, barData, index) {
                              final isLast = spot.x.toInt() == points.length - 1;
                              return FlDotCirclePainter(
                                radius: isLast ? 4.5 : 2.5,
                                color: const Color(0xFF006948),
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF006948).withValues(alpha: 0.22),
                                const Color(0xFF006948).withValues(alpha: 0.0),
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
          const SizedBox(height: 10),
          // Progress Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MilestoneChip('Entries: ${monthlyExpenses.length}'),
              _MilestoneChip(points.length > 1 ? '${points.length} Days' : 'Currency: INR (₹)'),
              _MilestoneChip('Total: ${inrFmt.format(totalOutflow)}', isPrimary: true),
            ],
          ),
        ],
      ),
    );
  }

  // --- 6. Recent Verified Ledger (Real User Expenses) ---
  Widget _buildVerifiedLedgerSection(BuildContext context, ExpenseProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Recent Verified Ledger',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF131B2E),
                  ),
                ),
                Text(
                  'Tap any entry to edit details or change date',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6D7A72)),
                ),
              ],
            ),
            if (provider.expenses.isNotEmpty)
              Text(
                '${provider.expenses.length} Entries',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF006948),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (provider.expenses.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x0A000000), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF2F3FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long_outlined, size: 26, color: Color(0xFF006948)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ledger is Clear',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'No transactions recorded yet.\nTap + or Guard / SMS to add your first expense.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72)),
                ),
              ],
            ),
          )
        else
          ...provider.expenses.take(6).map((expense) {
            final dateStr = DateFormat('MMM dd, hh:mm a').format(expense.dateTime);
            final title = expense.comment != null && expense.comment!.isNotEmpty
                ? expense.comment!
                : expense.category;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: _buildLedgerItem(
                icon: _getCategoryIcon(expense.category),
                color: const Color(0xFF006948),
                title: title,
                category: expense.category,
                categoryBg: const Color(0xFFE2DFFF),
                categoryColor: const Color(0xFF3323CC),
                time: '$dateStr • ${expense.paymentMethod}',
                amount: '-₹${expense.amount.toStringAsFixed(2)}',
                status: 'Cleared',
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => AddExpenseSheet(expenseToEdit: expense),
                  );
                },
              ),
            );
          }),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food & dining':
      case 'food':
        return Icons.restaurant;
      case 'tech & gear':
      case 'tech':
        return Icons.devices;
      case 'housing':
        return Icons.apartment;
      case 'entertainment':
        return Icons.local_activity;
      case 'wellness':
      case 'health':
        return Icons.spa;
      case 'transport':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'investment':
        return Icons.trending_up;
      case 'bills & utilities':
        return Icons.receipt;
      default:
        return Icons.receipt_long;
    }
  }

  Widget _buildLedgerItem({
    required IconData icon,
    required Color color,
    required String title,
    required String category,
    required Color categoryBg,
    required Color categoryColor,
    required String time,
    required String amount,
    required String status,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0A000000), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF131B2E),
                              ),
                            ),
                          ),
                          if (onTap != null) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF006948)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: categoryBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: categoryColor),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              time,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF6D7A72)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amount,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF85F8C4).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF005137)),
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

class _MilestoneChip extends StatelessWidget {
  final String label;
  final bool isPrimary;
  const _MilestoneChip(this.label, {this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: isPrimary ? const Color(0xFF006948) : const Color(0xFF6D7A72),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isPrimary ? FontWeight.w800 : FontWeight.w500,
            color: isPrimary ? const Color(0xFF006948) : const Color(0xFF3D4A42),
          ),
        ),
      ],
    );
  }
}
