import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/search_filter.dart';
import 'package:expense_tracker/providers/expense_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Advanced Search & Filter Tests', () {
    late ExpenseProvider provider;
    final now = DateTime.now();

    setUp(() {
      provider = ExpenseProvider(autoFetch: false);
      provider.setExpensesForTesting([
        Expense(
          id: 1,
          amount: 250.0,
          category: 'Food & Dining',
          paymentMethod: 'UPI',
          comment: 'Domino pizza lunch',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
        Expense(
          id: 2,
          amount: 1200.0,
          category: 'Shopping',
          paymentMethod: 'Card',
          comment: 'Zara jacket',
          expenseDate: now.millisecondsSinceEpoch - 86400000, // Yesterday
          createdAt: now.millisecondsSinceEpoch - 86400000,
          updatedAt: now.millisecondsSinceEpoch - 86400000,
        ),
        Expense(
          id: 3,
          amount: 80.0,
          category: 'Transport',
          paymentMethod: 'Cash',
          comment: 'Metro card recharge',
          expenseDate: now.millisecondsSinceEpoch - (86400000 * 5), // 5 days ago
          createdAt: now.millisecondsSinceEpoch - (86400000 * 5),
          updatedAt: now.millisecondsSinceEpoch - (86400000 * 5),
        ),
      ]);
    });

    test('Full-text search matches comment', () {
      final results = provider.searchExpenses(const SearchFilter(query: 'pizza'));
      expect(results.length, 1);
      expect(results.first.id, 1);
      expect(results.first.comment, 'Domino pizza lunch');
    });

    test('Full-text search matches category', () {
      final results = provider.searchExpenses(const SearchFilter(query: 'shopping'));
      expect(results.length, 1);
      expect(results.first.id, 2);
    });

    test('Full-text search matches payment method', () {
      final results = provider.searchExpenses(const SearchFilter(query: 'cash'));
      expect(results.length, 1);
      expect(results.first.id, 3);
    });

    test('Category multi-selection filter', () {
      final results = provider.searchExpenses(
        const SearchFilter(categories: {'Food & Dining', 'Transport'}),
      );
      expect(results.length, 2);
      expect(results.any((e) => e.category == 'Food & Dining'), true);
      expect(results.any((e) => e.category == 'Transport'), true);
      expect(results.any((e) => e.category == 'Shopping'), false);
    });

    test('Payment method filter', () {
      final results = provider.searchExpenses(
        const SearchFilter(paymentMethods: {'Card'}),
      );
      expect(results.length, 1);
      expect(results.first.paymentMethod, 'Card');
    });

    test('Amount range filtering min and max', () {
      final results = provider.searchExpenses(
        const SearchFilter(minAmount: 100.0, maxAmount: 500.0),
      );
      expect(results.length, 1);
      expect(results.first.id, 1);
      expect(results.first.amount, 250.0);
    });

    test('Sorting by amount descending and ascending', () {
      final descResults = provider.searchExpenses(
        const SearchFilter(sortBy: ExpenseSortOption.amountDesc),
      );
      expect(descResults.first.amount, 1200.0);
      expect(descResults.last.amount, 80.0);

      final ascResults = provider.searchExpenses(
        const SearchFilter(sortBy: ExpenseSortOption.amountAsc),
      );
      expect(ascResults.first.amount, 80.0);
      expect(ascResults.last.amount, 1200.0);
    });

    test('SearchFilter active state and count helpers', () {
      var filter = SearchFilter.initial();
      expect(filter.hasActiveFilters, false);
      expect(filter.activeFilterCount, 0);

      filter = filter.copyWith(
        query: 'coffee',
        categories: {'Food & Dining'},
        minAmount: 50.0,
      );
      expect(filter.hasActiveFilters, true);
      expect(filter.activeFilterCount, 3);
    });
  });
}
