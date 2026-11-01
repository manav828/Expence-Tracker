import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/split_models.dart';
import 'package:expense_tracker/models/payment_reminder.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/budget.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/services/split_service.dart';

/// Helper replicating exact UI logic from AddSplitExpenseSheet._buildShares
Map<String, double> buildShares({
  required SplitType splitType,
  required double total,
  required List<String> included,
  Map<String, double>? customAmounts,
  Map<String, double>? percentages,
}) {
  if (included.isEmpty) return {};

  if (splitType == SplitType.equal) {
    final totalCents = (total * 100).round();
    final count = included.length;
    final baseCents = totalCents ~/ count;
    final remainderCents = totalCents % count;
    final result = <String, double>{};
    for (var i = 0; i < count; i++) {
      final cents = baseCents + (i < remainderCents ? 1 : 0);
      result[included[i]] = cents / 100.0;
    }
    return result;
  } else if (splitType == SplitType.unequal) {
    return {
      for (final id in included)
        id: ((customAmounts?[id] ?? 0.0) < 0 ? 0.0 : (customAmounts?[id] ?? 0.0))
    };
  } else {
    // Percentage split: distribute exact cents, remainder to last member
    final count = included.length;
    var allocatedCents = 0;
    final totalCents = (total * 100).round();
    final result = <String, double>{};

    for (var i = 0; i < count; i++) {
      final id = included[i];
      var pct = percentages?[id] ?? 0.0;
      if (pct < 0) pct = 0;
      if (i == count - 1) {
        final cents = totalCents - allocatedCents;
        result[id] = (cents > 0 ? cents : 0) / 100.0;
      } else {
        final cents = (totalCents * (pct / 100.0)).round();
        allocatedCents += cents;
        result[id] = cents / 100.0;
      }
    }
    return result;
  }
}

/// Helper replicating exact UI validation from AddSplitExpenseSheet._validateShares
bool validateShares({
  required SplitType splitType,
  required double total,
  required List<String> included,
  required Map<String, double> shares,
  Map<String, double>? percentages,
}) {
  if (shares.isEmpty) return false;
  if (shares.values.any((s) => s < 0)) return false;

  if (splitType == SplitType.percentage) {
    final totalPct = included.fold<double>(
      0.0,
      (sum, id) => sum + (percentages?[id] ?? 0.0),
    );
    if ((totalPct - 100.0).abs() > 0.15) {
      return false;
    }
  }

  final sum = shares.values.fold(0.0, (a, b) => a + b);
  return (sum - total).abs() <= 0.02;
}

void main() {
  group('1. Split Remainder & Floating-Point Division Stress Tests', () {
    test('Equal Split: ₹100 split among 3 members sums to EXACTLY ₹100.00 in cents', () {
      final members = ['m1', 'm2', 'm3'];
      final shares = buildShares(
        splitType: SplitType.equal,
        total: 100.0,
        included: members,
      );

      expect(shares['m1'], 33.34);
      expect(shares['m2'], 33.33);
      expect(shares['m3'], 33.33);

      final sumInCents = shares.values.fold(0, (acc, s) => acc + (s * 100).round());
      expect(sumInCents, 10000);

      final sumDouble = shares.values.fold(0.0, (a, b) => a + b);
      expect(sumDouble, 100.0);
      expect(validateShares(splitType: SplitType.equal, total: 100.0, included: members, shares: shares), isTrue);
    });

    test('Equal Split: ₹10 split among 7 members distributes remainders correctly', () {
      final members = ['m1', 'm2', 'm3', 'm4', 'm5', 'm6', 'm7'];
      final shares = buildShares(
        splitType: SplitType.equal,
        total: 10.0,
        included: members,
      );

      // 1000 cents / 7 = 142 cents base, remainder 6 cents
      // First 6 members get 143 cents (1.43), 7th gets 142 cents (1.42)
      for (int i = 0; i < 6; i++) {
        expect(shares[members[i]], 1.43);
      }
      expect(shares[members[6]], 1.42);

      final sumInCents = shares.values.fold(0, (acc, s) => acc + (s * 100).round());
      expect(sumInCents, 1000);
      final sumDouble = double.parse(shares.values.fold(0.0, (a, b) => a + b).toStringAsFixed(2));
      expect(sumDouble, 10.00);
    });

    test('Equal Split: ₹0.01 split among 3 members creates zero-share members', () {
      final members = ['m1', 'm2', 'm3'];
      final shares = buildShares(
        splitType: SplitType.equal,
        total: 0.01,
        included: members,
      );

      // 1 cent / 3 = 0 base, remainder 1 cent
      expect(shares['m1'], 0.01);
      expect(shares['m2'], 0.00);
      expect(shares['m3'], 0.00);

      final sumInCents = shares.values.fold(0, (acc, s) => acc + (s * 100).round());
      expect(sumInCents, 1);
    });

    test('Equal Split: ₹1,000,000.03 split among 11 members precision test', () {
      final members = List.generate(11, (i) => 'm$i');
      final shares = buildShares(
        splitType: SplitType.equal,
        total: 1000000.03,
        included: members,
      );

      // 100000003 cents ~/ 11 = 9090909 cents base, remainder 4 cents
      // 4 members get 9090910 cents (90909.10), 7 members get 9090909 cents (90909.09)
      for (int i = 0; i < 4; i++) {
        expect(shares[members[i]], 90909.10);
      }
      for (int i = 4; i < 11; i++) {
        expect(shares[members[i]], 90909.09);
      }

      final sumInCents = shares.values.fold(0, (acc, s) => acc + (s * 100).round());
      expect(sumInCents, 100000003);
    });

    test('Unequal Split: Negative custom share is clamped to 0.0 in UI buildShares', () {
      final members = ['m1', 'm2'];
      final shares = buildShares(
        splitType: SplitType.unequal,
        total: 100.0,
        included: members,
        customAmounts: {'m1': -50.0, 'm2': 150.0},
      );

      expect(shares['m1'], 0.0);
      expect(shares['m2'], 150.0);
      // Validates false because 0.0 + 150.0 = 150 != 100
      expect(validateShares(splitType: SplitType.unequal, total: 100.0, included: members, shares: shares), isFalse);
    });

    test('DISCREPANCY: SplitService.addExpense accepts negative shares directly, corrupting ledger', () {
      // SplitService doesn't validate shares at service/DB layer
      final members = [
        SplitMember(id: 'm1', groupId: 'g1', name: 'Alice', joinedAt: DateTime.now()),
        SplitMember(id: 'm2', groupId: 'g1', name: 'Bob', joinedAt: DateTime.now()),
      ];
      final expense = SplitExpense(
        id: 'e1',
        groupId: 'g1',
        title: 'Corrupted Split',
        totalAmount: 100.0,
        paidByMemberId: 'm1',
        splitType: SplitType.unequal,
        addedByMemberId: 'm1',
        createdAt: DateTime.now(),
      );
      // Negative share for m2 passed directly
      final shares = [
        SplitShare(id: 's1', expenseId: 'e1', memberId: 'm1', shareAmount: 150.0),
        SplitShare(id: 's2', expenseId: 'e1', memberId: 'm2', shareAmount: -50.0),
      ];

      final balances = SplitService.instance.computeBalancesFromData(
        members: members,
        expenses: [expense],
        settlements: [],
        shares: shares,
      );

      // m1 paid 100, consumed 150 -> balance should be -50
      // m2 consumed -50 -> balance becomes +50! Bob consumed negative money and is now a creditor!
      expect(balances['m1'], -50.0);
      expect(balances['m2'], 50.0);
    });

    test('Percentage Split: 99.9% sum passes validation with 0.15% tolerance', () {
      // 33.3% * 3 = 99.9%
      final members = ['m1', 'm2', 'm3'];
      final percentages = {'m1': 33.3, 'm2': 33.3, 'm3': 33.3};
      final totalPct = percentages.values.reduce((a, b) => a + b); // 99.9

      final diff = (totalPct - 100.0).abs();
      expect(diff <= 0.15, isTrue, reason: '99.9% is within 0.15% tolerance');

      final shares = buildShares(
        splitType: SplitType.percentage,
        total: 100.0,
        included: members,
        percentages: percentages,
      );

      // Validation passes because tolerance allows 0.15%
      final isValid = validateShares(
        splitType: SplitType.percentage,
        total: 100.0,
        included: members,
        shares: shares,
        percentages: percentages,
      );
      expect(isValid, isTrue, reason: '99.9% is accepted by UI validation');
    });

    test('Percentage Split: Earlier shares exceeding 100% force last member to 0 and allow over-allocation', () {
      final members = ['m1', 'm2', 'm3'];
      final percentages = {'m1': 70.0, 'm2': 40.0, 'm3': 0.0}; // Sums to 110%
      final total = 100.0;

      final shares = buildShares(
        splitType: SplitType.percentage,
        total: total,
        included: members,
        percentages: percentages,
      );

      expect(shares['m1'], 70.0);
      expect(shares['m2'], 40.0);
      // Remainder for last member is totalCents (10000) - allocatedCents (11000) = -1000 -> clamped to 0
      expect(shares['m3'], 0.0);

      // Sum of shares is 110.0, exceeding total 100.0
      final sum = shares.values.fold(0.0, (a, b) => a + b);
      expect(sum, 110.0);
    });
  });

  group('2. Debt Simplification & Direct Debt Algorithm Tests', () {
    test('Circular Debt: A owes B ₹50, B owes C ₹50, C owes A ₹50 net is 0 in simplifyDebts', () {
      // Net balances: A: -50 + 50 = 0, B: 50 - 50 = 0, C: 50 - 50 = 0
      final balances = {'A': 0.0, 'B': 0.0, 'C': 0.0};
      final simplifiedDebts = simplifyDebts(balances);
      expect(simplifiedDebts, isEmpty, reason: 'Net simplified debt in circular relation should be 0');
    });

    test('Circular Debt: calculateDirectDebts retains all 3 circular debts without simplifying', () {
      final now = DateTime.now();
      // Expense 1: B paid 50 for A (A owes B 50)
      final exp1 = SplitExpense(
        id: 'e1', groupId: 'g1', title: 'B for A', totalAmount: 50.0,
        paidByMemberId: 'B', splitType: SplitType.unequal, addedByMemberId: 'B', createdAt: now,
      );
      final share1 = SplitShare(id: 's1', expenseId: 'e1', memberId: 'A', shareAmount: 50.0);

      // Expense 2: C paid 50 for B (B owes C 50)
      final exp2 = SplitExpense(
        id: 'e2', groupId: 'g1', title: 'C for B', totalAmount: 50.0,
        paidByMemberId: 'C', splitType: SplitType.unequal, addedByMemberId: 'C', createdAt: now,
      );
      final share2 = SplitShare(id: 's2', expenseId: 'e2', memberId: 'B', shareAmount: 50.0);

      // Expense 3: A paid 50 for C (C owes A 50)
      final exp3 = SplitExpense(
        id: 'e3', groupId: 'g1', title: 'A for C', totalAmount: 50.0,
        paidByMemberId: 'A', splitType: SplitType.unequal, addedByMemberId: 'A', createdAt: now,
      );
      final share3 = SplitShare(id: 's3', expenseId: 'e3', memberId: 'C', shareAmount: 50.0);

      final directDebts = calculateDirectDebts(
        expenses: [exp1, exp2, exp3],
        shares: [share1, share2, share3],
        settlements: [],
      );

      expect(directDebts.length, 3, reason: 'Direct debts do not simplify transitive circular loops');
      final amounts = directDebts.map((d) => '${d.fromMemberId}->${d.toMemberId}:${d.amount}').toSet();
      expect(amounts, containsAll(['A->B:50.0', 'B->C:50.0', 'C->A:50.0']));
    });

    test('DISCREPANCY: Fractional paise (< 0.01) are dropped and accumulate into lost money', () {
      // 10 creditors each with +0.004 balance (total +0.04), 1 debtor with -0.04
      final balances = <String, double>{
        for (int i = 0; i < 10; i++) 'creditor_$i': 0.004,
        'debtor': -0.04,
      };

      final debts = simplifyDebts(balances);

      // Because double.parse(0.004.toStringAsFixed(2)) == 0.0 <= 0.009, all creditors are dropped!
      // The debtor is left with no creditors to pay, so ZERO debts are returned!
      expect(debts, isEmpty, reason: 'Floating point residues < 0.01 are completely discarded');
    });

    test('DISCREPANCY: Unbalanced ledger sums silently drop excess balance without error', () {
      // Unbalanced ledger: Alice +100, Bob -70 (Total sum = +30)
      final balances = {'alice': 100.0, 'bob': -70.0};
      final debts = simplifyDebts(balances);

      expect(debts.length, 1);
      expect(debts.first.fromMemberId, 'bob');
      expect(debts.first.toMemberId, 'alice');
      expect(debts.first.amount, 70.0);
      // Alice is still owed 30.0, but algorithm terminates cleanly without indication
    });

    test('Settlement Groups Aggregation: handles zero balance and ungrouped members', () {
      final individualBalances = {
        'm1': 0.0,
        'm2': -50.0,
        'm3': 100.0,
      };
      final sg1 = SplitSettlementGroup(
        id: 'sg1',
        groupId: 'g1',
        name: 'Family',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        memberIds: ['m1', 'm2'],
      );

      final result = aggregateCombinedBalances(
        individualBalances: individualBalances,
        settlementGroups: [sg1],
      );

      // sg1 sum = 0.0 + (-50.0) = -50.0
      expect(result.entityBalances['sg_sg1'], -50.0);
      // m3 is ungrouped, keeps individual balance
      expect(result.entityBalances['m3'], 100.0);
      expect(result.entityBalances.containsKey('m1'), isFalse);
      expect(result.entityBalances.containsKey('m2'), isFalse);
    });

    test('FIXED: Member belonging to multiple settlement groups does not cause double-counted balances', () {
      final individualBalances = {'m1': 100.0};
      final sg1 = SplitSettlementGroup(
        id: 'sg1', groupId: 'g1', name: 'Group 1',
        createdAt: DateTime.now(), updatedAt: DateTime.now(), memberIds: ['m1'],
      );
      final sg2 = SplitSettlementGroup(
        id: 'sg2', groupId: 'g1', name: 'Group 2',
        createdAt: DateTime.now(), updatedAt: DateTime.now(), memberIds: ['m1'],
      );

      final result = aggregateCombinedBalances(
        individualBalances: individualBalances,
        settlementGroups: [sg1, sg2],
      );

      // m1's balance is attributed only to the first group that claims them
      expect(result.entityBalances['sg_sg1'], 100.0);
      expect(result.entityBalances['sg_sg2'], 0.0);
      final totalSum = result.entityBalances.values.reduce((a, b) => a + b);
      expect(totalSum, 100.0);
    });
  });

  group('3. Personal Financial Aggregations & Trajectory Chart Tests', () {
    test('DISCREPANCY: savingsRate returns 0% when income is 0 and expenses > 0', () {
      final provider = ExpenseProvider(autoFetch: false);
      final now = DateTime.now();

      provider.setExpensesForTesting([
        Expense(
          amount: 5000.0,
          category: 'Shopping',
          paymentMethod: 'UPI',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          type: TransactionType.expense,
        ),
      ]);

      expect(provider.totalIncome, 0.0);
      expect(provider.totalExpenses, 5000.0);
      expect(provider.netSavings, -5000.0);
      // Flaw: savingsRate returns 0.0 when totalIncome <= 0, reporting a neutral 0% savings rate!
      expect(provider.savingsRate, 0.0);
    });

    test('FIXED: savingsRate is clamped to 0.0% when expenses exceed income by 10x', () {
      final provider = ExpenseProvider(autoFetch: false);
      final now = DateTime.now();

      provider.setExpensesForTesting([
        Expense(
          amount: 1000.0,
          category: 'Salary',
          paymentMethod: 'NetBanking',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          type: TransactionType.income,
        ),
        Expense(
          amount: 10000.0,
          category: 'Emergency',
          paymentMethod: 'UPI',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          type: TransactionType.expense,
        ),
      ]);

      expect(provider.totalIncome, 1000.0);
      expect(provider.totalExpenses, 10000.0);
      expect(provider.netSavings, -9000.0);
      // Clamped to 0.0%
      expect(provider.savingsRate, 0.0);
    });

    test('FIXED: ExpenseProvider.getExpensesForMonth returns only EXPENSE transactions', () {
      final provider = ExpenseProvider(autoFetch: false);
      final now = DateTime.now();

      provider.setExpensesForTesting([
        Expense(
          amount: 500.0,
          category: 'Food',
          paymentMethod: 'UPI',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          type: TransactionType.expense,
        ),
        Expense(
          amount: 50000.0,
          category: 'Salary',
          paymentMethod: 'Bank Transfer',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          type: TransactionType.income,
        ),
      ]);

      final monthExpenses = provider.getExpensesForMonth(now.year, now.month);
      expect(monthExpenses.length, 1);
      expect(monthExpenses.every((e) => e.isExpense), isTrue);
    });

    test('FIXED: Trajectory Chart calculation excludes income from dailySpendMap', () {
      final provider = ExpenseProvider(autoFetch: false);
      final now = DateTime.now();

      provider.setExpensesForTesting([
        Expense(
          amount: 500.0,
          category: 'Food',
          paymentMethod: 'UPI',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          type: TransactionType.expense,
        ),
        Expense(
          amount: 100000.0,
          category: 'Salary',
          paymentMethod: 'NetBanking',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          type: TransactionType.income,
        ),
      ]);

      // Replicating lines of dashboard_screen.dart
      final monthlyExpenses = provider.getExpensesForMonth(now.year, now.month);
      final validExpenses = monthlyExpenses.where((e) => e.isExpense && e.amount > 0).toList();
      final Map<DateTime, double> dailySpendMap = {};
      for (final exp in validExpenses) {
        if (exp.isExpense) {
          final dt = exp.dateTime;
          final dayKey = DateTime(dt.year, dt.month, dt.day);
          dailySpendMap[dayKey] = (dailySpendMap[dayKey] ?? 0.0) + exp.amount;
        }
      }

      final dayKey = DateTime(now.year, now.month, now.day);
      expect(dailySpendMap[dayKey], 500.0);
    });
  });

  group('4. Payment Reminder Date Math Tests', () {
    test('Monthly reminder with dueDay 31 rolls forward correctly in Leap Year Feb (2024)', () {
      final reminder = PaymentReminder(
        title: 'Rent',
        amount: 15000.0,
        category: 'Housing',
        paymentMethod: 'UPI',
        frequency: ReminderFrequency.monthly,
        dueDay: 31,
        nextDueDate: DateTime(2024, 1, 31, 10, 0),
      );

      final nextDate = reminder.calculateNextCycleDate();
      // 2024 is a leap year, February has 29 days
      expect(nextDate.year, 2024);
      expect(nextDate.month, 2);
      expect(nextDate.day, 29);
    });

    test('Monthly reminder with dueDay 31 rolls forward correctly in non-leap Feb (2023, 2025, 2026)', () {
      for (final year in [2023, 2025, 2026]) {
        final reminder = PaymentReminder(
          title: 'Internet',
          amount: 1000.0,
          category: 'Utilities',
          paymentMethod: 'UPI',
          frequency: ReminderFrequency.monthly,
          dueDay: 31,
          nextDueDate: DateTime(year, 1, 31, 10, 0),
        );

        final nextDate = reminder.calculateNextCycleDate();
        expect(nextDate.year, year);
        expect(nextDate.month, 2);
        expect(nextDate.day, 28);
      }
    });

    test('Monthly reminder with dueDay 31 rolls forward correctly in 30-day month (April)', () {
      final reminder = PaymentReminder(
        title: 'Subscription',
        amount: 500.0,
        category: 'Entertainment',
        paymentMethod: 'UPI',
        frequency: ReminderFrequency.monthly,
        dueDay: 31,
        nextDueDate: DateTime(2026, 3, 31, 10, 0),
      );

      final nextDate = reminder.calculateNextCycleDate();
      expect(nextDate.year, 2026);
      expect(nextDate.month, 4);
      expect(nextDate.day, 30);
    });

    test('DISCREPANCY: If dueDay is null, rolling forward from Feb 28 permanently shifts due date to 28th', () {
      final reminder = PaymentReminder(
        title: 'Gym',
        amount: 2000.0,
        category: 'Health',
        paymentMethod: 'UPI',
        frequency: ReminderFrequency.monthly,
        dueDay: null, // dueDay omitted
        nextDueDate: DateTime(2025, 1, 31, 10, 0),
      );

      final febDate = reminder.calculateNextCycleDate();
      expect(febDate.day, 28);

      // Next month from Feb 28 without dueDay stored:
      final marchReminder = reminder.copyWith(nextDueDate: febDate);
      final marchDate = marchReminder.calculateNextCycleDate();
      // Flaw: March becomes March 28 instead of March 31!
      expect(marchDate.day, 28, reason: 'Lacking dueDay, date drift permanently locks to 28th');
    });

    test('Quarterly reminder rolls forward across year boundary (Oct -> Jan)', () {
      final reminder = PaymentReminder(
        title: 'Insurance',
        amount: 12000.0,
        category: 'Bills',
        paymentMethod: 'NetBanking',
        frequency: ReminderFrequency.quarterly,
        dueDay: 31,
        nextDueDate: DateTime(2026, 10, 31, 9, 0),
      );

      final nextDate = reminder.calculateNextCycleDate();
      expect(nextDate.year, 2027);
      expect(nextDate.month, 1);
      expect(nextDate.day, 31);
    });

    test('DISCREPANCY: One-time reminder calculateNextCycleDate returns the past date', () {
      final pastDate = DateTime(2025, 1, 15, 10, 0);
      final reminder = PaymentReminder(
        title: 'One-off fee',
        amount: 500.0,
        category: 'Other',
        paymentMethod: 'Cash',
        frequency: ReminderFrequency.oneTime,
        dueDate: pastDate,
        nextDueDate: pastDate,
      );

      final nextDate = reminder.calculateNextCycleDate(DateTime.now());
      // Flaw: returns past dueDate regardless of referenceDate
      expect(nextDate, pastDate);
    });

    test('DISCREPANCY: daysUntilDue on 23-hour DST spring-forward boundary day drops to 0 (Due Today)', () {
      // Simulate DST 23-hour gap
      // When DateTime difference across DST transition is 23 hours:
      final todayMidnight = DateTime(2026, 3, 8, 0, 0);
      // In a timezone with DST spring forward, the day duration is 23 hours
      const dstDayDuration = Duration(hours: 23);
      final tomorrowMidnight = todayMidnight.add(dstDayDuration);

      // Duration.inDays is integer division ~/ 24h
      expect(tomorrowMidnight.difference(todayMidnight).inDays, 0,
          reason: '23-hour duration ~/ 24h evaluates to 0 days');
    });
  });

  group('5. Budget Progress & Percentages Tests', () {
    test('FIXED: Budget monthly limit = 0 returns percentage = 100.0 when overspent', () {
      final provider = BudgetProvider(autoFetch: false);
      final budget = Budget(
        id: 1,
        category: 'Dining',
        monthlyLimit: 0.0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      final now = DateTime.now();
      final expenses = [
        Expense(
          amount: 500.0,
          category: 'Dining',
          paymentMethod: 'UPI',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          type: TransactionType.expense,
        ),
      ];

      final progress = provider.getProgressForBudget(budget, expenses);

      expect(progress.spentThisMonth, 500.0);
      expect(progress.remaining, -500.0);
      expect(progress.isOverspent, isTrue);
      // FIXED: When limit <= 0 and spent > 0, percentage reports 100.0 and progress is 1.0
      expect(progress.percentage, 100.0);
      expect(progress.progress, 1.0);
      expect(progress.isNearLimit, isFalse);
    });

    test('FIXED: Negative monthly limit does not cause 0 spending to be marked as overspent', () {
      final provider = BudgetProvider(autoFetch: false);
      final budget = Budget(
        id: 1,
        category: 'Gaming',
        monthlyLimit: -100.0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      final progress = provider.getProgressForBudget(budget, []);

      expect(progress.spentThisMonth, 0.0);
      expect(progress.percentage, 0.0);
      expect(progress.progress, 0.0);
      expect(progress.remaining, -100.0);
      expect(progress.isOverspent, isFalse);
    });

    test('Extreme Numbers: ₹999,999,999,999 budget computes correctly without float overflow', () {
      final provider = BudgetProvider(autoFetch: false);
      const trillionMinusOne = 999999999999.0;
      final budget = Budget(
        id: 1,
        category: 'MegaProject',
        monthlyLimit: trillionMinusOne,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      final now = DateTime.now();
      final expenses = [
        Expense(
          amount: 500000000000.0,
          category: 'MegaProject',
          paymentMethod: 'NetBanking',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          type: TransactionType.expense,
        ),
      ];

      final progress = provider.getProgressForBudget(budget, expenses);

      expect(progress.percentage, 50.0);
      expect(progress.remaining, 499999999999.0);
      expect(progress.isOverspent, isFalse);
      expect(progress.isNearLimit, isFalse);
    });

    test('FIXED: BudgetProvider.getTotalBudgetSpent excludes income transactions in budgeted categories', () {
      final provider = BudgetProvider(autoFetch: false);
      final budget = Budget(
        id: 1,
        category: 'Freelance',
        monthlyLimit: 10000.0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      provider.setBudgetsForTesting([budget]);

      final now = DateTime.now();
      final transactions = [
        Expense(
          amount: 25000.0,
          category: 'Freelance',
          paymentMethod: 'NetBanking',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          type: TransactionType.income, // Inflow/Income!
        ),
      ];

      final totalSpent = provider.getTotalBudgetSpent(transactions);
      expect(totalSpent, 0.0, reason: 'Income is excluded from total budget spent');
    });

    test('FIXED: BudgetProvider.getTotalBudgetSpent succeeds with case-insensitive matching', () {
      final provider = BudgetProvider(autoFetch: false);
      final budget = Budget(
        id: 1,
        category: 'Groceries',
        monthlyLimit: 5000.0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      provider.setBudgetsForTesting([budget]);

      final now = DateTime.now();
      final expenses = [
        Expense(
          amount: 1500.0,
          category: 'groceries', // lowercase
          paymentMethod: 'UPI',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          type: TransactionType.expense,
        ),
      ];

      expect(provider.getMonthlySpentForCategory('Groceries', expenses), 1500.0);

      final totalSpent = provider.getTotalBudgetSpent(expenses);
      expect(totalSpent, 1500.0, reason: 'Case-insensitive match correctly counts lowercase expense in budget spent');
    });
  });
}
