import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/search_filter.dart';
import '../providers/expense_provider.dart';
import '../widgets/add_expense_sheet.dart';

class SearchScreen extends StatefulWidget {
  final String? initialCategory;

  const SearchScreen({super.key, this.initialCategory});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late SearchFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = SearchFilter.initial();
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      _filter = _filter.copyWith(categories: {widget.initialCategory!});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() {
      _filter = _filter.copyWith(query: query);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _filter = _filter.copyWith(query: '');
    });
  }

  void _setDatePreset(DateRangePreset preset) async {
    if (preset == DateRangePreset.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(now.year + 2),
        initialDateRange: _filter.customStartDate != null && _filter.customEndDate != null
            ? DateTimeRange(start: _filter.customStartDate!, end: _filter.customEndDate!)
            : DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF006948),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Color(0xFF131B2E),
              ),
            ),
            child: child!,
          );
        },
      );

      if (picked != null) {
        setState(() {
          _filter = _filter.copyWith(
            datePreset: DateRangePreset.custom,
            customStartDate: picked.start,
            customEndDate: picked.end,
          );
        });
      }
    } else {
      setState(() {
        _filter = _filter.copyWith(
          datePreset: preset,
          clearCustomDates: true,
        );
      });
    }
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FilterBottomSheet(
        initialFilter: _filter,
        onApply: (updated) {
          setState(() {
            _filter = updated;
          });
        },
      ),
    );
  }

  void _openEditSheet(BuildContext context, Expense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddExpenseSheet(expenseToEdit: expense),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final results = provider.searchExpenses(_filter);
    final totalAmount = results.fold(0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchHeader(context),
            _buildDatePresetBar(),
            if (_filter.hasActiveFilters) _buildActiveFiltersBar(),
            _buildSummaryRow(results.length, totalAmount),
            Expanded(
              child: results.isEmpty
                  ? _buildEmptyState()
                  : _buildResultsList(context, results, provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    final activeCount = _filter.activeFilterCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0x0D000000), width: 1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF131B2E)),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
          ),
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _searchFocusNode.hasFocus ? const Color(0xFF006948) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14, color: Color(0xFF131B2E), fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Search remarks, categories, payment...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8C9BA2)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF006948), size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: Color(0xFF6D7A72)),
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: _filter.hasActiveFilters
                    ? const Color(0xFF006948).withValues(alpha: 0.12)
                    : const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _openFilterSheet,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 46,
                    width: 46,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: _filter.hasActiveFilters ? const Color(0xFF006948) : const Color(0xFF3D4A42),
                    ),
                  ),
                ),
              ),
              if (activeCount > 0)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF006948),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      '$activeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDatePresetBar() {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 8, bottom: 2),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: DateRangePreset.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final preset = DateRangePreset.values[index];
          final isSelected = _filter.datePreset == preset;

          String label = preset.label;
          if (preset == DateRangePreset.custom &&
              _filter.customStartDate != null &&
              _filter.customEndDate != null) {
            final f = DateFormat('d MMM');
            label = '${f.format(_filter.customStartDate!)} - ${f.format(_filter.customEndDate!)}';
          }

          return ActionChip(
            label: Text(label),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF3D4A42),
            ),
            backgroundColor: isSelected ? const Color(0xFF006948) : Colors.white,
            side: BorderSide(
              color: isSelected ? const Color(0xFF006948) : const Color(0x1F000000),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            onPressed: () => _setDatePreset(preset),
          );
        },
      ),
    );
  }

  Widget _buildActiveFiltersBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Clear all chip
            ActionChip(
              avatar: const Icon(Icons.close, size: 14, color: Color(0xFFBA1A1A)),
              label: const Text('Clear Filters'),
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFBA1A1A)),
              backgroundColor: const Color(0xFFFFEBEE),
              side: const BorderSide(color: Color(0xFFFFCDD2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _filter = SearchFilter.initial();
                });
              },
            ),
            const SizedBox(width: 6),

            // Active category chips
            for (var cat in _filter.categories) ...[
              InputChip(
                label: Text(cat),
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF006948)),
                backgroundColor: const Color(0xFF006948).withValues(alpha: 0.1),
                side: BorderSide.none,
                deleteIconColor: const Color(0xFF006948),
                onDeleted: () {
                  final newCats = Set<String>.from(_filter.categories)..remove(cat);
                  setState(() {
                    _filter = _filter.copyWith(categories: newCats);
                  });
                },
              ),
              const SizedBox(width: 6),
            ],

            // Active payment methods
            for (var pm in _filter.paymentMethods) ...[
              InputChip(
                label: Text(pm),
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4B41E1)),
                backgroundColor: const Color(0xFF4B41E1).withValues(alpha: 0.1),
                side: BorderSide.none,
                deleteIconColor: const Color(0xFF4B41E1),
                onDeleted: () {
                  final newPms = Set<String>.from(_filter.paymentMethods)..remove(pm);
                  setState(() {
                    _filter = _filter.copyWith(paymentMethods: newPms);
                  });
                },
              ),
              const SizedBox(width: 6),
            ],

            // Amount chip
            if (_filter.minAmount != null || _filter.maxAmount != null) ...[
              InputChip(
                label: Text(
                  '₹${_filter.minAmount?.toStringAsFixed(0) ?? '0'} - ₹${_filter.maxAmount?.toStringAsFixed(0) ?? '∞'}',
                ),
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF008096)),
                backgroundColor: const Color(0xFF008096).withValues(alpha: 0.1),
                side: BorderSide.none,
                deleteIconColor: const Color(0xFF008096),
                onDeleted: () {
                  setState(() {
                    _filter = _filter.copyWith(clearMinAmount: true, clearMaxAmount: true);
                  });
                },
              ),
              const SizedBox(width: 6),
            ],

            // Sort chip
            if (_filter.sortBy != ExpenseSortOption.dateDesc) ...[
              InputChip(
                label: Text(_filter.sortBy.label),
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3D4A42)),
                backgroundColor: const Color(0xFFF2F4F7),
                side: BorderSide.none,
                deleteIconColor: const Color(0xFF3D4A42),
                onDeleted: () {
                  setState(() {
                    _filter = _filter.copyWith(sortBy: ExpenseSortOption.dateDesc);
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(int count, double total) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                '$count ${count == 1 ? 'result' : 'results'} found',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF131B2E),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFFBCCAC0),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Total: ₹${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF006948),
                ),
              ),
            ],
          ),
          PopupMenuButton<ExpenseSortOption>(
            initialValue: _filter.sortBy,
            tooltip: 'Sort Options',
            onSelected: (sort) {
              setState(() {
                _filter = _filter.copyWith(sortBy: sort);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x14000000)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sort_rounded, size: 14, color: Color(0xFF006948)),
                  const SizedBox(width: 4),
                  Text(
                    _getShortSortLabel(_filter.sortBy),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => ExpenseSortOption.values.map((opt) {
              return PopupMenuItem<ExpenseSortOption>(
                value: opt,
                child: Row(
                  children: [
                    if (_filter.sortBy == opt)
                      const Icon(Icons.check, size: 16, color: Color(0xFF006948))
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text(opt.label, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getShortSortLabel(ExpenseSortOption sort) {
    switch (sort) {
      case ExpenseSortOption.dateDesc:
        return 'Date ↓';
      case ExpenseSortOption.dateAsc:
        return 'Date ↑';
      case ExpenseSortOption.amountDesc:
        return 'Amount ↓';
      case ExpenseSortOption.amountAsc:
        return 'Amount ↑';
    }
  }

  Widget _buildResultsList(BuildContext context, List<Expense> results, ExpenseProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final expense = results[index];
        final dateStr = DateFormat('EEE, d MMM yyyy • hh:mm a').format(expense.dateTime);

        return Dismissible(
          key: Key('search_${expense.id}'),
          background: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFBA1A1A),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Delete',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.delete_outline, color: Colors.white, size: 24),
              ],
            ),
          ),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('Delete Expense', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF131B2E))),
                content: const Text('Are you sure you want to delete this recorded transaction?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF6D7A72))),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Delete', style: TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) {
            provider.deleteExpense(expense.id!);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Transaction removed from ledger'),
                backgroundColor: const Color(0xFF006948),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
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
                onTap: () => _openEditSheet(context, expense),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF006948).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long, color: Color(0xFF006948), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  expense.category,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF131B2E),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF006948)),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              dateStr,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF6D7A72)),
                            ),
                            if (expense.comment != null && expense.comment!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                expense.comment!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF3D4A42)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '-₹${expense.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF131B2E),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F3FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              expense.paymentMethod,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3D4A42),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF006948).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, size: 40, color: Color(0xFF006948)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Transactions Match',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try changing your search keyword or clearing some filters.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6D7A72)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _filter = SearchFilter.initial();
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset All Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006948),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBottomSheet extends StatefulWidget {
  final SearchFilter initialFilter;
  final ValueChanged<SearchFilter> onApply;

  const _FilterBottomSheet({
    required this.initialFilter,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late Set<String> _selectedCategories;
  late Set<String> _selectedPaymentMethods;
  late ExpenseSortOption _selectedSort;
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCategories = Set.from(widget.initialFilter.categories);
    _selectedPaymentMethods = Set.from(widget.initialFilter.paymentMethods);
    _selectedSort = widget.initialFilter.sortBy;

    if (widget.initialFilter.minAmount != null) {
      _minAmountController.text = widget.initialFilter.minAmount!.toStringAsFixed(0);
    }
    if (widget.initialFilter.maxAmount != null) {
      _maxAmountController.text = widget.initialFilter.maxAmount!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _selectedCategories.clear();
      _selectedPaymentMethods.clear();
      _selectedSort = ExpenseSortOption.dateDesc;
      _minAmountController.clear();
      _maxAmountController.clear();
    });
  }

  void _apply() {
    final minAmount = double.tryParse(_minAmountController.text.trim());
    final maxAmount = double.tryParse(_maxAmountController.text.trim());

    final updated = widget.initialFilter.copyWith(
      categories: _selectedCategories,
      paymentMethods: _selectedPaymentMethods,
      minAmount: minAmount,
      maxAmount: maxAmount,
      sortBy: _selectedSort,
      clearMinAmount: minAmount == null,
      clearMaxAmount: maxAmount == null,
    );

    widget.onApply(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final categories = provider.categories;
    final paymentMethods = provider.paymentMethods;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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

          // Title & Reset button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter Transactions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
              ),
              TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh, size: 16, color: Color(0xFFBA1A1A)),
                label: const Text('Reset', style: TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categories section
                  const Text(
                    'Categories',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = _selectedCategories.contains(cat);
                      return FilterChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: const Color(0xFF006948).withValues(alpha: 0.15),
                        checkmarkColor: const Color(0xFF006948),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? const Color(0xFF006948) : const Color(0xFF3D4A42),
                        ),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF006948) : const Color(0x1F000000),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedCategories.add(cat);
                            } else {
                              _selectedCategories.remove(cat);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Payment methods section
                  const Text(
                    'Payment Methods',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: paymentMethods.map((pm) {
                      final isSelected = _selectedPaymentMethods.contains(pm);
                      return FilterChip(
                        label: Text(pm),
                        selected: isSelected,
                        selectedColor: const Color(0xFF4B41E1).withValues(alpha: 0.15),
                        checkmarkColor: const Color(0xFF4B41E1),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? const Color(0xFF4B41E1) : const Color(0xFF3D4A42),
                        ),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF4B41E1) : const Color(0x1F000000),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedPaymentMethods.add(pm);
                            } else {
                              _selectedPaymentMethods.remove(pm);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Amount Range section
                  const Text(
                    'Amount Range (₹)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minAmountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Min ₹',
                            labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF6D7A72)),
                            prefixText: '₹ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('to', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6D7A72))),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _maxAmountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Max ₹',
                            labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF6D7A72)),
                            prefixText: '₹ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Sort section
                  const Text(
                    'Sort Order',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ExpenseSortOption.values.map((sort) {
                      final isSelected = _selectedSort == sort;
                      return ChoiceChip(
                        label: Text(sort.label),
                        selected: isSelected,
                        selectedColor: const Color(0xFF006948).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? const Color(0xFF006948) : const Color(0xFF3D4A42),
                        ),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF006948) : const Color(0x1F000000),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedSort = sort;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          // Apply Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006948),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
