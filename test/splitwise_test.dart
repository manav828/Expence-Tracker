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
        addedByMemberId: 'm-2',
        createdAt: now,
      );

      final expMap = expense.toMap();
      expect(expMap['split_type'], 'equal');
      expect(expMap['added_by_member_id'], 'm-2');

      final restoredExp = SplitExpense.fromMap(expMap);
      expect(restoredExp.title, 'Dinner at Beach');
      expect(restoredExp.totalAmount, 1500.0);
      expect(restoredExp.splitType, SplitType.equal);
    });
  });
}
