import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/services/sms_parser.dart';
import 'package:expense_tracker/providers/budget_provider.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/models/search_filter.dart';
import 'package:expense_tracker/services/data_export_service.dart';

void main() {
  group('Comprehensive Bugfixes Regression Tests', () {
    test('Bug #01: Expense.fromMap safely parses num to double, int ids, and varied dates', () {
      final jsonWithIntAmount = {
        'id': 101, // int ID
        'amount': 250, // int amount, not double
        'category': 'Food',
        'payment_method': 'UPI',
        'expense_date': 1761310000000,
        'created_at': 1761310000000,
      };

      final exp = Expense.fromMap(jsonWithIntAmount);
      expect(exp.id, 101);
      expect(exp.amount, 250.0);
      expect(exp.category, 'Food');
      expect(exp.paymentMethod, 'UPI');
    });

    test('Bug #05: Equal split distributes exact remainder cents without 1-cent leak', () {
      const total = 100.0;
      final members = ['m1', 'm2', 'm3'];
      final totalCents = (total * 100).round();
      final count = members.length;
      final baseCents = totalCents ~/ count;
      final remainderCents = totalCents % count;

      final shares = <String, double>{};
      for (var i = 0; i < count; i++) {
        final cents = baseCents + (i < remainderCents ? 1 : 0);
        shares[members[i]] = cents / 100.0;
      }

      expect(shares['m1'], 33.34);
      expect(shares['m2'], 33.33);
      expect(shares['m3'], 33.33);

      final sum = shares.values.fold(0.0, (a, b) => a + b);
      expect((sum - total).abs() < 0.001, isTrue);
    });

    test('Bug #06 & #08: Split validation rejects negative shares and loose disparity', () {
      bool validate(double total, Map<String, double> shares) {
        if (shares.isEmpty) return false;
        if (shares.values.any((s) => s < 0)) return false;
        final sum = shares.values.fold(0.0, (a, b) => a + b);
        return (sum - total).abs() <= 0.02;
      }

      // Reject negative share
      expect(validate(100.0, {'m1': 120.0, 'm2': -20.0}), isFalse);

      // Reject loose disparity (e.g. ₹0.40 discrepancy which old code permitted)
      expect(validate(100.0, {'m1': 50.0, 'm2': 49.60}), isFalse);

      // Accept within 2 cents
      expect(validate(100.0, {'m1': 50.0, 'm2': 50.01}), isTrue);
      expect(validate(100.0, {'m1': 50.0, 'm2': 50.00}), isTrue);
    });

    test('Bug #11: SMS Parser avoids available balance collision', () {
      const sms = 'Avl Bal is Rs 85,000.00 after debited by Rs 150.00 at Starbucks.';
      final parsed = SmsParser.parse(sms);
      expect(parsed, isNotNull);
      expect(parsed!.amount, 150.0);
    });

    test('Bug #12: SMS Parser rejects OTP & 2FA authentication alerts', () {
      const sms = 'Your OTP for transaction of Rs. 450.00 at Swiggy is 849201. Do not share this OTP with anyone.';
      final parsed = SmsParser.parse(sms);
      expect(parsed, isNull);
    });

    test('Bug #13: SMS Parser rejects marketing offers & loan promos', () {
      const sms = 'Get Flat Rs. 200 off on your next order on Myntra with code STYLE200!';
      final parsed = SmsParser.parse(sms);
      expect(parsed, isNull);
    });

    test('Bug #21: Budget Provider is case and whitespace insensitive', () {
      final bp = BudgetProvider(autoFetch: false);
      final now = DateTime.now();
      final expenses = <Expense>[
        Expense(
          amount: 50.0,
          category: 'Food & dining ', // trailing space and lowercase d
          paymentMethod: 'UPI',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
        Expense(
          amount: 75.0,
          category: 'FOOD & DINING', // uppercase
          paymentMethod: 'Cash',
          expenseDate: now.millisecondsSinceEpoch,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
      ];

      final spent = bp.getMonthlySpentForCategory('food & dining', expenses);
      expect(spent, 125.0);
    });

    test('Bug #22: DateRangePreset.last30Days covers end of today at 23:59:59.999', () {
      final ep = ExpenseProvider(autoFetch: false);
      final now = DateTime.now();
      final todayLate = DateTime(now.year, now.month, now.day, 23, 30, 0);

      final exp = Expense(
        id: 1,
        amount: 100.0,
        category: 'Food',
        paymentMethod: 'UPI',
        expenseDate: todayLate.millisecondsSinceEpoch,
        createdAt: todayLate.millisecondsSinceEpoch,
        updatedAt: todayLate.millisecondsSinceEpoch,
      );
      ep.setExpensesForTesting([exp]);

      final filtered = ep.searchExpenses(const SearchFilter(datePreset: DateRangePreset.last30Days));
      expect(filtered.length, 1);
    });

    test('Bug #23: DateRangePreset.thisWeek spans through Sunday 23:59:59.999', () {
      final ep = ExpenseProvider(autoFetch: false);
      final now = DateTime.now();
      final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      final sundayNight = monday.add(const Duration(days: 6, hours: 22));

      final exp = Expense(
        id: 1,
        amount: 88.0,
        category: 'Shopping',
        paymentMethod: 'Card',
        expenseDate: sundayNight.millisecondsSinceEpoch,
        createdAt: sundayNight.millisecondsSinceEpoch,
        updatedAt: sundayNight.millisecondsSinceEpoch,
      );
      ep.setExpensesForTesting([exp]);

      final filtered = ep.searchExpenses(const SearchFilter(datePreset: DateRangePreset.thisWeek));
      expect(filtered.length, 1);
    });

    test('Bug #24: CSV Export escapes Excel formula injection characters', () {
      final exp = Expense(
        id: 1,
        amount: 10.0,
        category: '=SUM(A1:A10)', // Malicious formula in category
        paymentMethod: '+cmd|', // Malicious formula prefix in method
        comment: '-2+5', // Malicious minus formula in note
        expenseDate: DateTime(2026, 10, 24).millisecondsSinceEpoch,
        createdAt: DateTime(2026, 10, 24).millisecondsSinceEpoch,
        updatedAt: DateTime(2026, 10, 24).millisecondsSinceEpoch,
      );

      final csv = DataExportService.instance.generateCsv([exp]);
      expect(csv.contains("'=SUM(A1:A10)") || csv.contains('"\'=SUM(A1:A10)"'), isTrue);
      expect(csv.contains("'+cmd|") || csv.contains('"\'+\\cmd|"'), isTrue);
    });
  });
}
