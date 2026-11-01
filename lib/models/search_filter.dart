import 'expense.dart';

/// Sort options for filtering and searching expenses.
enum ExpenseSortOption {
  dateDesc('Date: Newest First'),
  dateAsc('Date: Oldest First'),
  amountDesc('Amount: Highest First'),
  amountAsc('Amount: Lowest First');

  final String label;
  const ExpenseSortOption(this.label);
}

/// Predefined date presets for fast expense filtering.
enum DateRangePreset {
  all('All Time'),
  today('Today'),
  thisWeek('This Week'),
  thisMonth('This Month'),
  last30Days('Last 30 Days'),
  custom('Custom');

  final String label;
  const DateRangePreset(this.label);
}

/// Comprehensive immutable filter state for search and analytics filtering.
class SearchFilter {
  final String query;
  final DateRangePreset datePreset;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final Set<String> categories;
  final Set<String> paymentMethods;
  final double? minAmount;
  final double? maxAmount;
  final ExpenseSortOption sortBy;
  final TransactionType? type;

  const SearchFilter({
    this.query = '',
    this.datePreset = DateRangePreset.all,
    this.customStartDate,
    this.customEndDate,
    this.categories = const {},
    this.paymentMethods = const {},
    this.minAmount,
    this.maxAmount,
    this.sortBy = ExpenseSortOption.dateDesc,
    this.type,
  });

  /// Factory constructor for empty/initial filter state.
  static SearchFilter initial() => const SearchFilter();

  /// Returns true if any non-default filter condition is active.
  bool get hasActiveFilters {
    return query.trim().isNotEmpty ||
        datePreset != DateRangePreset.all ||
        categories.isNotEmpty ||
        paymentMethods.isNotEmpty ||
        minAmount != null ||
        maxAmount != null ||
        sortBy != ExpenseSortOption.dateDesc ||
        type != null;
  }

  /// Calculates total count of active applied filter chips.
  int get activeFilterCount {
    int count = 0;
    if (query.trim().isNotEmpty) count++;
    if (datePreset != DateRangePreset.all) count++;
    if (categories.isNotEmpty) count += categories.length;
    if (paymentMethods.isNotEmpty) count += paymentMethods.length;
    if (minAmount != null || maxAmount != null) count++;
    if (sortBy != ExpenseSortOption.dateDesc) count++;
    if (type != null) count++;
    return count;
  }

  /// Returns a new [SearchFilter] with specified field updates.
  SearchFilter copyWith({
    String? query,
    DateRangePreset? datePreset,
    DateTime? customStartDate,
    DateTime? customEndDate,
    Set<String>? categories,
    Set<String>? paymentMethods,
    double? minAmount,
    double? maxAmount,
    ExpenseSortOption? sortBy,
    TransactionType? type,
    bool clearType = false,
    bool clearMinAmount = false,
    bool clearMaxAmount = false,
    bool clearCustomDates = false,
    bool clearAmounts = false,
  }) {
    return SearchFilter(
      query: query ?? this.query,
      datePreset: datePreset ?? this.datePreset,
      customStartDate: clearCustomDates ? null : (customStartDate ?? this.customStartDate),
      customEndDate: clearCustomDates ? null : (customEndDate ?? this.customEndDate),
      categories: categories ?? this.categories,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      minAmount: (clearAmounts || clearMinAmount) ? null : (minAmount ?? this.minAmount),
      maxAmount: (clearAmounts || clearMaxAmount) ? null : (maxAmount ?? this.maxAmount),
      sortBy: sortBy ?? this.sortBy,
      type: clearType ? null : (type ?? this.type),
    );
  }

  /// Resets all filters back to defaults.
  SearchFilter reset() => const SearchFilter();
}
