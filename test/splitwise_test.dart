import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/split_models.dart';

void main() {
  group('Splitwise Simplification & Debt Algorithm Tests', () {
    test('simplifyDebts with zero balances returns empty list', () {
      final balances = {'m1': 0.0, 'm2': 0.0, 'm3': 0.0};
      final debts = simplifyDebts(balances);
      expect(debts, isEmpty);
    });

    test('Two members: 1 owes another', () {
      // Alice paid 100 for Alice and Bob (50 each)
      // Alice is owed 50, Bob owes 50
      final balances = {'alice': 50.0, 'bob': -50.0};
      final debts = simplifyDebts(balances);

      expect(debts.length, 1);
      expect(debts.first.fromMemberId, 'bob');
      expect(debts.first.toMemberId, 'alice');
      expect(debts.first.amount, 50.0);
    });

    test('Three members: circular simplification to minimal transactions', () {
      // Alice: +100, Bob: -60, Charlie: -40
      final balances = {'alice': 100.0, 'bob': -60.0, 'charlie': -40.0};
      final debts = simplifyDebts(balances);

      expect(debts.length, 2);
      expect(debts[0].fromMemberId, 'bob');
      expect(debts[0].toMemberId, 'alice');
      expect(debts[0].amount, 60.0);

      expect(debts[1].fromMemberId, 'charlie');
      expect(debts[1].toMemberId, 'alice');
      expect(debts[1].amount, 40.0);
    });

    test('SplitType equal shares math', () {
      const total = 300.0;
      final members = ['A', 'B', 'C'];
      final equalShare = total / members.length;
      final shares = {for (final m in members) m: equalShare};

      expect(shares['A'], 100.0);
      expect(shares['B'], 100.0);
      expect(shares['C'], 100.0);
      expect(shares.values.reduce((a, b) => a + b), total);
    });

    test('SplitGroup and SplitExpense model serialization', () {
      final now = DateTime.now();
      final group = SplitGroup(
        id: 'g-123',
        name: 'Goa Trip',
        description: 'Weekend vacation',
        createdBy: 'Manav',
        inviteCode: 'GOA2026X',
        createdAt: now,
      );

      final map = group.toMap();
      expect(map['id'], 'g-123');
      expect(map['invite_code'], 'GOA2026X');

      final restored = SplitGroup.fromMap(map);
      expect(restored.name, 'Goa Trip');
      expect(restored.inviteCode, 'GOA2026X');

      final expense = SplitExpense(
        id: 'e-1',
        groupId: 'g-123',
        title: 'Dinner at Beach',
        totalAmount: 1500.0,
        paidByMemberId: 'm-1',
        splitType: SplitType.equal,
        receiptUrl: 'https://pub-5931ad4398be42b6a8a7426e57c49b6b.r2.dev/receipts/bill123.jpg',
        addedByMemberId: 'm-2',
        createdAt: now,
      );

      final expMap = expense.toMap();
      expect(expMap['split_type'], 'equal');
      expect(expMap['added_by_member_id'], 'm-2');
      expect(expMap['receipt_url'], 'https://pub-5931ad4398be42b6a8a7426e57c49b6b.r2.dev/receipts/bill123.jpg');

      final restoredExp = SplitExpense.fromMap(expMap);
      expect(restoredExp.title, 'Dinner at Beach');
      expect(restoredExp.totalAmount, 1500.0);
      expect(restoredExp.splitType, SplitType.equal);
      expect(restoredExp.receiptUrl, 'https://pub-5931ad4398be42b6a8a7426e57c49b6b.r2.dev/receipts/bill123.jpg');

      final clonedExp = restoredExp.copyWith(receiptUrl: 'https://example.com/new_receipt.jpg');
      expect(clonedExp.receiptUrl, 'https://example.com/new_receipt.jpg');
      expect(clonedExp.title, 'Dinner at Beach');
    });

    test('calculateDirectDebts vs simplifyDebts comparison', () {
      final now = DateTime.now();
      final exp1 = SplitExpense(
        id: 'exp1',
        groupId: 'g1',
        title: 'Lunch',
        totalAmount: 300.0,
        paidByMemberId: 'alice',
        splitType: SplitType.equal,
        addedByMemberId: 'alice',
        createdAt: now,
      );
      final shares1 = [
        SplitShare(id: 's1', expenseId: 'exp1', memberId: 'alice', shareAmount: 100.0),
        SplitShare(id: 's2', expenseId: 'exp1', memberId: 'bob', shareAmount: 100.0),
        SplitShare(id: 's3', expenseId: 'exp1', memberId: 'charlie', shareAmount: 100.0),
      ];

      final exp2 = SplitExpense(
        id: 'exp2',
        groupId: 'g1',
        title: 'Snacks',
        totalAmount: 150.0,
        paidByMemberId: 'bob',
        splitType: SplitType.equal,
        addedByMemberId: 'bob',
        createdAt: now,
      );
      final shares2 = [
        SplitShare(id: 's4', expenseId: 'exp2', memberId: 'bob', shareAmount: 75.0),
        SplitShare(id: 's5', expenseId: 'exp2', memberId: 'charlie', shareAmount: 75.0),
      ];

      // 1. Direct Debts:
      // Bob owes Alice 100
      // Charlie owes Alice 100
      // Charlie owes Bob 75
      final directDebts = calculateDirectDebts(
        expenses: [exp1, exp2],
        shares: [...shares1, ...shares2],
        settlements: [],
      );

      expect(directDebts.length, 3);
      final bobToAlice = directDebts.firstWhere((d) => d.fromMemberId == 'bob' && d.toMemberId == 'alice');
      expect(bobToAlice.amount, 100.0);

      final charlieToAlice = directDebts.firstWhere((d) => d.fromMemberId == 'charlie' && d.toMemberId == 'alice');
      expect(charlieToAlice.amount, 100.0);

      final charlieToBob = directDebts.firstWhere((d) => d.fromMemberId == 'charlie' && d.toMemberId == 'bob');
      expect(charlieToBob.amount, 75.0);

      // 2. Simplified Debts (Min Payments):
      // Net balances:
      // Alice: paid 300, consumed 100 => +200
      // Bob: paid 150, consumed 175 => -25
      // Charlie: paid 0, consumed 175 => -175
      final netBalances = {
        'alice': 200.0,
        'bob': -25.0,
        'charlie': -175.0,
      };
      final simplifiedDebts = simplifyDebts(netBalances);

      // Should be reduced from 3 down to 2 payments!
      expect(simplifiedDebts.length, 2);
      expect(simplifiedDebts[0].fromMemberId, 'charlie');
      expect(simplifiedDebts[0].toMemberId, 'alice');
      expect(simplifiedDebts[0].amount, 175.0);

      expect(simplifiedDebts[1].fromMemberId, 'bob');
      expect(simplifiedDebts[1].toMemberId, 'alice');
      expect(simplifiedDebts[1].amount, 25.0);
    });

    test('calculateDirectDebts with settlement reduction', () {
      final now = DateTime.now();
      final exp = SplitExpense(
        id: 'exp1',
        groupId: 'g1',
        title: 'Cab',
        totalAmount: 200.0,
        paidByMemberId: 'alice',
        splitType: SplitType.equal,
        addedByMemberId: 'alice',
        createdAt: now,
      );
      final shares = [
        SplitShare(id: 's1', expenseId: 'exp1', memberId: 'alice', shareAmount: 100.0),
        SplitShare(id: 's2', expenseId: 'exp1', memberId: 'bob', shareAmount: 100.0),
      ];

      // Bob settled 40 to Alice
      final settlement = Settlement(
        id: 'sett1',
        groupId: 'g1',
        fromMemberId: 'bob',
        toMemberId: 'alice',
        amount: 40.0,
        settledAt: now,
      );

      final directDebts = calculateDirectDebts(
        expenses: [exp],
        shares: shares,
        settlements: [settlement],
      );

      expect(directDebts.length, 1);
      expect(directDebts.first.fromMemberId, 'bob');
      expect(directDebts.first.toMemberId, 'alice');
      expect(directDebts.first.amount, 60.0);
    });
  });
}
