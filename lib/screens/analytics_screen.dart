import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedTimeframe = 'Daily';
  late DateTime _currentMonth;
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _selectedDay = now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // 1. Top Executive Metric Snapshot
            _buildVelocityMetricCard(context, provider),
            const SizedBox(height: 16),

            // 2. Multi-Timeframe Expense Analytics Bar Chart
            _buildExpenseRhythmCard(context, provider),
            const SizedBox(height: 20),

            // 3. Interactive Expense Calendar
            _buildInteractiveCalendar(context, provider),
            const SizedBox(height: 20),

            // 4. Monthly Calendar Spend Summary & Category Breakdown Card
            _buildSpendSummaryCard(context, provider),
            const SizedBox(height: 20),

            // 5. Recent Outflows of Selected Date Card
            _buildSelectedDayTransactions(context, provider),
          ],
        );
      },
    );
  }

  // --- 1. Top Executive Metric Snapshot ---
  Widget _buildVelocityMetricCard(BuildContext context, ExpenseProvider provider) {
    final double outflow = provider.totalExpenses;
    final double ceiling = outflow > 10000 ? outflow * 1.25 : 10000.00;

    final outflowInt = outflow.truncate();
    final outflowDec = (outflow % 1 * 100).toInt().toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x0D000000), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06131B2E),
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
              const Text(
                'NET OUTFLOW VELOCITY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: Color(0xFF3D4A42),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF85F8C4).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      outflow > 0 ? Icons.trending_up : Icons.check_circle_outline,
                      size: 14,
                      color: const Color(0xFF005137),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      outflow > 0 ? '${provider.expenses.length} Txns' : 'Balanced',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF005137),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₹${outflowInt.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF131B2E),
                      letterSpacing: -0.8,
                    ),
                  ),
                  Text(
                    '.$outflowDec',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3D4A42),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'INR',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6D7A72)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Forecast Ceiling',
                    style: TextStyle(fontSize: 11, color: Color(0xFF3D4A42)),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '₹${ceiling.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF006948)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 2. Multi-Timeframe Expense Analytics Bar Chart ---
  Widget _buildExpenseRhythmCard(BuildContext context, ExpenseProvider provider) {
    final weeklySpends = provider.getWeeklySpendByDay();
    double maxWeeklySpend = 0.0;
    int peakDayIdx = 0;
    double totalWeekly = 0.0;

    for (int i = 0; i < weeklySpends.length; i++) {
      totalWeekly += weeklySpends[i];
      if (weeklySpends[i] > maxWeeklySpend) {
        maxWeeklySpend = weeklySpends[i];
        peakDayIdx = i;
      }
    }

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final peakDayName = dayNames[peakDayIdx];
    final double avgDaily = totalWeekly / 7;
    final double chartMaxY = maxWeeklySpend > 100 ? maxWeeklySpend * 1.25 : 100.0;

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
                children: const [
                  Text(
                    'Expense Rhythm',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF131B2E),
                    ),
                  ),
                  Text(
                    'Real-time expenditure frequency comparison',
                    style: TextStyle(fontSize: 11, color: Color(0xFF3D4A42)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Timeframe Switcher
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: ['Daily', 'Weekly', 'Monthly', 'Yearly'].map((tf) {
                final isSelected = _selectedTimeframe == tf;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTimeframe = tf),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSelected
                          ? const [
                              BoxShadow(
                                color: Color(0x10000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      tf,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? const Color(0xFF006948) : const Color(0xFF3D4A42),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Quick Stat Badges
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 4, backgroundColor: Color(0xFF4B41E1)),
                    const SizedBox(width: 6),
                    const Text(
                      'Peak Outflow: ',
                      style: TextStyle(fontSize: 10, color: Color(0xFF3D4A42)),
                    ),
                    Text(
                      maxWeeklySpend > 0
                          ? '₹${maxWeeklySpend.toStringAsFixed(2)} ($peakDayName)'
                          : '₹0.00',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 4, backgroundColor: Color(0xFF006948)),
                    const SizedBox(width: 6),
                    const Text(
                      'Avg: ',
                      style: TextStyle(fontSize: 10, color: Color(0xFF3D4A42)),
                    ),
                    Text(
                      '₹${avgDaily.toStringAsFixed(2)} / day',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bar Chart with guidelines
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: chartMaxY,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: chartMaxY / 2 > 0 ? chartMaxY / 2 : 50,
                      getTitlesWidget: (val, meta) {
                        return Text(
                          '₹${val.toInt()}',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF3D4A42)),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= dayNames.length) return const SizedBox();
                        final isPeak = idx == peakDayIdx && maxWeeklySpend > 0;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            dayNames[idx],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600,
                              color: isPeak ? const Color(0xFF4B41E1) : const Color(0xFF3D4A42),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: Color(0xFFF2F3FF),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  final isPeak = i == peakDayIdx && maxWeeklySpend > 0;
                  return _makeBarGroup(i, weeklySpends[i], isPeak);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, bool isPeak, {bool isDim = false}) {
    Color startColor = const Color(0xFF00855D);
    Color endColor = const Color(0xFF68DBA9);

    if (isPeak) {
      startColor = const Color(0xFF4B41E1);
      endColor = const Color(0xFF645EFB);
    } else if (isDim || y == 0) {
      startColor = const Color(0xFFDAE2FD);
      endColor = const Color(0xFFE2E7FF);
    }

    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          gradient: LinearGradient(
            colors: [startColor, endColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          width: 24,
          borderRadius: BorderRadius.circular(6),
        ),
      ],
    );
  }

  // --- 3. Interactive Expense Calendar ---
  Widget _buildInteractiveCalendar(BuildContext context, ExpenseProvider provider) {
    final monthStr = DateFormat('MMMM yyyy').format(_currentMonth);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = _currentMonth.weekday; // 1 = Mon, 7 = Sun
    final leadingSpaces = firstWeekday - 1;

    final dailyTotals = provider.getDailyTotalsForMonth(_currentMonth.year, _currentMonth.month);
    final daySelectedSpend = dailyTotals[_selectedDay] ?? 0.0;

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
          // Month Header & Heatmap Legend
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                        _selectedDay = 1;
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F3FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_left, size: 18, color: Color(0xFF3D4A42)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    monthStr,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF131B2E),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                        _selectedDay = 1;
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F3FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF3D4A42)),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF006948), shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('<₹500', style: TextStyle(fontSize: 10, color: Color(0xFF3D4A42))),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF4B41E1), shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('>₹2000', style: TextStyle(fontSize: 10, color: Color(0xFF3D4A42))),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Day of Week Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) {
                final isWeekend = d == 'S';
                return SizedBox(
                  width: 36,
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isWeekend ? const Color(0xFF4B41E1) : const Color(0xFF3D4A42),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // 7-Column Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 0.85,
            ),
            itemCount: leadingSpaces + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leadingSpaces) {
                return const SizedBox();
              }

              final dayNumber = index - leadingSpaces + 1;
              final daySpend = dailyTotals[dayNumber];
              return _buildDayCell(dayNumber, daySpend);
            },
          ),
          const SizedBox(height: 12),
          // Active Selection Detail Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_available, size: 18, color: Color(0xFF006948)),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('MMM').format(_currentMonth)} $_selectedDay, ${_currentMonth.year}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Day Total: ', style: TextStyle(fontSize: 12, color: Color(0xFF3D4A42))),
                    Text(
                      '₹${daySelectedSpend.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF006948),
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

  Widget _buildDayCell(int day, double? spend) {
    final isSelected = _selectedDay == day;
    final hasSpend = spend != null && spend > 0;
    final isHigh = hasSpend && spend > 2000;

    String badgeText = hasSpend ? '₹${spend.toInt()}' : 'Rest';

    Color cellBg = const Color(0xFFF2F3FF);
    Color textColor = const Color(0xFF131B2E);
    Color badgeBg = const Color(0xFFEAEDFF);
    Color badgeColor = const Color(0xFF131B2E);

    if (isSelected) {
      cellBg = const Color(0xFF006948);
      textColor = Colors.white;
      badgeBg = Colors.white;
      badgeColor = const Color(0xFF006948);
    } else if (isHigh) {
      cellBg = const Color(0xFF645EFB).withValues(alpha: 0.15);
      textColor = const Color(0xFF4B41E1);
      badgeBg = const Color(0xFF4B41E1);
      badgeColor = Colors.white;
    } else if (hasSpend) {
      cellBg = const Color(0xFF85F8C4).withValues(alpha: 0.3);
      textColor = const Color(0xFF005137);
      badgeBg = const Color(0xFF85F8C4);
      badgeColor = const Color(0xFF002114);
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedDay = day),
      child: Container(
        decoration: BoxDecoration(
          color: cellBg,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: const Color(0xFF006948), width: 1.5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Palette for dynamic category breakdown
  static const List<Color> _palette = [
    Color(0xFF00855D),
    Color(0xFF4B41E1),
    Color(0xFF008096),
    Color(0xFF645EFB),
    Color(0xFFF43F5E),
    Color(0xFFF59E0B),
  ];

  // --- 4. Monthly Calendar Spend Summary & Category Breakdown Card ---
  Widget _buildSpendSummaryCard(BuildContext context, ExpenseProvider provider) {
    final double totalOutflow = provider.getTotalExpensesForMonth(_currentMonth.year, _currentMonth.month);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final dailyTotals = provider.getDailyTotalsForMonth(_currentMonth.year, _currentMonth.month);
    
    final int spendDaysCount = dailyTotals.length;
    final int restDaysCount = daysInMonth - spendDaysCount;
    final double dailyAvg = spendDaysCount > 0 ? (totalOutflow / spendDaysCount) : 0.0;
    
    double highestDay = 0.0;
    dailyTotals.forEach((_, val) {
      if (val > highestDay) highestDay = val;
    });

    final categoryMap = provider.getCategoryTotalsForMonth(_currentMonth.year, _currentMonth.month);
    final List<PieChartSectionData> sections = [];
    if (categoryMap.isEmpty || totalOutflow == 0) {
      sections.add(
        PieChartSectionData(color: const Color(0xFFEAEDFF), value: 100, title: '', radius: 14),
      );
    } else {
      int idx = 0;
      categoryMap.forEach((cat, val) {
        sections.add(
          PieChartSectionData(
            color: _palette[idx % _palette.length],
            value: val,
            title: '',
            radius: 14,
          ),
        );
        idx++;
      });
    }

    final monthTitle = _currentMonth.year == DateTime.now().year
        ? '${DateFormat('MMMM').format(_currentMonth)} Spend Summary'
        : '${DateFormat('MMMM yyyy').format(_currentMonth)} Spend Summary';

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF131B2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Comprehensive portfolio outflow analysis',
                      style: TextStyle(fontSize: 11, color: Color(0xFF3D4A42)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF85F8C4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$spendDaysCount Spend Days',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF002114)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 3-Column Key Summary Counters
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Daily Avg', style: TextStyle(fontSize: 10, color: Color(0xFF3D4A42))),
                      const SizedBox(height: 2),
                      Text('₹${dailyAvg.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF131B2E))),
                      const Text('Active pacing', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF006948))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Highest Day', style: TextStyle(fontSize: 10, color: Color(0xFF3D4A42))),
                      const SizedBox(height: 2),
                      Text('₹${highestDay.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF4B41E1))),
                      const Text('Peak outflow', style: TextStyle(fontSize: 9, color: Color(0xFF3D4A42))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rest Days', style: TextStyle(fontSize: 10, color: Color(0xFF3D4A42))),
                      const SizedBox(height: 2),
                      Text('$restDaysCount Days', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF008096))),
                      const Text('₹0 outflow', style: TextStyle(fontSize: 9, color: Color(0xFF008096))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Donut Distribution & Progress Rows
          Row(
            children: [
              // Donut Chart
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        startDegreeOffset: -90,
                        sections: sections,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('TOTAL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF3D4A42))),
                        Text(
                          '₹${totalOutflow.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF131B2E)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Proportional Progress Rows
              Expanded(
                child: categoryMap.isEmpty
                    ? const Center(
                        child: Text(
                          'No category data available yet.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF6D7A72)),
                        ),
                      )
                    : Column(
                        children: categoryMap.entries.take(3).map((entry) {
                          final idx = categoryMap.keys.toList().indexOf(entry.key);
                          final color = _palette[idx % _palette.length];
                          final pct = totalOutflow > 0 ? (entry.value / totalOutflow) : 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildProgressRow(
                              entry.key,
                              '₹${entry.value.toStringAsFixed(2)}',
                              '(${(pct * 100).toStringAsFixed(1)}%)',
                              color,
                              pct,
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
          if (categoryMap.length > 3) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: categoryMap.entries.skip(3).map((e) {
                final pct = totalOutflow > 0 ? ((e.value / totalOutflow) * 100).toStringAsFixed(1) : '0';
                return _TagPill('${e.key} ₹${e.value.toStringAsFixed(0)} ($pct%)');
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, String amount, String pct, Color color, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF131B2E))),
              ],
            ),
            Text(
              '$amount $pct',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: const Color(0xFFF2F3FF),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  // --- 5. Recent Outflows of Selected Date Card ---
  Widget _buildSelectedDayTransactions(BuildContext context, ExpenseProvider provider) {
    final selectedDate = DateTime(_currentMonth.year, _currentMonth.month, _selectedDay);
    final dayExpenses = provider.getExpensesForDate(selectedDate);
    final dayStr = DateFormat('MMM dd').format(selectedDate);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x0D000000), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06131B2E),
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
              Text(
                'Transactions for $dayStr',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF131B2E),
                ),
              ),
              Text(
                '${dayExpenses.length} Outflows',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF006948)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (dayExpenses.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text(
                  'No transactions recorded on this date.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72)),
                ),
              ),
            )
          else
            ...dayExpenses.map((expense) {
              final timeStr = DateFormat('hh:mm a').format(expense.dateTime);
              final title = expense.comment != null && expense.comment!.isNotEmpty
                  ? expense.comment!
                  : expense.category;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3FF).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF006948).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getCategoryIcon(expense.category), color: const Color(0xFF006948), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                          ),
                          Text(
                            '$timeStr • ${expense.category} (${expense.paymentMethod})',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF6D7A72)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '-₹${expense.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
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
}

class _TagPill extends StatelessWidget {
  final String text;

  const _TagPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, color: Color(0xFF3D4A42), fontWeight: FontWeight.w500),
      ),
    );
  }
}
