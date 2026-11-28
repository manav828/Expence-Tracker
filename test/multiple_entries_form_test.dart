import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/widgets/add_expense_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class _RecordingExpenseProvider extends ExpenseProvider {
  _RecordingExpenseProvider({this.failOnceOn}) : super(autoFetch: false);

  final double? failOnceOn;
  final saved = <Expense>[];
  bool _failed = false;

  @override
  Future<void> addExpense(Expense expense) async {
    if (!_failed && expense.amount == failOnceOn) {
      _failed = true;
      throw StateError('Simulated storage failure');
    }
    saved.add(expense);
    setExpensesForTesting(saved);
  }
}

Finder _input(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _openEntrySheet(
  WidgetTester tester,
  ExpenseProvider provider,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<ExpenseProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () => AddExpenseSheet.showForNewEntry(context),
                  child: const Text('Open entry sheet'),
                ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open entry sheet'));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enterVisible(
  WidgetTester tester,
  Finder finder,
  String value,
) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Adds a day of expenses and income in one sheet', (tester) async {
    tester.view.physicalSize = const Size(393, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = _RecordingExpenseProvider();
    addTearDown(provider.dispose);
    await _openEntrySheet(tester, provider);

    expect(find.text('Entries (1)'), findsOneWidget);
    expect(find.text('Add Spend'), findsNothing);
    expect(_input('Amount'), findsOneWidget);
    expect(find.text('₹0.00'), findsOneWidget);
    await _enterVisible(tester, _input('Amount'), '320');
    await _tapVisible(tester, find.text('Add Another Entry'));
    expect(find.byType(AddExpenseSheet), findsOneWidget);
    expect(find.text('Entries (2)'), findsOneWidget);
    expect(find.text('₹320.00'), findsOneWidget);
    expect(find.text('Bulk Date'), findsNothing);
    expect(
      tester.widget<TextField>(_input('Amount').first).controller!.text,
      '320',
    );

    await tester.tap(find.text('Save 2 Entries'));
    await tester.pumpAndSettle();
    expect(provider.saved, isEmpty);
    expect(find.text('Enter a valid amount'), findsOneWidget);

    await _enterVisible(tester, _input('Amount').at(1), '1,200.00');
    await _tapVisible(tester, find.byTooltip('Payment method for entry 2'));
    await tester.tap(find.text('Card'));
    await tester.pumpAndSettle();
    await _enterVisible(tester, _input('Note (optional)').at(1), 'Groceries');
    await _tapVisible(tester, find.text('Add Another Entry'));
    expect(find.text('Entries (3)'), findsOneWidget);
    await _enterVisible(tester, _input('Amount').at(2), '560');
    await _tapVisible(tester, find.byTooltip('Transaction type for entry 3'));
    await tester.tap(find.text('Income').last);
    await tester.pumpAndSettle();
    expect(find.text('₹2,080.00'), findsOneWidget);

    final pastDate = DateTime(2025, 11, 22);
    await _tapVisible(tester, find.byTooltip('Date for entry 3'));
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).last,
      DateFormat('MM/dd/yyyy').format(pastDate),
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save 3 Entries'));
    await tester.pumpAndSettle();

    expect(find.byType(AddExpenseSheet), findsNothing);
    expect(provider.saved.map((expense) => expense.amount), [320, 1200, 560]);
    expect(provider.saved.map((expense) => expense.type), [
      TransactionType.expense,
      TransactionType.expense,
      TransactionType.income,
    ]);
    expect(provider.saved[1].paymentMethod, 'Card');
    expect(provider.saved[1].comment, 'Groceries');
    expect(provider.saved[2].paymentMethod, 'Card');
    expect(provider.saved[2].category, 'Salary');
    expect(DateUtils.isSameDay(provider.saved[2].dateTime, pastDate), isTrue);
  });

  testWidgets('Removes drafts and retries only unsaved entries', (
    tester,
  ) async {
    final provider = _RecordingExpenseProvider(failOnceOn: 75);
    addTearDown(provider.dispose);
    await _openEntrySheet(tester, provider);

    await _enterVisible(tester, _input('Amount'), '50');
    await _tapVisible(tester, find.text('Add Another Entry'));
    await _enterVisible(tester, _input('Amount').at(1), '75');
    await _tapVisible(tester, find.text('Add Another Entry'));
    await _enterVisible(tester, _input('Amount').at(2), '25');
    expect(find.text('₹150.00'), findsOneWidget);
    await _tapVisible(tester, find.byTooltip('Remove entry 3'));
    expect(find.text('Entries (2)'), findsOneWidget);
    expect(find.text('₹125.00'), findsOneWidget);

    await tester.tap(find.text('Save 2 Entries'));
    await tester.pumpAndSettle();
    expect(provider.saved.map((expense) => expense.amount), [50]);
    expect(find.text('Saved 1. 1 left to save. Try again.'), findsOneWidget);
    expect(find.text('₹75.00'), findsOneWidget);
    expect(tester.widget<TextField>(_input('Amount')).controller!.text, '75');

    await tester.tap(find.text('Save Entry'));
    await tester.pumpAndSettle();
    expect(provider.saved.map((expense) => expense.amount), [50, 75]);
    expect(
      provider.saved.map((expense) => expense.createdAt).toSet(),
      hasLength(2),
    );
    expect(find.byType(AddExpenseSheet), findsNothing);
  });

  testWidgets('Saves directly from the default single entry card', (
    tester,
  ) async {
    final provider = _RecordingExpenseProvider();
    addTearDown(provider.dispose);
    await _openEntrySheet(tester, provider);

    expect(find.text('Entries (1)'), findsOneWidget);
    expect(find.text('Attach receipt'), findsOneWidget);
    await _enterVisible(tester, _input('Amount'), '450');
    await tester.tap(find.text('Save Entry'));
    await tester.pumpAndSettle();

    expect(provider.saved.single.amount, 450);
    expect(find.byType(AddExpenseSheet), findsNothing);
  });
}
