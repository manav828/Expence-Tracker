import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/models/split_models.dart';
import 'package:expense_tracker/providers/split_provider.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/widgets/add_expense_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trip Mode Tests', () {
    late SplitProvider splitProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      splitProvider = SplitProvider();
    });

    test('enableTripMode and disableTripMode update state and prefs', () async {
      final group = SplitGroup(
        id: 'group_trip_1',
        name: 'Goa Trip 2026',
        createdBy: 'Manav',
        inviteCode: 'GOA123',
        createdAt: DateTime.now(),
      );

      splitProvider.setGroupDetailForTesting(
        groupId: group.id,
        groups: [group],
        members: [
          SplitMember(id: 'm1', groupId: group.id, name: 'Manav', joinedAt: DateTime.now()),
          SplitMember(id: 'm2', groupId: group.id, name: 'Friend 1', joinedAt: DateTime.now()),
        ],
        settlementGroups: [],
        expenses: [],
        settlements: [],
        balances: {'m1': 0.0, 'm2': 0.0},
      );

      // Initially inactive
      expect(splitProvider.isTripModeActive, false);
      expect(splitProvider.activeTripGroup, null);

      // Enable Trip Mode
      await splitProvider.enableTripMode(group.id);
      expect(splitProvider.activeTripGroupId, 'group_trip_1');
      expect(splitProvider.isTripModeActive, true);
      expect(splitProvider.activeTripGroup?.name, 'Goa Trip 2026');

      // Disable Trip Mode
      await splitProvider.disableTripMode();
      expect(splitProvider.activeTripGroupId, null);
      expect(splitProvider.isTripModeActive, false);
    });

    test('calculateUserNetShare accurately computes user share', () async {
      final group = SplitGroup(
        id: 'group_trip_2',
        name: 'Manali Expedition',
        createdBy: 'Manav',
        inviteCode: 'MNL456',
        createdAt: DateTime.now(),
      );

      final members = [
        SplitMember(id: 'm1', groupId: group.id, name: 'Manav', joinedAt: DateTime.now()),
        SplitMember(id: 'm2', groupId: group.id, name: 'Rohan', joinedAt: DateTime.now()),
      ];

      final expenses = [
        SplitExpense(
          id: 'exp1',
          groupId: group.id,
          title: 'Hotel Stay',
          totalAmount: 4000.0,
          paidByMemberId: 'm1',
          splitType: SplitType.equal,
          addedByMemberId: 'm1',
          createdAt: DateTime.now(),
        ),
        SplitExpense(
          id: 'exp2',
          groupId: group.id,
          title: 'River Rafting',
          totalAmount: 2000.0,
          paidByMemberId: 'm2',
          splitType: SplitType.equal,
          addedByMemberId: 'm2',
          createdAt: DateTime.now(),
        ),
      ];

      splitProvider.setGroupDetailForTesting(
        groupId: group.id,
        groups: [group],
        members: members,
        settlementGroups: [],
        expenses: expenses,
        settlements: [],
        balances: {'m1': 1000.0, 'm2': -1000.0},
      );
      await splitProvider.setCurrentMemberName('Manav');

      // Total group spend is 6000. For 2 members split equally, each member's share is 3000.
      final userShare = splitProvider.calculateUserNetShare(group.id);
      expect(userShare, equals(3000.0));
    });

    testWidgets('AddExpenseSheet renders Trip Mode card when Trip Mode is active', (tester) async {
      final group = SplitGroup(
        id: 'group_trip_ui',
        name: 'Ujjain Trip',
        createdBy: 'Manav',
        inviteCode: 'UJJ789',
        createdAt: DateTime.now(),
      );

      splitProvider.setGroupDetailForTesting(
        groupId: group.id,
        groups: [group],
        members: [
          SplitMember(id: 'm1', groupId: group.id, name: 'Manav', joinedAt: DateTime.now()),
          SplitMember(id: 'm2', groupId: group.id, name: 'Dinesh', joinedAt: DateTime.now()),
        ],
        settlementGroups: [],
        expenses: [],
        settlements: [],
        balances: {},
      );
      await splitProvider.enableTripMode(group.id);

      final expenseProvider = ExpenseProvider();
      final budgetProvider = BudgetProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SplitProvider>.value(value: splitProvider),
            ChangeNotifierProvider<ExpenseProvider>.value(value: expenseProvider),
            ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AddExpenseSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Trip Mode banner is displayed
      expect(find.text('Trip Mode: Ujjain Trip'), findsOneWidget);
      expect(find.text('SPLIT'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });
  });
}
