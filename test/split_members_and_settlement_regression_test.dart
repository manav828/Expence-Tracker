import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/models/split_models.dart';
import 'package:expense_tracker/providers/split_provider.dart';
import 'package:expense_tracker/screens/split/split_group_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Splitwise Members Tab & Combined Settlement Groups Regression Tests', () {
    late SplitProvider splitProvider;
    final now = DateTime.now();

    final group = SplitGroup(
      id: 'grp_goa_123',
      name: 'Goa Trip 2026',
      createdBy: 'Alex',
      inviteCode: 'GOA2026',
      createdAt: now,
    );

    // 5 members total: 1 individual + 2 combined groups (2 members each)
    final me = SplitMember(id: 'm_alex', groupId: 'grp_goa_123', name: 'Alex', joinedAt: now);
    final bob = SplitMember(id: 'm_bob', groupId: 'grp_goa_123', name: 'Bob', joinedAt: now);
    final charlie = SplitMember(id: 'm_charlie', groupId: 'grp_goa_123', name: 'Charlie', joinedAt: now);
    final david = SplitMember(id: 'm_david', groupId: 'grp_goa_123', name: 'David', joinedAt: now);
    final eve = SplitMember(id: 'm_eve', groupId: 'grp_goa_123', name: 'Eve', joinedAt: now);

    final sg1 = SplitSettlementGroup(
      id: 'sg_couple_a',
      groupId: 'grp_goa_123',
      name: 'Couple A',
      memberIds: ['m_bob', 'm_charlie'],
      createdAt: now,
      updatedAt: now,
    );

    final sg2 = SplitSettlementGroup(
      id: 'sg_couple_b',
      groupId: 'grp_goa_123',
      name: 'Couple B',
      memberIds: ['m_david', 'm_eve'],
      createdAt: now,
      updatedAt: now,
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'split_simplify_debts_grp_goa_123': true,
      });
      splitProvider = SplitProvider();
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        home: ChangeNotifierProvider<SplitProvider>.value(
          value: splitProvider,
          child: SplitGroupDetailScreen(group: group),
        ),
      );
    }

    testWidgets('Members Tab displays settlement groups WITH their 2 members each and individual creator', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      splitProvider.setGroupDetailForTesting(
        groupId: 'grp_goa_123',
        members: [me, bob, charlie, david, eve],
        settlementGroups: [sg1, sg2],
        balances: {'m_alex': 400.0, 'm_bob': -100.0, 'm_charlie': -100.0, 'm_david': -100.0, 'm_eve': -100.0},
      );
      await tester.pumpAndSettle();

      // Tap on Members Tab
      final membersTab = find.text('Members');
      expect(membersTab, findsOneWidget);
      await tester.tap(membersTab);
      await tester.pumpAndSettle();

      // 1. Verify Header counts
      expect(find.text('Trip Members (5)'), findsOneWidget);
      expect(find.text('Individual Members (1)'), findsOneWidget);
      expect(find.text('Groups & Combinations (2)'), findsOneWidget);

      // 2. Verify Individual Member is visible
      expect(find.text('Alex'), findsOneWidget);

      // 3. Verify Group 1 header and member names are visible
      expect(find.text('Couple A'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);

      // 4. Verify Group 2 header and member names are visible
      expect(find.text('Couple B'), findsOneWidget);
      expect(find.text('David'), findsOneWidget);
      expect(find.text('Eve'), findsOneWidget);

      // 5. Verify member counts in pills: (2) for each group
      expect(find.text('(2)'), findsNWidgets(2));
    });

    testWidgets('Self-Healing: if member was missing from map, group still displays fallback members instead of (0)', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Simulate a case where members list was partially missing from cloud, but settlement group has member IDs
      splitProvider.setGroupDetailForTesting(
        groupId: 'grp_goa_123',
        members: [me], // only creator returned
        settlementGroups: [sg1], // has m_bob, m_charlie
      );
      await tester.pumpAndSettle();

      // Tap on Members Tab
      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();

      // Verify group header is displayed with count (2), NOT (0)!
      expect(find.text('Couple A'), findsOneWidget);
      expect(find.text('(2)'), findsOneWidget);
      expect(find.text('(0)'), findsNothing);
    });

    testWidgets('Balances Tab does NOT show "All settled up!" when debts exist', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final exp = SplitExpense(
        id: 'e1',
        groupId: 'grp_goa_123',
        title: 'Dinner',
        totalAmount: 500.0,
        paidByMemberId: 'm_alex',
        splitType: SplitType.equal,
        addedByMemberId: 'm_alex',
        createdAt: now,
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      splitProvider.setGroupDetailForTesting(
        groupId: 'grp_goa_123',
        members: [me, bob, charlie, david, eve],
        settlementGroups: [sg1, sg2],
        expenses: [exp],
        balances: {'m_alex': 400.0, 'm_bob': -100.0, 'm_charlie': -100.0, 'm_david': -100.0, 'm_eve': -100.0},
      );
      await tester.pumpAndSettle();

      // Ensure "All settled up!" is NOT shown
      expect(find.text('All settled up! 🎉'), findsNothing);
      expect(find.text('No expenses yet'), findsNothing);
      expect(find.text('Who Owes Whom (Simplified)'), findsOneWidget);
    });
  });
}
