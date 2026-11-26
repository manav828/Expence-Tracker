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
      expect(find.text('ALL MEMBERS & GROUPS'), findsOneWidget);
      expect(find.text('All Members (5)'), findsOneWidget);
      expect(find.text('Combined (2)'), findsOneWidget);

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
      final exp2 = SplitExpense(
        id: 'e2',
        groupId: 'grp_goa_123',
        title: 'Snacks',
        totalAmount: 100.0,
        paidByMemberId: 'm_bob',
        splitType: SplitType.equal,
        addedByMemberId: 'm_bob',
        createdAt: now,
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      splitProvider.setGroupDetailForTesting(
        groupId: 'grp_goa_123',
        members: [me, bob, charlie, david, eve],
        settlementGroups: [sg1, sg2],
        expenses: [exp, exp2],
        balances: {'m_alex': 100.0, 'm_bob': 200.0, 'm_charlie': 0.0, 'm_david': -150.0, 'm_eve': -150.0},
      );
      await tester.pumpAndSettle();

      // Tap on Settle Tab in CheQ Bottom Nav Bar
      final settleTab = find.text('Settle');
      expect(settleTab, findsOneWidget);
      await tester.tap(settleTab);
      await tester.pumpAndSettle();

      // Ensure "All settled up!" is NOT shown
      expect(find.text('All settled up! 🎉'), findsNothing);
      expect(find.text('No expenses yet'), findsNothing);
      expect(find.text('Who Owes Whom (Simplified)'), findsOneWidget);

      // Verify NET BALANCES heading (without "Individual")
      expect(find.text('NET BALANCES'), findsOneWidget);
      expect(find.text('INDIVIDUAL NET BALANCES'), findsNothing);
      expect(find.text('View Ledger'), findsOneWidget);

      // Verify groups are embedded in NET BALANCES
      expect(find.text('Couple A'), findsOneWidget);
      expect(find.text('Couple B'), findsOneWidget);
      expect(find.text('Family • 2 members'), findsNWidgets(2));
    });

    testWidgets('Settlement History displays with redesigned card matching reference image', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final s1 = Settlement(
        id: 's_1',
        groupId: 'grp_goa_123',
        fromMemberId: 'm_bob',
        toMemberId: 'm_alex',
        amount: 500.0,
        settledAt: DateTime.now().subtract(const Duration(days: 1)),
        note: 'Settled via UPI',
      );

      final s2 = Settlement(
        id: 's_2',
        groupId: 'grp_goa_123',
        fromMemberId: 'm_charlie',
        toMemberId: 'm_david',
        amount: 120.0,
        settledAt: DateTime.now().subtract(const Duration(days: 2)),
        note: 'Cash payment',
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      splitProvider.setGroupDetailForTesting(
        groupId: 'grp_goa_123',
        members: [me, bob, charlie, david, eve],
        settlementGroups: [],
        settlements: [s1, s2],
      );
      await tester.pumpAndSettle();

      // Tap on Settle Tab
      await tester.tap(find.text('Settle'));
      await tester.pumpAndSettle();

      // Verify Settlement History header
      expect(find.text('SETTLEMENT HISTORY'), findsOneWidget);
      expect(find.text('2 Settled'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);

      // Verify rows
      expect(find.text('Settled via UPI'), findsOneWidget);
      expect(find.text('Settled • Cash'), findsOneWidget);
      expect(find.text('₹500.00'), findsOneWidget);
      expect(find.text('₹120.00'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_outlined), findsAtLeastNWidgets(2));
    });

    testWidgets('Members Tab top card shows minimal header, Add Member & Group QR only, and no avatar stack', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      splitProvider.setGroupDetailForTesting(
        groupId: 'grp_goa_123',
        members: [me, bob, charlie],
        settlementGroups: [],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();

      expect(find.text('Goa Trip 2026'), findsAtLeastNWidgets(1));
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').startsWith('Created on ') && (w.data ?? '').endsWith(' • Active'),
        ),
        findsOneWidget,
      );
      expect(find.text('Add Member'), findsAtLeastNWidgets(1));
      expect(find.text('Group QR'), findsOneWidget);

      // Removed elements from top card
      expect(find.text('Share Link'), findsNothing);
      expect(find.text('Active Group'), findsNothing);
      expect(find.text('Good friends, shared moments'), findsNothing);
      expect(find.textContaining('members across'), findsNothing);
    });

    testWidgets('Settle Tab replaces Request via UPI with Remind and does not copy reminder to clipboard', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final exp = SplitExpense(
        id: 'e1',
        groupId: 'grp_goa_123',
        title: 'Hotel',
        totalAmount: 1000.0,
        paidByMemberId: 'm_alex',
        splitType: SplitType.equal,
        addedByMemberId: 'm_alex',
        createdAt: now,
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      splitProvider.setGroupDetailForTesting(
        groupId: 'grp_goa_123',
        members: [me, bob],
        settlementGroups: [],
        expenses: [exp],
        balances: {'m_alex': 500.0, 'm_bob': -500.0},
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settle'));
      await tester.pumpAndSettle();

      expect(find.text('Request via UPI'), findsNothing);
      expect(find.text('Remind'), findsOneWidget);

      await tester.tap(find.text('Remind'));
      await tester.pumpAndSettle();

      expect(find.textContaining('copied to clipboard'), findsNothing);
      expect(
        find.text('Bob has not joined with an app account yet.'),
        findsOneWidget,
      );
    });
  });
}
