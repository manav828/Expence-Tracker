import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../widgets/add_expense_sheet.dart';
import '../utils/category_icons.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // --- View Mode: 'list' (Ledger), 'calendar' (Calendar Grid), or 'chart' (Breakdown) ---
  String _viewMode = 'list';

  // --- Date Range State ---
  String _activePreset = 'This Month';
  late DateTimeRange _dateRange;

  // Specific Day Filter (if user picks a single date via picker)
  DateTime? _selectedSpecificDate;

  // Selected Day within Calendar View
  int? _selectedCalendarDay;

  // --- Filter & Search State ---
  String _searchQuery = '';
  String? _selectedCategoryFilter;
  String? _selectedPaymentFilter;

  final TextEditingController _searchController = TextEditingController();

  static const List<Color> _palette = [
    Color(0xFF006948),
    Color(0xFF4B41E1),
    Color(0xFF008096),
    Color(0xFF645EFB),
    Color(0xFFF43F5E),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  static Color _getCategoryColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('food') || lower.contains('restaurant') || lower.contains('dining')) {
      return const Color(0xFFF59E0B);
    } else if (lower.contains('transport') || lower.contains('fuel') || lower.contains('cab')) {
      return const Color(0xFF008096);
    } else if (lower.contains('shop') || lower.contains('cloth')) {
      return const Color(0xFFEC4899);
    } else if (lower.contains('bill') || lower.contains('utilit') || lower.contains('recharge')) {
      return const Color(0xFF4B41E1);
    } else if (lower.contains('entertain') || lower.contains('stream') || lower.contains('movie')) {
      return const Color(0xFF8B5CF6);
    } else if (lower.contains('health') || lower.contains('fitness') || lower.contains('gym')) {
      return const Color(0xFF10B981);
    } else if (lower.contains('grocer')) {
      return const Color(0xFF006948);
    }
    final hash = category.codeUnits.fold(0, (sum, c) => sum + c);
    return _palette[hash % _palette.length];
  }

  @override
  void initState() {
    super.initState();
    _setDateRangePreset('This Month', notify: false);
    _selectedCalendarDay = DateTime.now().day;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setDateRangePreset(String preset, {bool notify = true}) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (preset) {
      case 'This Month':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        break;
      case 'Last Month':
        start = DateTime(now.year, now.month - 1, 1);
        end = DateTime(now.year, now.month, 0, 23, 59, 59, 999);
        break;
      case 'Last 30 Days':
        start = DateTime(now.year, now.month, now.day - 30);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case 'This Year':
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        break;
      default:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    }

    final newDay = (start.year == now.year && start.month == now.month) ? now.day : 1;

    if (notify) {
      setState(() {
        _activePreset = preset;
        _dateRange = DateTimeRange(start: start, end: end);
        _selectedSpecificDate = null;
        _selectedCalendarDay = newDay;
      });
    } else {
      _activePreset = preset;
      _dateRange = DateTimeRange(start: start, end: end);
      _selectedSpecificDate = null;
      _selectedCalendarDay = newDay;
    }
  }

  void _shiftMonth(int offset) {
    setState(() {
      final currentStart = _dateRange.start;
      final newMonth = DateTime(currentStart.year, currentStart.month + offset, 1);
      final newEnd = DateTime(newMonth.year, newMonth.month + 1, 0, 23, 59, 59, 999);
      _dateRange = DateTimeRange(start: newMonth, end: newEnd);
      _activePreset = DateFormat('MMMM yyyy').format(newMonth);
      _selectedSpecificDate = null;

      final now = DateTime.now();
      if (newMonth.year == now.year && newMonth.month == now.month) {
        _selectedCalendarDay = now.day;
      } else {
        _selectedCalendarDay = 1;
      }
    });
  }

  Future<void> _pickCustomDateOrRange(BuildContext context) async {
    final now = DateTime.now();

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Filter Expenses by Date',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Color(0xFF006948)),
                title: const Text('Pick a Specific Day', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('View transactions from an exact single date'),
                onTap: () => Navigator.pop(ctx, 'single'),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month, color: Color(0xFF4B41E1)),
                title: const Text('Pick a Custom Date Range', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Choose starting and ending dates'),
                onTap: () => Navigator.pop(ctx, 'range'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == 'single' && context.mounted) {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: _selectedSpecificDate ?? now,
        firstDate: DateTime(2020),
        lastDate: DateTime(now.year + 5),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF006948),
                onPrimary: Colors.white,
                onSurface: Color(0xFF131B2E),
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedDate != null && mounted) {
        setState(() {
          _selectedSpecificDate = pickedDate;
          _selectedCalendarDay = pickedDate.day;
          _dateRange = DateTimeRange(
            start: DateTime(pickedDate.year, pickedDate.month, 1),
            end: DateTime(pickedDate.year, pickedDate.month + 1, 0, 23, 59, 59, 999),
          );
          _activePreset = 'Custom Day';
        });
      }
    } else if (choice == 'range' && context.mounted) {
      final pickedRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(now.year + 5),
        initialDateRange: _dateRange,
        helpText: 'SELECT EXPENSE DATE RANGE',
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF006948),
                onPrimary: Colors.white,
                onSurface: Color(0xFF131B2E),
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedRange != null && mounted) {
        setState(() {
          _dateRange = DateTimeRange(
            start: pickedRange.start,
            end: DateTime(pickedRange.end.year, pickedRange.end.month, pickedRange.end.day, 23, 59, 59, 999),
          );
          _activePreset = 'Custom Range';
          _selectedSpecificDate = null;
        });
      }
    }
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _selectedCategoryFilter = null;
      _selectedPaymentFilter = null;
      _selectedSpecificDate = null;
      _searchController.clear();
      _setDateRangePreset('This Month');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        // 1. Filter expenses by date range
        final rangeExpenses = provider.expenses.where((e) {
          final d = e.dateTime;
          return d.isAfter(_dateRange.start.subtract(const Duration(milliseconds: 1))) &&
              d.isBefore(_dateRange.end.add(const Duration(milliseconds: 1)));
        }).toList();

        // 2. Further filtered transactions for ledger
        final ledgerExpenses = rangeExpenses.where((e) {
          if (_selectedSpecificDate != null) {
            final sd = _selectedSpecificDate!;
            if (e.dateTime.year != sd.year || e.dateTime.month != sd.month || e.dateTime.day != sd.day) {
              return false;
            }
          }
          if (_selectedCategoryFilter != null && e.category != _selectedCategoryFilter) {
            return false;
          }
          if (_selectedPaymentFilter != null && e.paymentMethod != _selectedPaymentFilter) {
            return false;
          }
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            final matchesNote = e.comment?.toLowerCase().contains(query) ?? false;
            final matchesCat = e.category.toLowerCase().contains(query);
            final matchesAmt = e.amount.toString().contains(query);
            if (!matchesNote && !matchesCat && !matchesAmt) return false;
          }
          return true;
        }).toList();

        final totalSpent = rangeExpenses.fold(0.0, (sum, e) => sum + e.amount);
        final filteredSpent = ledgerExpenses.fold(0.0, (sum, e) => sum + e.amount);
        final daySpan = (_dateRange.end.difference(_dateRange.start).inDays + 1).clamp(1, 10000);
        final dailyAvg = totalSpent / daySpan;

        // Group spend by category
        final Map<String, double> categorySpendMap = {};
        for (var e in rangeExpenses) {
          categorySpendMap[e.category] = (categorySpendMap[e.category] ?? 0.0) + e.amount;
        }

        final hasActiveFilters = _selectedCategoryFilter != null ||
            _selectedPaymentFilter != null ||
            _selectedSpecificDate != null ||
            _searchQuery.isNotEmpty;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FD),
          body: Column(
            children: [
              // 1. Sleek Sticky Header (Date range, month shifter, presets)
              _buildHeaderControls(context),

              // 2. Main Scrollable Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  children: [
                    // Summary Banner Card with 3-Way Mode Switcher
                    _buildSummaryCard(
                      totalSpent,
                      filteredSpent,
                      rangeExpenses.length,
                      ledgerExpenses.length,
                      dailyAvg,
                      hasActiveFilters,
                    ),
                    const SizedBox(height: 12),

                    if (_viewMode == 'list') ...[
                      // Category Filter Chips (Instant in-place filter!)
                      _buildCategoryChipsRow(categorySpendMap, rangeExpenses.length),
                      const SizedBox(height: 12),

                      // Search & Quick Payment Method Filters Bar
                      _buildSearchAndFilterBar(),
                      const SizedBox(height: 10),

                      // Active Filters Indicator (if any)
                      if (hasActiveFilters) _buildActiveFilterBanner(),

                      // Grouped Transactions Ledger (Clean Column, Zero Ghost Whitespace!)
                      _buildTransactionsLedger(ledgerExpenses, provider),
                    ] else if (_viewMode == 'calendar') ...[
                      // Interactive Calendar Grid & Day Outflow View
                      _buildCalendarView(rangeExpenses, provider),
                    ] else ...[
                      // Breakdown View (Category Donut & Ranked List)
                      _buildCategoryBreakdownSection(categorySpendMap, totalSpent, rangeExpenses),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 1. Sleek Sticky Header ---
  Widget _buildHeaderControls(BuildContext context) {
    final isSingleMonth = _dateRange.start.year == _dateRange.end.year &&
        _dateRange.start.month == _dateRange.end.month &&
        _dateRange.start.day == 1 &&
        _dateRange.end.day >= 28;

    final monthTitle = isSingleMonth
        ? DateFormat('MMMM yyyy').format(_dateRange.start)
        : '${DateFormat('d MMM').format(_dateRange.start)} – ${DateFormat('d MMM yyyy').format(_dateRange.end)}';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Month Shifter & Title (Base-Safe standard Icons.chevron_left & right!)
              Row(
                children: [
                  IconButton(
                    onPressed: () => _shiftMonth(-1),
                    icon: const Icon(Icons.chevron_left, size: 24, color: Color(0xFF131B2E)),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Previous Month',
                  ),
                  Text(
                    monthTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF131B2E),
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _shiftMonth(1),
                    icon: const Icon(Icons.chevron_right, size: 24, color: Color(0xFF131B2E)),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Next Month',
                  ),
                ],
              ),
              // Date Picker Icon Button (Base-safe Icons.calendar_today)
              InkWell(
                onTap: () => _pickCustomDateOrRange(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF006948).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF006948).withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF006948)),
                      const SizedBox(width: 5),
                      Text(
                        _selectedSpecificDate != null
                            ? DateFormat('d MMM').format(_selectedSpecificDate!)
                            : 'Select Date',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF006948),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Horizontal Preset Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                'This Month',
                'Last Month',
                'Last 30 Days',
                'This Year',
              ].map((preset) {
                final isSelected = _activePreset == preset && _selectedSpecificDate == null;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => _setDateRangePreset(preset),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF006948) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        preset,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. Summary Card with Full-Width Non-Wrapping Amount & 3-Way Switcher ---
  Widget _buildSummaryCard(
    double totalSpent,
    double filteredSpent,
    int totalCount,
    int filteredCount,
    double dailyAvg,
    bool hasActiveFilters,
  ) {
    final isShowingFiltered = hasActiveFilters && (filteredSpent != totalSpent || filteredCount != totalCount);
    final displayAmount = isShowingFiltered ? filteredSpent : totalSpent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle / Filter Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isShowingFiltered ? 'FILTERED EXPENSES' : 'TOTAL EXPENSES',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF006948).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isShowingFiltered
                      ? '$filteredCount of $totalCount items'
                      : '$totalCount transactions',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF006948),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Hero Amount (Full Width, Never Wraps, FittedBox with Non-breaking space)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '₹\u00A0${NumberFormat('#,##,##0.00', 'en_IN').format(displayAmount)}',
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF131B2E),
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Daily average / date context
          Text(
            isShowingFiltered
                ? 'Filtered by active criteria'
                : 'Avg. ${NumberFormat.currency(locale: 'en_IN', symbol: '₹\u00A0', decimalDigits: 0).format(dailyAvg)}/day',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),

          // 3-Way Segmented Control: Ledger | Calendar | Breakdown
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(child: _buildViewTab('list', Icons.receipt_long, 'Ledger')),
                const SizedBox(width: 4),
                Expanded(child: _buildViewTab('calendar', Icons.calendar_month, 'Calendar')),
                const SizedBox(width: 4),
                Expanded(child: _buildViewTab('chart', Icons.pie_chart, 'Breakdown')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewTab(String mode, IconData icon, String label) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? const Color(0xFF006948) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF006948) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. Interactive Category Filter Chips ---
  Widget _buildCategoryChipsRow(Map<String, double> categorySpendMap, int totalCount) {
    final currencyFmt = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');
    final sortedCategories = categorySpendMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // "All" chip
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('All ($totalCount)'),
                  selected: _selectedCategoryFilter == null,
                  onSelected: (_) => setState(() => _selectedCategoryFilter = null),
                  selectedColor: const Color(0xFF006948),
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _selectedCategoryFilter == null ? FontWeight.bold : FontWeight.w600,
                    color: _selectedCategoryFilter == null ? Colors.white : const Color(0xFF334155),
                  ),
                  side: BorderSide(
                    color: _selectedCategoryFilter == null ? const Color(0xFF006948) : const Color(0xFFE2E8F0),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  showCheckmark: false,
                ),
              ),
              // Category chips
              ...sortedCategories.map((entry) {
                final isSelected = _selectedCategoryFilter == entry.key;
                final catIcon = CategoryIcons.get(entry.key);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(
                      catIcon,
                      size: 14,
                      color: isSelected ? Colors.white : _getCategoryColor(entry.key),
                    ),
                    label: Text('${entry.key} · ${currencyFmt.format(entry.value)}'),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategoryFilter = selected ? entry.key : null;
                      });
                    },
                    selectedColor: const Color(0xFF006948),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF006948) : const Color(0xFFE2E8F0),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    showCheckmark: false,
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // --- 4. Search & Payment Method Filter Bar ---
  Widget _buildSearchAndFilterBar() {
    return Row(
      children: [
        // Search Input Field (Base-Safe Icons.search & Icons.clear)
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(fontSize: 13, color: Color(0xFF131B2E), fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Search notes, merchant, amount...',
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Payment Method Dropdown (Base-Safe icons)
        PopupMenuButton<String?>(
          initialValue: _selectedPaymentFilter,
          onSelected: (val) => setState(() => _selectedPaymentFilter = val),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          itemBuilder: (ctx) => [
            const PopupMenuItem<String?>(
              value: null,
              child: Text('All Payment Methods', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const PopupMenuDivider(),
            ...['UPI', 'Card', 'Cash', 'NetBanking'].map(
              (m) => PopupMenuItem<String?>(
                value: m,
                child: Row(
                  children: [
                    Icon(
                      m == 'UPI'
                          ? Icons.qr_code_2
                          : (m == 'Card' ? Icons.credit_card : Icons.payments),
                      size: 16,
                      color: const Color(0xFF006948),
                    ),
                    const SizedBox(width: 8),
                    Text(m),
                  ],
                ),
              ),
            ),
          ],
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _selectedPaymentFilter != null ? const Color(0xFF006948).withValues(alpha: 0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedPaymentFilter != null ? const Color(0xFF006948) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: _selectedPaymentFilter != null ? const Color(0xFF006948) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  _selectedPaymentFilter ?? 'Payment',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _selectedPaymentFilter != null ? const Color(0xFF006948) : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Active Filters Banner ---
  Widget _buildActiveFilterBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF006948).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF006948).withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF006948)),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (_selectedCategoryFilter != null)
                  _buildTagBadge('Category: $_selectedCategoryFilter', () => setState(() => _selectedCategoryFilter = null)),
                if (_selectedPaymentFilter != null)
                  _buildTagBadge('Method: $_selectedPaymentFilter', () => setState(() => _selectedPaymentFilter = null)),
                if (_selectedSpecificDate != null)
                  _buildTagBadge('Date: ${DateFormat('d MMM').format(_selectedSpecificDate!)}', () => setState(() => _selectedSpecificDate = null)),
                if (_searchQuery.isNotEmpty)
                  _buildTagBadge('Search: "$_searchQuery"', () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  }),
              ],
            ),
          ),
          InkWell(
            onTap: _clearAllFilters,
            child: const Text(
              'Reset All',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC5221F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagBadge(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF006948).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF006948))),
          const SizedBox(width: 3),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 12, color: Color(0xFF006948)),
          ),
        ],
      ),
    );
  }

  // --- 5. Grouped Transactions Ledger (Clean Column, Zero Extra Whitespace) ---
  Widget _buildTransactionsLedger(List<Expense> expenses, ExpenseProvider provider) {
    if (expenses.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        alignment: Alignment.center,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long, size: 36, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            const Text(
              'No expenses found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try adjusting your search, filters, or selected date',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _clearAllFilters,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF006948),
                side: const BorderSide(color: Color(0xFF006948)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Clear All Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    // Sort descending by date
    final sorted = List<Expense>.from(expenses)..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

    // Group by Day (YYYY-MM-DD)
    final Map<String, List<Expense>> grouped = {};
    for (var e in sorted) {
      final key = DateFormat('yyyy-MM-dd').format(e.dateTime);
      grouped.putIfAbsent(key, () => []).add(e);
    }

    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹\u00A0', decimalDigits: 2);
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayKey = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

    return Column(
      children: grouped.entries.map((entry) {
        final dayExpenses = entry.value;
        final dayDate = dayExpenses.first.dateTime;
        final dayTotal = dayExpenses.fold(0.0, (s, e) => s + e.amount);

        String dayTitle;
        if (entry.key == todayKey) {
          dayTitle = 'Today, ${DateFormat('d MMM').format(dayDate)}';
        } else if (entry.key == yesterdayKey) {
          dayTitle = 'Yesterday, ${DateFormat('d MMM').format(dayDate)}';
        } else {
          dayTitle = DateFormat('EEEE, d MMMM').format(dayDate);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x040F172A), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Day Section Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dayTitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                    Text(
                      currencyFmt.format(dayTotal),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                  ],
                ),
              ),
              // Day Items - Clean direct items (zero nested ListView padding!)
              Column(
                children: [
                  for (int idx = 0; idx < dayExpenses.length; idx++) ...[
                    if (idx > 0)
                      const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
                    _buildTransactionRowItem(dayExpenses[idx], provider, currencyFmt),
                  ],
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTransactionRowItem(Expense expense, ExpenseProvider provider, NumberFormat currencyFmt) {
    final icon = CategoryIcons.get(expense.category);
    final color = _getCategoryColor(expense.category);

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AddExpenseSheet(expenseToEdit: expense),
        );
      },
      onLongPress: () => _confirmDeleteExpense(context, expense, provider),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    expense.comment?.isNotEmpty == true ? expense.comment! : expense.category,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF131B2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (expense.comment?.isNotEmpty == true) ...[
                        Text(
                          expense.category,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                        const Text(' · ', style: TextStyle(color: Color(0xFFCBD5E1))),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          expense.paymentMethod,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '- ${currencyFmt.format(expense.amount)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF131B2E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 6. Interactive Calendar View (Exact Beloved Original UI) ---
  Widget _buildCalendarView(List<Expense> monthExpenses, ExpenseProvider provider) {
    final monthStart = _dateRange.start;
    final year = monthStart.year;
    final month = monthStart.month;
    final monthStr = DateFormat('MMMM yyyy').format(monthStart);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1 = Mon, 7 = Sun
    final leadingSpaces = firstWeekday - 1;

    final dailyTotals = provider.getDailyTotalsForMonth(year, month);

    final activeDay = (_selectedCalendarDay ?? DateTime.now().day).clamp(1, daysInMonth);
    final daySelectedSpend = dailyTotals[activeDay] ?? 0.0;

    return Column(
      children: [
        // 1. Calendar Card
        Container(
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
                        onTap: () => _shiftMonth(-1),
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
                        onTap: () => _shiftMonth(1),
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
                          const Text('<₹2000', style: TextStyle(fontSize: 10, color: Color(0xFF3D4A42))),
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
                padding: EdgeInsets.zero,
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
                  return _buildOriginalDayCell(dayNumber, daySpend, activeDay);
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
                          '${DateFormat('MMM').format(monthStart)} $activeDay, ${monthStart.year}',
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
        ),
        const SizedBox(height: 16),

        // 2. Outflows of Selected Date Card
        _buildSelectedDayOutflows(context, provider, year, month, activeDay),
      ],
    );
  }

  Widget _buildOriginalDayCell(int day, double? spend, int selectedDay) {
    final isSelected = selectedDay == day;
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
      onTap: () => setState(() => _selectedCalendarDay = day),
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

  Widget _buildSelectedDayOutflows(
    BuildContext context,
    ExpenseProvider provider,
    int year,
    int month,
    int day,
  ) {
    final selectedDate = DateTime(year, month, day);
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
                '${dayExpenses.length} Outflow${dayExpenses.length == 1 ? '' : 's'}',
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
              child: Column(
                children: [
                  const Text(
                    'No transactions recorded on this date.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72)),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const AddExpenseSheet(),
                      );
                    },
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add Expense'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006948),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            )
          else
            ...dayExpenses.map((expense) {
              final timeStr = DateFormat('hh:mm a').format(expense.dateTime);
              final title = expense.comment != null && expense.comment!.isNotEmpty
                  ? expense.comment!
                  : expense.category;

              return InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => AddExpenseSheet(expenseToEdit: expense),
                  );
                },
                onLongPress: () => _confirmDeleteExpense(context, expense, provider),
                borderRadius: BorderRadius.circular(14),
                child: Container(
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
                        child: Icon(CategoryIcons.get(expense.category), color: const Color(0xFF006948), size: 18),
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
                ),
              );
            }),
        ],
      ),
    );
  }

  void _confirmDeleteExpense(BuildContext context, Expense expense, ExpenseProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Delete "${expense.category} - ₹${expense.amount}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteExpense(expense.id!);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Expense deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFBA1A1A))),
          ),
        ],
      ),
    );
  }

  // --- 7. Breakdown View (Category Donut & Ranked List) ---
  Widget _buildCategoryBreakdownSection(
    Map<String, double> categorySpendMap,
    double totalSpent,
    List<Expense> rangeExpenses,
  ) {
    if (categorySpendMap.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: const Text('No expense data available for this range', style: TextStyle(color: Color(0xFF64748B))),
      );
    }

    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹\u00A0', decimalDigits: 2);
    final sortedCategories = categorySpendMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Prepare pie chart sections
    final List<PieChartSectionData> pieSections = [];
    for (int i = 0; i < sortedCategories.length; i++) {
      final entry = sortedCategories[i];
      final color = _palette[i % _palette.length];
      final pct = totalSpent > 0 ? (entry.value / totalSpent) * 100 : 0.0;

      pieSections.add(
        PieChartSectionData(
          color: color,
          value: entry.value,
          title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
          radius: 36,
          titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    }

    return Column(
      children: [
        // Donut Chart Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 190,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: pieSections,
                        sectionsSpace: 2,
                        centerSpaceRadius: 58,
                        startDegreeOffset: -90,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${sortedCategories.length}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF131B2E)),
                        ),
                        const Text(
                          'Categories',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tap any category below to immediately view its filtered transactions in Ledger',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Ranked Category List
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Spending by Category',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
                ),
              ),
              ...sortedCategories.map((entry) {
                final pct = totalSpent > 0 ? (entry.value / totalSpent) : 0.0;
                final catColor = _getCategoryColor(entry.key);
                final catIcon = CategoryIcons.get(entry.key);
                final txCount = rangeExpenses.where((e) => e.category == entry.key).length;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCategoryFilter = entry.key;
                      _viewMode = 'list';
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(catIcon, size: 18, color: catColor),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                                  ),
                                  Text(
                                    '$txCount transaction${txCount == 1 ? '' : 's'}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  currencyFmt.format(entry.value),
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                                ),
                                Text(
                                  '${(pct * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF006948)),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCBD5E1)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: AlwaysStoppedAnimation<Color>(catColor),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
