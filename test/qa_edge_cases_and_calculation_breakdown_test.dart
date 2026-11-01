import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/budget.dart';
import 'package:expense_tracker/models/payment_reminder.dart';
import 'package:expense_tracker/models/split_models.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/services/data_export_service.dart';

void main() {
  group('1. Split Remainder & Floating-Point Division Stress Tests', () {
    test('Equal split distributes cents exactly for odd amounts & prime counts', () {
      final testCases = [
        {'total': 100.0, 'count': 3},
        {'total': 10.0, 'count': 7},
        {'total': 0.01, 'count': 3},
        {'total': 1000000.03, 'count': 11},
        {'total': 99.99, 'count': 6},
        {'total': 0.05, 'count': 4},
      ];

      for (final tc in testCases) {
        final total = tc['total'] as double;
        final count = tc['count'] as int;
        final totalCents = (total * 100).round();
        final baseCents = totalCents ~/ count;
        final remainderCents = totalCents % count;

        final shares = <double>[];
        for (var i = 0; i < count; i++) {
          final cents = baseCents + (i < remainderCents ? 1 : 0);
          shares.add(cents / 100.0);
        }

        // Sum in cents must match exactly
        final sumCents = shares.fold<int>(0, (sum, s) => sum + (s * 100).round());
        expect(sumCents, totalCents, reason: 'Failed for total $total and count $count');

        // Sum in doubles should match within 0.001
        final sumDouble = shares.fold<double>(0.0, (sum, s) => sum + s);
        expect((sumDouble - total).abs(), lessThan(0.001));
      }
    });

    test('Edge Case: Split ₹0.01 among 3 members leaves 2 members with ₹0.00', () {
      const total = 0.01;
      const count = 3;
      final totalCents = (total * 100).round(); // 1 cent
      final baseCents = totalCents ~/ count; // 0
      final remainderCents = totalCents % count; // 1

      final shares = <double>[];
      for (var i = 0; i < count; i++) {
        final cents = baseCents + (i < remainderCents ? 1 : 0);
        shares.add(cents / 100.0);
      }

      expect(shares, [0.01, 0.0, 0.0]);
      // Note: Member 2 and Member 3 participate in the split but owe 0.00!
    });

    test('Percentage split remainder distortion when percentages sum to 99.9% or 100.1%', () {
      const total = 100.0;
      final totalCents = (total * 100).round();

      // Case A: 33.3%, 33.3%, 33.3% = 99.9%
      final pctsA = [33.3, 33.3, 33.3];
      var allocatedA = 0;
      final sharesA = <double>[];
      for (var i = 0; i < 3; i++) {
        if (i == 2) {
          final cents = totalCents - allocatedA;
          sharesA.add(cents / 100.0);
        } else {
          final cents = (totalCents * (pctsA[i] / 100.0)).round();
          allocatedA += cents;
          sharesA.add(cents / 100.0);
        }
      }
      // Member 3 gets 33.40 even though they entered 33.3%
      expect(sharesA[0], 33.30);
      expect(sharesA[1], 33.30);
      expect(sharesA[2], 33.40); // 10 cents more!

      // Case B: Flaw if first member enters 110%
      final pctsB = [110.0, 10.0];
      var allocatedB = 0;
      final sharesB = <double>[];
      for (var i = 0; i < 2; i++) {
        if (i == 1) {
          final cents = totalCents - allocatedB;
          sharesB.add((cents > 0 ? cents : 0) / 100.0);
        } else {
          final cents = (totalCents * (pctsB[i] / 100.0)).round();
          allocatedB += cents;
          sharesB.add(cents / 100.0);
        }
      }
      expect(sharesB[0], 110.0);
      expect(sharesB[1], 0.0);
      final sumB = sharesB.reduce((a, b) => a + b);
      expect(sumB, 110.0); // Exceeds total by ₹10!
    });
  });

  group('2. Debt Simplification & Circular Ledger Math Tests', () {
    test('Circular debts (A->B ₹100, B->C ₹100, C->A ₹100) resolves to exactly 0 debts', () {
      // Net balances: A paid 100, consumed 100 = 0. B paid 100, consumed 100 = 0. C = 0.
      final balances = {'A': 0.0, 'B': 0.0, 'C': 0.0};
      final simplified = simplifyDebts(balances);
      expect(simplified, isEmpty);
    });

    test('Fractional debts under 0.005 are dropped, but 0.005-0.009 round up to 0.01 (Rounding Anomaly)', () {
      // Anomaly proof: 0.004 rounds to 0.00 and is dropped
      final balancesDropped = {'A': 0.004, 'B': -0.004};
      final simplifiedDropped = simplifyDebts(balancesDropped);
      expect(simplifiedDropped, isEmpty);

      // Anomaly proof: 0.008 rounds up to 0.01 and creates a phantom 1-paise debt
      final balancesPhantom = {'A': 0.008, 'B': -0.008};
      final simplifiedPhantom = simplifyDebts(balancesPhantom);
      expect(simplifiedPhantom, isNotEmpty);
      expect(simplifiedPhantom.first.amount, 0.01);
    });

    test('Unbalanced ledger sums (sum of all balances != 0) leads to unresolvable debts', () {
      // Corrupted state: someone inserted an expense without all shares
      final balances = {'A': 100.0, 'B': -60.0}; // missing -40
      final debts = simplifyDebts(balances);
      // Only 1 debt produced, leaving A with ₹40 uncollected phantom credit
      expect(debts.length, 1);
      expect(debts.first.amount, 60.0);
      expect(debts.first.fromMemberId, 'B');
      expect(debts.first.toMemberId, 'A');
    });

    test('calculateDirectDebts with settlement overpayment reverses who owes whom', () {
      final now = DateTime.now();
      // Expense: A paid ₹100 for B
      final exp = SplitExpense(
        id: 'e1',
        groupId: 'g1',
        title: 'Lunch',
        totalAmount: 100.0,
        paidByMemberId: 'A',
        splitType: SplitType.equal,
        addedByMemberId: 'A',
        createdAt: now,
      );
      final shares = [
        SplitShare(id: 's1', expenseId: 'e1', memberId: 'A', shareAmount: 0.0),
        SplitShare(id: 's2', expenseId: 'e1', memberId: 'B', shareAmount: 100.0),
      ];

      // Settlement: B pays A ₹150 (overpaid by ₹50)
      final settlements = [
        Settlement(
          id: 'set1',
          groupId: 'g1',
          fromMemberId: 'B',
          toMemberId: 'A',
          amount: 150.0,
          settledAt: now,
        ),
      ];

      final directDebts = calculateDirectDebts(
        expenses: [exp],
        shares: shares,
        settlements: settlements,
      );

      // Now A owes B ₹50!
      expect(directDebts.length, 1);
      expect(directDebts.first.fromMemberId, 'A');
      expect(directDebts.first.toMemberId, 'B');
      expect(directDebts.first.amount, 50.0);
    });
  });

  group('3. Financial Aggregation & Flaw Identification in ExpenseProvider', () {
    test('BUG IDENTIFIED: getExpensesForMonth returns BOTH expenses AND income', () {
      final provider = ExpenseProvider(autoFetch: false);
      final now = DateTime.now();

      final expense1 = Expense(
        id: 1,
        amount: 500.0,
        category: 'Food',
        paymentMethod: 'UPI',
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
        type: TransactionType.expense,
      );

      final income1 = Expense(
        id: 2,
        amount: 50000.0,
        category: 'Salary',
        paymentMethod: 'Transfer',
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
        type: TransactionType.income,
      );

      provider.setExpensesForTesting([expense1, income1]);

      // Method name is `getExpensesForMonth`
      final monthly = provider.getExpensesForMonth(now.year, now.month);

      // FIXED: It only includes expenses!
      expect(monthly.length, 1);
      expect(monthly.first.id, 1);
      expect(monthly.every((e) => e.isExpense), isTrue);

      // But getTotalExpensesForMonth correctly filters by isExpense:
      final totalExpenses = provider.getTotalExpensesForMonth(now.year, now.month);
      expect(totalExpenses, 500.0);
    });

    test('FIXED: getCategoryMonthlyTotals excludes income from expense category totals', () {
      final provider = ExpenseProvider(autoFetch: false);
      final now = DateTime.now();

      // Expense of 500 under "General"
      final exp = Expense(
        amount: 500.0,
        category: 'General',
        paymentMethod: 'Cash',
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
        type: TransactionType.expense,
      );

      // Income refund of 2000 under "General"
      final inc = Expense(
        amount: 2000.0,
        category: 'General',
        paymentMethod: 'Cash',
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
        type: TransactionType.income,
      );

      provider.setExpensesForTesting([exp, inc]);

      final categoryTotals = provider.getCategoryMonthlyTotals('General', now.year);
      // FIXED: Excludes income, returns only actual expenses!
      expect(categoryTotals[now.month], 500.0);
    });

    test('savingsRate returns 0.0 when income is 0 even if expenses are huge', () {
      final provider = ExpenseProvider(autoFetch: false);
      final now = DateTime.now();

      final exp = Expense(
        amount: 15000.0,
        category: 'Rent',
        paymentMethod: 'UPI',
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
        type: TransactionType.expense,
      );

      provider.setExpensesForTesting([exp]);

      // With 0 income and ₹15,000 expense, savings rate is 0.0%
      expect(provider.totalIncome, 0.0);
      expect(provider.netSavings, -15000.0);
      expect(provider.savingsRate, 0.0);
    });

    test('savingsRate clamps at 0.0% when expenses exceed income', () {
      final provider = ExpenseProvider(autoFetch: false);
      final now = DateTime.now();

      final inc = Expense(
        amount: 1000.0,
        category: 'Freelance',
        paymentMethod: 'UPI',
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
        type: TransactionType.income,
      );

      final exp = Expense(
        amount: 10000.0,
        category: 'Shopping',
        paymentMethod: 'Card',
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
        type: TransactionType.expense,
      );

      provider.setExpensesForTesting([inc, exp]);

      // Net savings = -9,000. Real savings rate is negative, clamped to 0.0%
      expect(provider.netSavings, -9000.0);
      expect(provider.savingsRate, 0.0);
    });
  });

  group('4. Payment Reminder Date Math & Edge Cases', () {
    test('Monthly reminder with due day 31 rolling into February clamps to 28 (or 29)', () {
      final reminder = PaymentReminder(
        id: 'r1',
        title: 'Gym',
        amount: 2000.0,
        category: 'Health & Wellness',
        paymentMethod: 'UPI',
        frequency: ReminderFrequency.monthly,
        dueDay: 31,
        nextDueDate: DateTime(2026, 1, 31),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      // Roll forward into February 2026 (non-leap year -> 28 days)
      final febDue = reminder.calculateNextCycleDate(DateTime(2026, 1, 31));
      expect(febDue.month, 2);
      expect(febDue.day, 28);

      // Roll forward from Feb into March -> should pick up dueDay 31 again
      final marDue = reminder.calculateNextCycleDate(febDue);
      expect(marDue.month, 3);
      expect(marDue.day, 31);

      // Roll forward from March into April (30 days) -> clamps to 30
      final aprDue = reminder.calculateNextCycleDate(marDue);
      expect(aprDue.month, 4);
      expect(aprDue.day, 30);
    });

    test('Leap year February 29 rolling forward in yearly frequency', () {
      final leapReminder = PaymentReminder(
        id: 'r2',
        title: 'Leap Year Insurance',
        amount: 5000.0,
        category: 'Bills & Utilities',
        paymentMethod: 'UPI',
        frequency: ReminderFrequency.yearly,
        dueDay: 29,
        nextDueDate: DateTime(2024, 2, 29), // 2024 is leap year
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      // 2025 is NOT a leap year -> clamps to Feb 28
      final nextYear = leapReminder.calculateNextCycleDate();
      expect(nextYear.year, 2025);
      expect(nextYear.month, 2);
      expect(nextYear.day, 28);
    });

    test('BUG IDENTIFIED: One-Time reminder calculateNextCycleDate returns the same past date', () {
      final pastDate = DateTime(2026, 5, 10);
      final oneTime = PaymentReminder(
        id: 'r3',
        title: 'Exam Fee',
        amount: 1500.0,
        category: 'General',
        paymentMethod: 'UPI',
        frequency: ReminderFrequency.oneTime,
        dueDate: pastDate,
        nextDueDate: pastDate,
        createdAt: pastDate,
        updatedAt: pastDate,
      );

      final next = oneTime.calculateNextCycleDate();
      expect(next, pastDate); // Never rolls forward
    });
  });

  group('5. Budget Limit Zero & Extreme Range Calculation Tests', () {
    test('Budget with monthlyLimit = 0 produces 100% progress when overspent', () {
      final budget = Budget(
        id: 1,
        category: 'Shopping',
        monthlyLimit: 0.0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      final now = DateTime.now();
      final expense = Expense(
        amount: 500.0,
        category: 'Shopping',
        paymentMethod: 'Card',
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
        type: TransactionType.expense,
      );

      final provider = BudgetProvider(autoFetch: false);
      final progress = provider.getProgressForBudget(budget, [expense]);

      expect(progress.spentThisMonth, 500.0);
      expect(progress.isOverspent, isTrue);
      // Fixed: when limit <= 0 and spent > 0, returns 100% (or progress 1.0)
      expect(progress.percentage, 100.0);
      expect(progress.progress, 1.0);
    });

    test('Extreme currency numbers ₹999,999,999 formatting & precision check', () {
      const hugeAmount = 999999999.99;
      final inrFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN');
      final formatted = inrFmt.format(hugeAmount);

      expect(formatted, contains('99,99,99,999.99'));
    });
  });

  group('6. Data Export Omission & CSV Formula Injection Flaws', () {
    test('FIXED: CSV and JSON export include transaction type and signed amounts', () {
      final now = DateTime.now();
      final income = Expense(
        id: 101,
        amount: 85000.0,
        category: 'Salary',
        paymentMethod: 'Bank',
        comment: 'Tech Corp Monthly Salary',
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
        type: TransactionType.income,
      );

      final csv = DataExportService.instance.generateCsv([income]);
      final json = DataExportService.instance.generateJson([income]);

      // CSV verification: Header has "Type" column
      expect(csv, contains('ID,Type,Date,Time,Category,Amount (INR),Payment Method,Note / Payee,Created Timestamp'));
      expect(csv, contains(',Income,'));
      expect(csv, contains('+85000.00'));

      // JSON verification: has 'type' and 'isExpense'
      expect(json, contains('"type": "income"'));
      expect(json, contains('"isExpense": false'));
      expect(json, contains('"amount": 85000.0'));
    });

    test('FIXED: CSV Formula Injection cannot bypass _escapeCsv even if preceded by whitespace', () {
      final exportService = DataExportService.instance;
      final now = DateTime.now();

      // Attacker enters a note starting with whitespace then '='
      final malicious = Expense(
        id: 102,
        amount: 10.0,
        category: 'General',
        paymentMethod: 'Cash',
        comment: ' =cmd|\' /C calc\'!A0', // starts with space!
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      );

      final csv = exportService.generateCsv([malicious]);

      // In data_export_service.dart: val.trimLeft() detects leading formula character,
      // so single quote prefix is applied
      expect(csv, contains("' =cmd"));
    });
  });
}
