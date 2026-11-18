import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/widgets/searchable_selection_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Income Categories - ExpenseProvider & DatabaseService Integration', () {
    test('Default income categories are initialized and distinct from expenses', () {
      final provider = ExpenseProvider(autoFetch: false);
      provider.setExpensesForTesting([]);

      final incomeCats = provider.incomeCategories;
      final expenseCats = provider.categories;

      expect(incomeCats, contains('Salary'));
      expect(incomeCats, contains('Freelance'));
      expect(incomeCats, contains('Investments'));
      expect(incomeCats, contains('Refund / Cashback'));
      expect(incomeCats, contains('Rental Income'));
      expect(incomeCats, contains('Gifts'));
      expect(incomeCats, contains('Other Income'));

      // Salary was moved out of expense categories into income categories
      expect(expenseCats, isNot(contains('Salary')));
    });

    test('Add, update, and delete income category in provider', () async {
      final provider = ExpenseProvider(autoFetch: false);
      provider.setExpensesForTesting([]);

      // Add custom income category
      await provider.addIncomeCategory('Consulting');
      expect(provider.incomeCategories, contains('Consulting'));

      // Duplicate addition should be a no-op
      await provider.addIncomeCategory('Consulting');
      expect(provider.incomeCategories.where((c) => c == 'Consulting').length, 1);

      // Update income category
      await provider.updateIncomeCategory('Consulting', 'Tech Consulting');
      expect(provider.incomeCategories, isNot(contains('Consulting')));
      expect(provider.incomeCategories, contains('Tech Consulting'));

      // Delete income category
      await provider.deleteIncomeCategory('Tech Consulting');
      expect(provider.incomeCategories, isNot(contains('Tech Consulting')));
    });

    test('Income category sorting by usage count', () async {
      final provider = ExpenseProvider(autoFetch: false);
      final nowMillis = DateTime.now().millisecondsSinceEpoch;

      final expenses = [
        Expense(
          id: 1,
          amount: 50000,
          category: 'Salary',
          paymentMethod: 'Bank Transfer',
          expenseDate: nowMillis,
          createdAt: nowMillis,
          updatedAt: nowMillis,
          type: TransactionType.income,
        ),
        Expense(
          id: 2,
          amount: 15000,
          category: 'Freelance',
          paymentMethod: 'UPI',
          expenseDate: nowMillis,
          createdAt: nowMillis,
          updatedAt: nowMillis,
          type: TransactionType.income,
        ),
        Expense(
          id: 3,
          amount: 8000,
          category: 'Freelance',
          paymentMethod: 'UPI',
          expenseDate: nowMillis,
          createdAt: nowMillis,
          updatedAt: nowMillis,
          type: TransactionType.income,
        ),
        Expense(
          id: 4,
          amount: 12000,
          category: 'Freelance',
          paymentMethod: 'UPI',
          expenseDate: nowMillis,
          createdAt: nowMillis,
          updatedAt: nowMillis,
          type: TransactionType.income,
        ),
      ];

      provider.setExpensesForTesting(expenses);

      expect(provider.getIncomeCategoryUsageCount('Freelance'), 3);
      expect(provider.getIncomeCategoryUsageCount('Salary'), 1);
      expect(provider.getIncomeCategoryUsageCount('Investments'), 0);

      // Most-used first sort
      final mostUsed = provider.getSortedIncomeCategories(mostUsedFirst: true);
      expect(mostUsed.first, 'Freelance');
      expect(mostUsed[1], 'Salary');

      // Least-used first sort
      final leastUsed = provider.getSortedIncomeCategories(mostUsedFirst: false);
      expect(leastUsed.last, 'Freelance');
    });

    test('Reorder income categories updates order', () async {
      final provider = ExpenseProvider(autoFetch: false);
      provider.setExpensesForTesting([]);

      final initialFirst = provider.incomeCategories.first;
      // Reorder item at 0 to index 3
      await provider.reorderIncomeCategories(0, 3);
      expect(provider.incomeCategories[0], isNot(initialFirst));
      expect(provider.incomeCategories.contains(initialFirst), isTrue);
    });
  });

  group('Income Categories - UI Selection Sheet Widget Tests', () {
    testWidgets('SearchableSelectionSheet displays income categories and usage count correctly', (tester) async {
      final provider = ExpenseProvider(autoFetch: false);
      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      provider.setExpensesForTesting([
        Expense(
          id: 1,
          amount: 50000,
          category: 'Salary',
          paymentMethod: 'Bank Transfer',
          expenseDate: nowMillis,
          createdAt: nowMillis,
          updatedAt: nowMillis,
          type: TransactionType.income,
        ),
      ]);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => SearchableSelectionSheet(
                        title: 'Select Income Category',
                        items: provider.incomeCategories,
                        selectedItem: 'Salary',
                        isCategory: true,
                        isIncomeCategory: true,
                        onAddNew: (query) {},
                      ),
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Select Income Category'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('1 transactions logged'), findsOneWidget);
      expect(find.text('Freelance'), findsOneWidget);
      expect(find.text('Not used yet'), findsWidgets);
      expect(find.text('Add New'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets('SearchableSelectionSheet search and "+ Add New" triggers onAddNew callback', (tester) async {
      final provider = ExpenseProvider(autoFetch: false);
      provider.setExpensesForTesting([]);

      String? addedQuery;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => SearchableSelectionSheet(
                        title: 'Select Income Category',
                        items: provider.incomeCategories,
                        selectedItem: 'Salary',
                        isCategory: true,
                        isIncomeCategory: true,
                        onAddNew: (query) {
                          addedQuery = query;
                        },
                      ),
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Search for non-existent category
      await tester.enterText(find.byType(TextField), 'Crypto Yield');
      await tester.pumpAndSettle();

      expect(find.text('No matches found for "Crypto Yield"'), findsOneWidget);
      expect(find.text('Create "Crypto Yield"'), findsOneWidget);

      await tester.tap(find.text('Create "Crypto Yield"'));
      await tester.pumpAndSettle();

      expect(addedQuery, 'Crypto Yield');
    });
  });
}
