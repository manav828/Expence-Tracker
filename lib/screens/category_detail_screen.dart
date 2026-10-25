import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/searchable_selection_sheet.dart';
import '../utils/category_icons.dart';

enum TimeFramePreset { week, month, threeMonths, sixMonths, nineMonths, year, custom }

class CategoryDetailScreen extends StatefulWidget {
  final String initialCategory;

  const CategoryDetailScreen({super.key, required this.initialCategory});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _ChartDataPoint {
  final String label;
  final String tooltipTitle;
  final double amount;

  _ChartDataPoint({
    required this.label,
    required this.tooltipTitle,
    required this.amount,
  });
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  late String _selectedCategory;
  TimeFramePreset _preset = TimeFramePreset.month;
  late DateTimeRange _dateRange;
  bool _isLineChart = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
  }

  void _onPresetChanged(TimeFramePreset preset) {
    if (preset == TimeFramePreset.custom) {
      _openCalendarPicker();
      return;
    }

    final now = DateTime.now();
    DateTimeRange newRange;
    switch (preset) {
      case TimeFramePreset.week:
        final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final sunday = monday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        newRange = DateTimeRange(start: monday, end: sunday);
        break;
      case TimeFramePreset.month:
        newRange = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
        break;
      case TimeFramePreset.threeMonths:
        newRange = DateTimeRange(
          start: DateTime(now.year, now.month - 2, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
        break;
      case TimeFramePreset.sixMonths:
        newRange = DateTimeRange(
          start: DateTime(now.year, now.month - 5, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
        break;
      case TimeFramePreset.nineMonths:
        newRange = DateTimeRange(
          start: DateTime(now.year, now.month - 8, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
        break;
      case TimeFramePreset.year:
        newRange = DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31, 23, 59, 59),
        );
        break;
      case TimeFramePreset.custom:
        return;
    }

    setState(() {
      _preset = preset;
      _dateRange = newRange;
    });
  }

  Future<void> _openCalendarPicker() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select Date Range',
      cancelText: 'Cancel',
      confirmText: 'Apply',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF006948),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF131B2E),
              secondary: Color(0xFF85F8C4),
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateRange = DateTimeRange(
          start: DateTime(picked.start.year, picked.start.month, picked.start.day),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
        );
        _preset = TimeFramePreset.custom;
      });
    }
  }

  String _dateRangeLabel() {
    switch (_preset) {
      case TimeFramePreset.week:
        return 'This Week';
      case TimeFramePreset.month:
        return DateFormat('MMMM yyyy').format(_dateRange.start);
      case TimeFramePreset.threeMonths:
      case TimeFramePreset.sixMonths:
      case TimeFramePreset.nineMonths:
        return '${DateFormat('MMM').format(_dateRange.start)} – ${DateFormat('MMM yyyy').format(_dateRange.end)}';
      case TimeFramePreset.year:
        return DateFormat('yyyy').format(_dateRange.start);
      case TimeFramePreset.custom:
        return '${DateFormat('dd MMM').format(_dateRange.start)} – ${DateFormat('dd MMM yyyy').format(_dateRange.end)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final filteredExpenses = provider.getExpensesForCategory(
      _selectedCategory,
      _dateRange.start,
      _dateRange.end,
    );
    final totalSpent = filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF006948).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF006948)),
          ),
        ),
        title: const Text(
          'Category Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF131B2E),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Searchable Category Selector
            _buildCategorySelector(provider),
            const SizedBox(height: 16),

            // 2. Summary Hero Card
            _buildSummaryCard(totalSpent, filteredExpenses.length),
            const SizedBox(height: 16),

            // 3. Calendar Type Filter (Dropdown on left + Date Range on right)
            _buildCalendarFilterCard(),
            const SizedBox(height: 16),

            // 4. Spending Trend Chart (Bar & Line switchable)
            _buildChartCard(filteredExpenses),
            const SizedBox(height: 20),

            // 5. Expense Entries List
            _buildExpenseList(filteredExpenses),
          ],
        ),
      ),
    );
  }

  // --- 1. Searchable Category Selector Card ---
  Widget _buildCategorySelector(ExpenseProvider provider) {
    final categories = provider.categories;
    final effectiveCategory = categories.contains(_selectedCategory)
        ? _selectedCategory
        : (categories.firstOrNull ?? _selectedCategory);
    final iconData = CategoryIcons.get(effectiveCategory);

    return InkWell(
      onTap: () async {
        final selected = await SearchableSelectionSheet.show(
          context,
          title: 'Select Category',
          items: categories,
          selectedItem: effectiveCategory,
          isCategory: true,
        );
        if (selected != null && mounted) {
          setState(() => _selectedCategory = selected);
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x0D000000)),
          boxShadow: const [
            BoxShadow(color: Color(0x08131B2E), blurRadius: 14, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF006948).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(iconData, size: 22, color: const Color(0xFF006948)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6D7A72),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    effectiveCategory,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF131B2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.search, size: 14, color: Color(0xFF006948)),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF006948)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. Summary Hero Card ---
  Widget _buildSummaryCard(double totalSpent, int count) {
    final iconData = CategoryIcons.get(_selectedCategory);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF006948), Color(0xFF00855D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x33006948), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(iconData, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedCategory,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${totalSpent.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count entries',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _dateRangeLabel(),
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 3. Calendar Type Filter Card ---
  // Left: small dropdown (week, month, 3month, 6month, 9month, year)
  // Right: displays From - To range, clickable to open calendar date range modal
  Widget _buildCalendarFilterCard() {
    final startStr = DateFormat('dd MMM yyyy').format(_dateRange.start);
    final endStr = DateFormat('dd MMM yyyy').format(_dateRange.end);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x0D000000)),
        boxShadow: const [
          BoxShadow(color: Color(0x08131B2E), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Left side: small dropdown with presets
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF006948).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF006948).withValues(alpha: 0.2)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TimeFramePreset>(
                value: _preset,
                isDense: true,
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF006948), size: 22),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF006948),
                ),
                items: const [
                  DropdownMenuItem(value: TimeFramePreset.week, child: Text('Week')),
                  DropdownMenuItem(value: TimeFramePreset.month, child: Text('Month')),
                  DropdownMenuItem(value: TimeFramePreset.threeMonths, child: Text('3 Month')),
                  DropdownMenuItem(value: TimeFramePreset.sixMonths, child: Text('6 Month')),
                  DropdownMenuItem(value: TimeFramePreset.nineMonths, child: Text('9 Month')),
                  DropdownMenuItem(value: TimeFramePreset.year, child: Text('Year')),
                  DropdownMenuItem(value: TimeFramePreset.custom, child: Text('Custom')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    _onPresetChanged(val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Divider
          Container(
            height: 36,
            width: 1,
            color: const Color(0x1F006948),
          ),
          const SizedBox(width: 12),
          // Right side: showing range From - To, clickable to open calendar modal
          Expanded(
            child: InkWell(
              onTap: _openCalendarPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF006948).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF006948)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'From: ',
                                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6D7A72), fontSize: 10),
                              ),
                              Text(
                                startStr,
                                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF131B2E), fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Text(
                                'To:     ',
                                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6D7A72), fontSize: 10),
                              ),
                              Text(
                                endStr,
                                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF131B2E), fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_calendar_outlined, size: 16, color: Color(0xFF006948)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. Spending Trend Chart Card ---
  Widget _buildChartCard(List<Expense> filteredExpenses) {
    final points = _getChartData(filteredExpenses);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x0D000000)),
        boxShadow: const [
          BoxShadow(color: Color(0x08131B2E), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isLineChart ? Icons.show_chart : Icons.bar_chart,
                size: 18,
                color: const Color(0xFF006948),
              ),
              const SizedBox(width: 8),
              const Text(
                'Spending Trend',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF131B2E),
                ),
              ),
              const Spacer(),
              // Toggle Bar / Line
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isLineChart = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: !_isLineChart ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: !_isLineChart
                              ? const [BoxShadow(color: Color(0x14000000), blurRadius: 4)]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.bar_chart,
                              size: 14,
                              color: !_isLineChart ? const Color(0xFF006948) : const Color(0xFF6D7A72),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Bar',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: !_isLineChart ? FontWeight.w700 : FontWeight.w500,
                                color: !_isLineChart ? const Color(0xFF006948) : const Color(0xFF6D7A72),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _isLineChart = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isLineChart ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _isLineChart
                              ? const [BoxShadow(color: Color(0x14000000), blurRadius: 4)]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.show_chart,
                              size: 14,
                              color: _isLineChart ? const Color(0xFF006948) : const Color(0xFF6D7A72),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Line',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: _isLineChart ? FontWeight.w700 : FontWeight.w500,
                                color: _isLineChart ? const Color(0xFF006948) : const Color(0xFF6D7A72),
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
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: _isLineChart ? _buildLineChart(points) : _buildBarChart(points),
          ),
        ],
      ),
    );
  }

  // --- Compute chart data points based on date range ---
  List<_ChartDataPoint> _getChartData(List<Expense> expenses) {
    final daysCount = _dateRange.end.difference(_dateRange.start).inDays + 1;

    if (_preset == TimeFramePreset.week || daysCount <= 7) {
      // 1 point per day with Weekday name or Day number
      const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final points = <_ChartDataPoint>[];
      for (int i = 0; i < daysCount; i++) {
        final d = _dateRange.start.add(Duration(days: i));
        double total = 0.0;
        for (var e in expenses) {
          if (e.dateTime.year == d.year && e.dateTime.month == d.month && e.dateTime.day == d.day) {
            total += e.amount;
          }
        }
        final weekdayLabel = dayNames[(d.weekday - 1) % 7];
        points.add(_ChartDataPoint(
          label: daysCount == 7 ? weekdayLabel : DateFormat('dd').format(d),
          tooltipTitle: DateFormat('EEE, dd MMM').format(d),
          amount: total,
        ));
      }
      return points;
    } else if (_preset == TimeFramePreset.month || daysCount <= 35) {
      // 1 point per day with Day numbers (1..daysCount)
      final points = <_ChartDataPoint>[];
      for (int i = 0; i < daysCount; i++) {
        final d = _dateRange.start.add(Duration(days: i));
        double total = 0.0;
        for (var e in expenses) {
          if (e.dateTime.year == d.year && e.dateTime.month == d.month && e.dateTime.day == d.day) {
            total += e.amount;
          }
        }
        points.add(_ChartDataPoint(
          label: '${d.day}',
          tooltipTitle: DateFormat('dd MMMM yyyy').format(d),
          amount: total,
        ));
      }
      return points;
    } else {
      // Multi-month range (3Mo, 6Mo, 9Mo, Year, or custom > 35 days)
      final startMonth = DateTime(_dateRange.start.year, _dateRange.start.month, 1);
      final endMonth = DateTime(_dateRange.end.year, _dateRange.end.month, 1);
      final months = <DateTime>[];
      var curr = startMonth;
      while (!curr.isAfter(endMonth)) {
        months.add(curr);
        curr = DateTime(curr.year, curr.month + 1, 1);
      }

      final points = <_ChartDataPoint>[];
      for (var m in months) {
        double total = 0.0;
        for (var e in expenses) {
          if (e.dateTime.year == m.year && e.dateTime.month == m.month) {
            total += e.amount;
          }
        }
        points.add(_ChartDataPoint(
          label: months.length > 8 ? DateFormat('MMM').format(m).substring(0, 1) : DateFormat('MMM').format(m),
          tooltipTitle: DateFormat('MMMM yyyy').format(m),
          amount: total,
        ));
      }
      return points;
    }
  }

  // --- Dynamic Bar Chart ---
  Widget _buildBarChart(List<_ChartDataPoint> points) {
    if (points.isEmpty) return const SizedBox.shrink();
    final maxVal = points.map((p) => p.amount).reduce((a, b) => a > b ? a : b);
    final maxY = maxVal == 0 ? 100.0 : (maxVal * 1.3);

    final bool isDense = points.length > 14;
    final labelIndices = <int>{};
    if (isDense) {
      labelIndices.add(0);
      final step = points.length > 25 ? 5 : 3;
      for (int i = step; i < points.length; i += step) {
        labelIndices.add(i);
      }
      labelIndices.add(points.length - 1);
    }

    final double barWidth = points.length <= 7
        ? 24.0
        : points.length <= 14
            ? 14.0
            : points.length <= 31
                ? 6.0
                : 8.0;

    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final p = points[group.x];
              return BarTooltipItem(
                '${p.tooltipTitle}\n₹${rod.toY.toStringAsFixed(0)}',
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) return const SizedBox.shrink();
                return Text(
                  '₹${value.toInt()}',
                  style: const TextStyle(fontSize: 9, color: Color(0xFF6D7A72)),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                if (isDense && !labelIndices.contains(idx)) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    points[idx].label,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF3D4A42)),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0x0F000000),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(points.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: points[i].amount,
                color: const Color(0xFF006948),
                width: barWidth,
                borderRadius: BorderRadius.vertical(top: Radius.circular(barWidth > 10 ? 6 : 3)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: const Color(0xFFF2F4F7),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // --- Dynamic Line Chart ---
  Widget _buildLineChart(List<_ChartDataPoint> points) {
    if (points.isEmpty) return const SizedBox.shrink();
    final maxVal = points.map((p) => p.amount).reduce((a, b) => a > b ? a : b);
    final maxY = maxVal == 0 ? 100.0 : (maxVal * 1.3);

    final bool isDense = points.length > 14;
    final labelIndices = <int>{};
    if (isDense) {
      labelIndices.add(0);
      final step = points.length > 25 ? 5 : 3;
      for (int i = step; i < points.length; i += step) {
        labelIndices.add(i);
      }
      labelIndices.add(points.length - 1);
    }

    return LineChart(
      LineChartData(
        maxY: maxY,
        minY: 0,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final idx = spot.x.toInt();
                if (idx < 0 || idx >= points.length) return null;
                final p = points[idx];
                return LineTooltipItem(
                  '${p.tooltipTitle}\n₹${spot.y.toStringAsFixed(0)}',
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) return const SizedBox.shrink();
                return Text(
                  '₹${value.toInt()}',
                  style: const TextStyle(fontSize: 9, color: Color(0xFF6D7A72)),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                if (isDense && !labelIndices.contains(idx)) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    points[idx].label,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF3D4A42)),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0x0F000000),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(points.length, (i) => FlSpot(i.toDouble(), points[i].amount)),
            isCurved: true,
            curveSmoothness: 0.25,
            color: const Color(0xFF006948),
            barWidth: 3,
            isStrokeCapRound: true,
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF006948).withValues(alpha: 0.12),
            ),
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) {
                if (!isDense) return true;
                return labelIndices.contains(spot.x.toInt()) && spot.y > 0;
              },
              getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                radius: 4,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: const Color(0xFF006948),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. Expense Entries List ---
  Widget _buildExpenseList(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x0D000000)),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long, size: 44, color: const Color(0xFF6D7A72).withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text(
              'No expenses found',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF3D4A42)),
            ),
            const SizedBox(height: 4),
            Text(
              'No entries for $_selectedCategory in this period',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6D7A72)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.receipt_long, size: 16, color: Color(0xFF006948)),
              const SizedBox(width: 6),
              Text(
                'All Entries (${expenses.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF131B2E),
                ),
              ),
            ],
          ),
        ),
        ...expenses.map((e) => _buildExpenseTile(e)),
      ],
    );
  }

  Widget _buildExpenseTile(Expense expense) {
    final iconData = CategoryIcons.get(expense.category);
    final dateStr = DateFormat('dd MMM, hh:mm a').format(expense.dateTime);

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AddExpenseSheet(expenseToEdit: expense),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x0D000000)),
          boxShadow: const [
            BoxShadow(color: Color(0x06131B2E), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF006948).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, size: 18, color: const Color(0xFF006948)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.comment ?? expense.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF131B2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${expense.paymentMethod} · $dateStr',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF6D7A72)),
                  ),
                ],
              ),
            ),
            Text(
              '₹${expense.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFFBA1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
