import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/services/database_service.dart';
import 'package:expense_tracker/utils/category_icons.dart';
import 'package:expense_tracker/widgets/category_payment_manager_sheet.dart';
import 'package:expense_tracker/widgets/searchable_selection_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CategoryIcons.init();
  });

  group('CategoryIcons Registry & Custom Icons', () {
    test('Default keyword icon matching works accurately', () {
      expect(CategoryIcons.get('Food & Dining'), Icons.restaurant);
      expect(CategoryIcons.get('Fast food'), Icons.restaurant);
      expect(CategoryIcons.get('Coffee & snacks'), Icons.coffee);
      expect(CategoryIcons.get('Groceries supermarket'), Icons.shopping_cart);
      expect(CategoryIcons.get('Shopping clothes'), Icons.shopping_bag);
      expect(CategoryIcons.get('Petrol fuel'), Icons.directions_car);
      expect(CategoryIcons.get('Electricity bill'), Icons.receipt);
      expect(CategoryIcons.get('Cinema movie tickets'), Icons.tv);
    });

    test('Payment method icon matching works accurately', () {
      expect(CategoryIcons.getPaymentMethodIcon('UPI'), Icons.qr_code_2);
      expect(CategoryIcons.getPaymentMethodIcon('Google Pay (UPI)'), Icons.qr_code_2);
      expect(CategoryIcons.getPaymentMethodIcon('Credit Card'), Icons.credit_card);
      expect(CategoryIcons.getPaymentMethodIcon('Debit Card'), Icons.credit_card);
      expect(CategoryIcons.getPaymentMethodIcon('Cash'), Icons.payments_outlined);
      expect(CategoryIcons.getPaymentMethodIcon('Bank Transfer'), Icons.account_balance);
    });

    test('Custom icon assignment overrides default icon', () async {
      expect(CategoryIcons.get('Gardening'), Icons.category);

      await CategoryIcons.setCustomIcon('Gardening', 'brush');
      expect(CategoryIcons.get('Gardening'), Icons.brush);
    });

    test('Custom icon rename and deletion work properly', () async {
      await CategoryIcons.setCustomIcon('My Pets', 'pets');
      expect(CategoryIcons.get('My Pets'), Icons.pets);

      await CategoryIcons.renameCategory('My Pets', 'Adopted Animals');
      expect(CategoryIcons.get('Adopted Animals'), Icons.pets);

      await CategoryIcons.deleteCategory('Adopted Animals');
      expect(CategoryIcons.get('Adopted Animals'), Icons.category);
    });
  });

  group('ExpenseProvider Category & Payment Method Sorting', () {
    test('Usage count and most-used-first sorting places frequent items forward', () async {
      final provider = ExpenseProvider(autoFetch: false);

      provider.expenses.clear();
      provider.categories.clear();
      provider.categories.addAll(['Food & Dining', 'Shopping', 'Transport', 'Entertainment']);
      provider.paymentMethods.clear();
      provider.paymentMethods.addAll(['Cash', 'Card', 'UPI', 'Transfer']);

      // Add dummy expenses:
      // Shopping: 3 times
      // Food: 2 times
      // Transport: 1 time
      final now = DateTime.now().millisecondsSinceEpoch;
      provider.expenses.addAll([
        Expense(amount: 100, category: 'Shopping', paymentMethod: 'UPI', createdAt: now, updatedAt: now, expenseDate: now),
        Expense(amount: 200, category: 'Shopping', paymentMethod: 'UPI', createdAt: now, updatedAt: now, expenseDate: now),
        Expense(amount: 300, category: 'Shopping', paymentMethod: 'Card', createdAt: now, updatedAt: now, expenseDate: now),
        Expense(amount: 50, category: 'Food & Dining', paymentMethod: 'Card', createdAt: now, updatedAt: now, expenseDate: now),
        Expense(amount: 60, category: 'Food & Dining', paymentMethod: 'Cash', createdAt: now, updatedAt: now, expenseDate: now),
        Expense(amount: 20, category: 'Transport', paymentMethod: 'UPI', createdAt: now, updatedAt: now, expenseDate: now),
      ]);

      expect(provider.getCategoryUsageCount('Shopping'), 3);
      expect(provider.getCategoryUsageCount('Food & Dining'), 2);
      expect(provider.getCategoryUsageCount('Transport'), 1);
      expect(provider.getCategoryUsageCount('Entertainment'), 0);

      // Most used first
      final sortedCategories = provider.getSortedCategories(mostUsedFirst: true);
      expect(sortedCategories.first, 'Shopping');
      expect(sortedCategories[1], 'Food & Dining');
      expect(sortedCategories[2], 'Transport');
      expect(sortedCategories[3], 'Entertainment');

      // Least used first (backward)
      final leastUsedCategories = provider.getSortedCategories(mostUsedFirst: false);
      expect(leastUsedCategories.first, 'Entertainment');
      expect(leastUsedCategories.last, 'Shopping');

      // Payment method counts
      expect(provider.getPaymentMethodUsageCount('UPI'), 3);
      expect(provider.getPaymentMethodUsageCount('Card'), 2);
      expect(provider.getPaymentMethodUsageCount('Cash'), 1);
      expect(provider.getPaymentMethodUsageCount('Transfer'), 0);

      final sortedMethods = provider.getSortedPaymentMethods(mostUsedFirst: true);
      expect(sortedMethods.first, 'UPI');
      expect(sortedMethods[1], 'Card');
      expect(sortedMethods[2], 'Cash');
      expect(sortedMethods[3], 'Transfer');

      // Month-specific calculations
      final thisYear = DateTime.fromMillisecondsSinceEpoch(now).year;
      final thisMonth = DateTime.fromMillisecondsSinceEpoch(now).month;
      expect(provider.getTotalExpensesForMonth(thisYear, thisMonth), 730.0);
      expect(provider.getTotalExpensesForMonth(thisYear - 1, 1), 0.0);

      final monthCats = provider.getCategoryTotalsForMonth(thisYear, thisMonth);
      expect(monthCats['Shopping'], 600.0);
      expect(monthCats['Food & Dining'], 110.0);
      expect(monthCats['Transport'], 20.0);
      expect(monthCats['Entertainment'], isNull);
      // Test reordering categories
      await provider.reorderCategories(2, 0); // Move Transport to first
      expect(provider.categories.first, 'Transport');
      expect(provider.categories[1], 'Food & Dining');

      // Test reordering payment methods
      await provider.reorderPaymentMethods(2, 0); // Move UPI (index 2) to first
      expect(provider.paymentMethods.first, 'UPI');
      expect(provider.paymentMethods[1], 'Cash');
    });

    testWidgets('CategoryPaymentManagerSheet renders with drag & drop chips, handles, and category icons', (tester) async {
      final provider = ExpenseProvider(autoFetch: false);
      provider.categories.clear();
      provider.categories.addAll(['Food & Dining', 'Shopping', 'Transport']);
      provider.paymentMethods.clear();
      provider.paymentMethods.addAll(['UPI', 'Card', 'Cash']);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ExpenseProvider>.value(
            value: provider,
            child: const Scaffold(
              body: CategoryPaymentManagerSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Categories & Methods'), findsOneWidget);
      expect(find.text('Drag & Drop'), findsOneWidget);
      expect(find.text('Most Used'), findsOneWidget);
      expect(find.text('A-Z'), findsOneWidget);

      // Verify category rows rendered
      expect(find.text('Food & Dining'), findsOneWidget);
      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      expect(find.byIcon(Icons.drag_indicator), findsWidgets);

      // Tap sort chip to switch to A-Z
      await tester.tap(find.text('A-Z'));
      await tester.pumpAndSettle();
      expect(provider.categories.first, 'Food & Dining');

      // Test adding a category via dialog
      await tester.tap(find.text('Add Category'));
      await tester.pumpAndSettle();

      expect(find.text('Add New Category'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Category Name'), 'Gym & Fitness');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Ensure all categories remain visible and newly added category appears!
      expect(find.text('Gym & Fitness'), findsOneWidget);
      expect(find.text('Food & Dining'), findsOneWidget);
      expect(find.text('Shopping'), findsOneWidget);
    });

    test('Adding and persisting categories and payment methods does not wipe data', () async {
      final provider = ExpenseProvider(autoFetch: false);
      final initialCategories = await DatabaseService.instance.getCategories();
      expect(initialCategories, isNotEmpty);

      await provider.addCategory('Pet Care');
      expect(provider.categories.contains('Pet Care'), isTrue);
      // Ensure previous categories still exist
      expect(provider.categories.contains(initialCategories.first), isTrue);

      // Verify persistence across getCategories call
      final reloadedCategories = await DatabaseService.instance.getCategories();
      expect(reloadedCategories.contains('Pet Care'), isTrue);

      // Same for payment methods
      final initialMethods = await DatabaseService.instance.getPaymentMethods();
      expect(initialMethods, isNotEmpty);

      await provider.addPaymentMethod('Cheque');
      expect(provider.paymentMethods.contains('Cheque'), isTrue);
      expect(provider.paymentMethods.contains(initialMethods.first), isTrue);

      final reloadedMethods = await DatabaseService.instance.getPaymentMethods();
      expect(reloadedMethods.contains('Cheque'), isTrue);
    });

    testWidgets('SearchableSelectionSheet filters categories and shows icons and usage badges', (tester) async {
      final provider = ExpenseProvider(autoFetch: false);
      final now = DateTime.now().millisecondsSinceEpoch;
      provider.expenses.addAll([
        Expense(amount: 150, category: 'Food & Dining', paymentMethod: 'UPI', createdAt: now, updatedAt: now, expenseDate: now),
        Expense(amount: 80, category: 'Food & Dining', paymentMethod: 'UPI', createdAt: now, updatedAt: now, expenseDate: now),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ExpenseProvider>.value(
            value: provider,
            child: Scaffold(
              body: SearchableSelectionSheet(
                title: 'Select Category',
                items: const ['Food & Dining', 'Shopping', 'Entertainment'],
                selectedItem: 'Shopping',
                isCategory: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Select Category'), findsOneWidget);
      expect(find.text('3 available'), findsOneWidget);
      expect(find.text('Most used first'), findsOneWidget);
      expect(find.text('2x'), findsOneWidget); // 2 transactions for Food & Dining

      // Enter search query
      await tester.enterText(find.byType(TextField), 'shop');
      await tester.pumpAndSettle();

      expect(find.text('1 available'), findsOneWidget);
      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('Food & Dining'), findsNothing);
    });
  });
}
