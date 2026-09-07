enum ExpenseSortOption {
  dateDesc('Date: Newest First'),
  dateAsc('Date: Oldest First'),
  amountDesc('Amount: Highest First'),
  amountAsc('Amount: Lowest First');

  final String label;
  const ExpenseSortOption(this.label);
}

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
  });

  bool get hasActiveFilters {
    return query.trim().isNotEmpty ||
        datePreset != DateRangePreset.all ||
        categories.isNotEmpty ||
        paymentMethods.isNotEmpty ||
        minAmount != null ||
        maxAmount != null ||
        sortBy != ExpenseSortOption.dateDesc;
  }

  int get activeFilterCount {
    int count = 0;
    if (query.trim().isNotEmpty) count++;
    if (datePreset != DateRangePreset.all) count++;
    if (categories.isNotEmpty) count += categories.length;
    if (paymentMethods.isNotEmpty) count += paymentMethods.length;
    if (minAmount != null || maxAmount != null) count++;
    if (sortBy != ExpenseSortOption.dateDesc) count++;
    return count;
  }

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
    bool clearMinAmount = false,
    bool clearMaxAmount = false,
    bool clearCustomDates = false,
  }) {
    return SearchFilter(
      query: query ?? this.query,
      datePreset: datePreset ?? this.datePreset,
      customStartDate: clearCustomDates ? null : (customStartDate ?? this.customStartDate),
      customEndDate: clearCustomDates ? null : (customEndDate ?? this.customEndDate),
      categories: categories ?? this.categories,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      minAmount: clearMinAmount ? null : (minAmount ?? this.minAmount),
      maxAmount: clearMaxAmount ? null : (maxAmount ?? this.maxAmount),
      sortBy: sortBy ?? this.sortBy,
    );
  }

  static SearchFilter initial() => const SearchFilter();
}
