import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/split_models.dart';

void main() {
  group('Combined Settlement & Member Groups Pure Math Tests', () {
    test('PRD Scenario 3: Husband owes ₹2000, wife owes ₹1500 => Combined balance ₹3500 owed', () {
      final individualBalances = {
        'husband': -2000.0,
        'wife': -1500.0,
        'friend': 3500.0,
      };

      final familyGroup = SplitSettlementGroup(
        id: 'fam_1',
        groupId: 'grp_1',
        name: "Dinesh Sir's Family",
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        memberIds: ['husband', 'wife'],
      );

      final aggregated = aggregateCombinedBalances(
        individualBalances: individualBalances,
        settlementGroups: [familyGroup],
      );

      expect(aggregated.getGroupBalance('fam_1'), -3500.0);
      expect(aggregated.entityBalances['friend'], 3500.0);

      final debts = simplifyDebtsWithGroups(
        individualBalances: individualBalances,
        settlementGroups: [familyGroup],
      );

      expect(debts.length, 1);
      expect(debts.first.fromSettlementGroupId, 'fam_1');
      expect(debts.first.fromGroupName, "Dinesh Sir's Family");
      expect(debts.first.toMemberId, 'friend');
      expect(debts.first.amount, 3500.0);
    });

    test('PRD Scenario 4: Husband owes ₹2000, wife receives ₹1000 => Combined balance ₹1000 owed', () {
      final individualBalances = {
        'husband': -2000.0,
        'wife': 1000.0,
        'other': 1000.0,
      };

      final familyGroup = SplitSettlementGroup(
        id: 'fam_1',
        groupId: 'grp_1',
        name: "Family Group",
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        memberIds: ['husband', 'wife'],
      );

      final aggregated = aggregateCombinedBalances(
        individualBalances: individualBalances,
        settlementGroups: [familyGroup],
      );

      expect(aggregated.getGroupBalance('fam_1'), -1000.0);

      final debts = simplifyDebtsWithGroups(
        individualBalances: individualBalances,
        settlementGroups: [familyGroup],
      );

      expect(debts.length, 1);
      expect(debts.first.fromSettlementGroupId, 'fam_1');
      expect(debts.first.toMemberId, 'other');
      expect(debts.first.amount, 1000.0);
    });

    test('PRD Scenario 5: Husband receives ₹2000, wife owes ₹2000 => Combined balance zero (no debt generated)', () {
      final individualBalances = {
        'husband': 2000.0,
        'wife': -2000.0,
        'third_person': 0.0,
      };

      final familyGroup = SplitSettlementGroup(
        id: 'fam_1',
        groupId: 'grp_1',
        name: "Zero Balance Family",
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        memberIds: ['husband', 'wife'],
      );

      final aggregated = aggregateCombinedBalances(
        individualBalances: individualBalances,
        settlementGroups: [familyGroup],
      );

      expect(aggregated.getGroupBalance('fam_1'), 0.0);

      final debts = simplifyDebtsWithGroups(
        individualBalances: individualBalances,
        settlementGroups: [familyGroup],
      );

      expect(debts, isEmpty);
    });

    test('PRD Section 5 Core Example: Trip with 5 members and 1 family group', () {
      final individualBalances = {
        'manav': -1000.0,
        'pooja': 5000.0,
        'dinesh': -2000.0,
        'dinesh_wife': -1500.0,
        'kirti': -500.0,
      };

      final dineshFamily = SplitSettlementGroup(
        id: 'fam_dinesh',
        groupId: 'trip_1',
        name: "Dinesh Sir's Family",
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        memberIds: ['dinesh', 'dinesh_wife'],
      );

      final debts = simplifyDebtsWithGroups(
        individualBalances: individualBalances,
        settlementGroups: [dineshFamily],
      );

      expect(debts.length, 3);

      final familyDebt = debts.firstWhere((d) => d.fromSettlementGroupId == 'fam_dinesh');
      expect(familyDebt.amount, 3500.0);
      expect(familyDebt.toMemberId, 'pooja');
      expect(familyDebt.fromGroupName, "Dinesh Sir's Family");

      final manavDebt = debts.firstWhere((d) => d.fromMemberId == 'manav');
      expect(manavDebt.amount, 1000.0);
      expect(manavDebt.toMemberId, 'pooja');

      final kirtiDebt = debts.firstWhere((d) => d.fromMemberId == 'kirti');
      expect(kirtiDebt.amount, 500.0);
      expect(kirtiDebt.toMemberId, 'pooja');
    });

    test('PRD Scenario 6: Partial settlement reduces combined group balance correctly', () {
      // Initially Dinesh Sir: -2000, Wife: -1500, Pooja: +3500
      // Dinesh Sir makes a partial payment of ₹2000 to Pooja on behalf of the family
      // After payment:
      // Dinesh Sir net balance: -2000 + 2000 = 0.0
      // Wife net balance: -1500.0
      // Pooja net balance: 3500 - 2000 = +1500.0
      final updatedBalances = {
        'dinesh': 0.0,
        'dinesh_wife': -1500.0,
        'pooja': 1500.0,
      };

      final dineshFamily = SplitSettlementGroup(
        id: 'fam_dinesh',
        groupId: 'trip_1',
        name: "Dinesh Sir's Family",
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        memberIds: ['dinesh', 'dinesh_wife'],
      );

      final aggregated = aggregateCombinedBalances(
        individualBalances: updatedBalances,
        settlementGroups: [dineshFamily],
      );

      expect(aggregated.getGroupBalance('fam_dinesh'), -1500.0);

      final debts = simplifyDebtsWithGroups(
        individualBalances: updatedBalances,
        settlementGroups: [dineshFamily],
      );

      expect(debts.length, 1);
      expect(debts.first.fromSettlementGroupId, 'fam_dinesh');
      expect(debts.first.toMemberId, 'pooja');
      expect(debts.first.amount, 1500.0);
    });

    test('PRD Scenario 7: Removing settlement link restores individual settlement balances', () {
      final individualBalances = {
        'dinesh': -2000.0,
        'dinesh_wife': -1500.0,
        'pooja': 3500.0,
      };

      // When settlementGroups list is empty (link removed)
      final debts = simplifyDebtsWithGroups(
        individualBalances: individualBalances,
        settlementGroups: [],
      );

      expect(debts.length, 2);
      expect(debts.any((d) => d.fromMemberId == 'dinesh' && d.amount == 2000.0 && d.toMemberId == 'pooja'), isTrue);
      expect(debts.any((d) => d.fromMemberId == 'dinesh_wife' && d.amount == 1500.0 && d.toMemberId == 'pooja'), isTrue);
    });
  });
}
