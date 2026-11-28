import 'package:expense_tracker/models/split_models.dart';
import 'package:expense_tracker/providers/split_provider.dart';
import 'package:expense_tracker/screens/split/add_split_expense_sheet.dart';
import 'package:expense_tracker/services/split_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const tripId = 'mixed-vacation';
final tripDate = DateTime(2026, 11, 27);
const guests = ['Asha', 'Arun', 'Dev', 'Diya', 'Esha', 'Evan', 'Neel', 'Tara'];

void main() {
  testWidgets('mixed participants, payment modes, and household settlements', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(850, 1650));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final members = [
      for (final name in guests)
        SplitMember(id: name, groupId: tripId, name: name, joinedAt: tripDate),
    ];
    final households = [
      SplitSettlementGroup(
        id: 'couple',
        groupId: tripId,
        name: 'Couple',
        memberIds: ['Asha', 'Arun'],
        createdAt: tripDate,
        updatedAt: tripDate,
      ),
      SplitSettlementGroup(
        id: 'family',
        groupId: tripId,
        name: 'Family',
        memberIds: ['Dev', 'Diya', 'Esha', 'Evan'],
        createdAt: tripDate,
        updatedAt: tripDate,
      ),
    ];
    final ledger = RecordingSplitProvider();
    addTearDown(ledger.dispose);
    await tester.pumpAndSettle();
    ledger.setGroupDetailForTesting(
      groupId: tripId,
      members: members,
      settlementGroups: households,
    );

    Future<void> enterBill({
      required String title,
      required String amount,
      required String payer,
      required Map<String, int> expectedShares,
      String type = 'Equal',
      Map<String, String> allocation = const {},
    }) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<SplitProvider>.value(
          value: ledger,
          child: MaterialApp(
            key: ValueKey(title),
            home: Scaffold(
              body: AddSplitExpenseSheet(
                groupId: tripId,
                members: members,
                currentMemberName: 'Asha',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final billCount = ledger.bills.length;
      await tester.enterText(
        find.widgetWithText(TextField, 'What was it for?'),
        title,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Total Amount (₹)'),
        amount,
      );
      await tester.tap(find.text(payer).first);
      expect(memberRow('Arun'), findsNothing);
      if (type == 'Equal') {
        for (final household in households) {
          final header = find.text(household.name);
          await tester.ensureVisible(header);
          await tester.tap(header);
          await tester.pumpAndSettle();
        }
      } else {
        final typeControl = find.text(type);
        await tester.ensureVisible(typeControl);
        await tester.tap(typeControl);
        await tester.pumpAndSettle();
        expect(memberRow('Arun'), findsOneWidget);
        expect(memberRow('Diya'), findsOneWidget);
      }
      for (final guest in guests.where(
        (guest) => !expectedShares.containsKey(guest),
      )) {
        final checkbox = find.descendant(
          of: memberRow(guest),
          matching: find.byType(Checkbox),
        );
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
      }
      expect(
        find.text('${expectedShares.length} of 8 selected'),
        findsOneWidget,
      );
      for (final entry in allocation.entries) {
        final field = find.descendant(
          of: memberRow(entry.key),
          matching: find.byType(TextField),
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      final save = find.widgetWithText(ElevatedButton, 'Add Expense');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(ledger.bills.length, billCount + 1, reason: '$title should save');
      expect(ledger.bills.last.paidByMemberId, payer, reason: title);
      final savedShares = {
        for (final share in ledger.shares.where(
          (share) => share.expenseId == title,
        ))
          share.memberId: paise(share.shareAmount),
      };
      expect(savedShares, expectedShares, reason: title);
      expect(
        savedShares.values.reduce((a, b) => a + b),
        paise(ledger.bills.last.totalAmount),
      );
    }

    await enterBill(
      title: 'Hotel',
      amount: '16000',
      payer: 'Asha',
      expectedShares: {for (final guest in guests) guest: 200000},
    );
    await enterBill(
      title: 'Boat',
      amount: '3600',
      payer: 'Dev',
      expectedShares: {
        'Arun': 90000,
        'Diya': 90000,
        'Evan': 90000,
        'Neel': 90000,
      },
    );
    await enterBill(
      title: 'Dinner',
      amount: '2550',
      payer: 'Neel',
      expectedShares: {'Asha': 85000, 'Dev': 85000, 'Tara': 85000},
    );
    await enterBill(
      title: 'Market',
      amount: '1475',
      payer: 'Tara',
      type: 'Unequal',
      allocation: {'Asha': '175', 'Diya': '300', 'Esha': '450', 'Tara': '550'},
      expectedShares: {
        'Asha': 17500,
        'Diya': 30000,
        'Esha': 45000,
        'Tara': 55000,
      },
    );
    await enterBill(
      title: 'Cab',
      amount: '1000.01',
      payer: 'Arun',
      expectedShares: {'Arun': 33334, 'Esha': 33334, 'Neel': 33333},
    );
    await enterBill(
      title: 'Tickets',
      amount: '2400',
      payer: 'Diya',
      type: 'Percentage',
      allocation: {'Asha': '50', 'Esha': '25', 'Neel': '25'},
      expectedShares: {'Asha': 120000, 'Esha': 60000, 'Neel': 60000},
    );
    await enterBill(
      title: 'Family snacks',
      amount: '800',
      payer: 'Dev',
      expectedShares: {
        'Dev': 20000,
        'Diya': 20000,
        'Esha': 20000,
        'Evan': 20000,
      },
    );

    Map<String, double> balances(List<Settlement> settlements) =>
        SplitService.instance.computeBalancesFromData(
          members: members,
          expenses: ledger.bills,
          shares: ledger.shares,
          settlements: settlements,
        );

    List<Debt> direct(List<Settlement> settlements) => eliminateDebtCycles(
      calculateDirectDebtsWithGroups(
        expenses: ledger.bills,
        shares: ledger.shares,
        settlements: settlements,
        settlementGroups: households,
      ),
    );

    List<Debt> simplified(List<Settlement> settlements) =>
        simplifyDebtsWithGroups(
          individualBalances: balances(settlements),
          settlementGroups: households,
        );

    Map<String, int> entities(List<Settlement> settlements) => inPaise(
      aggregateCombinedBalances(
        individualBalances: balances(settlements),
        settlementGroups: households,
      ).entityBalances,
    );

    // Expected balances are from an independent integer-paise ledger.
    expect(inPaise(balances([])), {
      'Asha': 1177500,
      'Arun': -223333,
      'Dev': 135000,
      'Diya': -100000,
      'Esha': -358334,
      'Evan': -310000,
      'Neel': -128333,
      'Tara': -192500,
    });
    expect(entities([]), {
      'sg_couple': 954167,
      'sg_family': -633334,
      'Neel': -128333,
      'Tara': -192500,
    });
    expect(transfers(direct([])), {
      'family → couple': 623334,
      'Neel → couple': 148333,
      'Tara → couple': 182500,
      'Tara → Neel': 20000,
      'family → Tara': 10000,
    });
    expect(transfers(simplified([])), {
      'family → couple': 633334,
      'Neel → couple': 128333,
      'Tara → couple': 192500,
    });

    final partial = payment(
      '1',
      'Esha',
      'Arun',
      1500,
      fromHousehold: 'family',
      toHousehold: 'couple',
    );
    expect(inPaise(balances([partial]))['Esha'], -208334);
    expect(inPaise(balances([partial]))['Arun'], -373333);
    expect(entities([partial]), {
      'sg_couple': 804167,
      'sg_family': -483334,
      'Neel': -128333,
      'Tara': -192500,
    });
    expect(transfers(direct([partial]))['family → couple'], 473334);
    expect(transfers(simplified([partial])), {
      'family → couple': 483334,
      'Neel → couple': 128333,
      'Tara → couple': 192500,
    });

    final settled = [
      partial,
      payment(
        '2',
        'Dev',
        'Asha',
        4833.34,
        fromHousehold: 'family',
        toHousehold: 'couple',
      ),
      payment('3', 'Neel', 'Asha', 1283.33, toHousehold: 'couple'),
      payment('4', 'Tara', 'Arun', 1925, toHousehold: 'couple'),
    ];
    expect(entities(settled), {
      'sg_couple': 0,
      'sg_family': 0,
      'Neel': 0,
      'Tara': 0,
    });
    expect(direct(settled), isEmpty);
    expect(simplified(settled), isEmpty);
  });
}

Finder memberRow(String guest) => find.byWidgetPredicate(
  (widget) =>
      widget is Row &&
      widget.children.any(
        (child) =>
            child is Expanded &&
            child.child is Text &&
            (child.child as Text).data == guest,
      ),
);

int paise(double rupees) => (rupees * 100).round();

Map<String, int> inPaise(Map<String, double> amounts) =>
    amounts.map((key, value) => MapEntry(key, paise(value)));

Map<String, int> transfers(List<Debt> debts) => {
  for (final debt in debts)
    '${debt.fromSettlementGroupId ?? debt.fromMemberId} → '
        '${debt.toSettlementGroupId ?? debt.toMemberId}': paise(debt.amount),
};

Settlement payment(
  String id,
  String from,
  String to,
  double amount, {
  String? fromHousehold,
  String? toHousehold,
}) => Settlement(
  id: id,
  groupId: tripId,
  fromMemberId: from,
  toMemberId: to,
  amount: amount,
  settledAt: tripDate,
  fromSettlementGroupId: fromHousehold,
  toSettlementGroupId: toHousehold,
);

class RecordingSplitProvider extends SplitProvider {
  final bills = <SplitExpense>[];
  final shares = <SplitShare>[];

  @override
  Future<void> addExpense({
    required String groupId,
    required String title,
    required double totalAmount,
    required String paidByMemberId,
    required SplitType splitType,
    required Map<String, double> shares,
    String? category,
    String? note,
    String? receiptUrl,
    required String addedByMemberId,
  }) async {
    bills.add(
      SplitExpense(
        id: title,
        groupId: groupId,
        title: title,
        totalAmount: totalAmount,
        paidByMemberId: paidByMemberId,
        splitType: splitType,
        addedByMemberId: addedByMemberId,
        createdAt: tripDate,
      ),
    );
    for (final entry in shares.entries) {
      this.shares.add(
        SplitShare(
          id: '$title-${entry.key}',
          expenseId: title,
          memberId: entry.key,
          shareAmount: entry.value,
        ),
      );
    }
  }
}
