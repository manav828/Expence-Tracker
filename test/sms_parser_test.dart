import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/sms_parser.dart';

void main() {
  group('SmsParser Tests', () {
    test('Correctly parses HDFC Salary SMS with deposited amount and company name', () {
      const sms = 'Update! INR 30,185.00 deposited in HDFC Bank A/c XX8401 on 07-SEP-26 for A2AINT01 - ONPRINTSHOP SOFTWARE PRIVATE LIMITED - Salary - SALARY AUG 2026.Avl bal INR 30,810.89. Cheque deposits in A/C are subject to clearing';

      final result = SmsParser.parse(sms);

      expect(result, isNotNull);
      expect(result!.amount, 30185.00);
      expect(result.bank, 'HDFC');
      expect(result.paymentMethod, 'Transfer');
      expect(result.category, 'Salary');
      expect(result.isExpense, false);
      expect(result.payee.contains('ONPRINTSHOP SOFTWARE'), true);
    });

    test('Correctly parses HDFC Card transaction', () {
      const sms = '''Txn Rs.20.00
On HDFC Bank Card 6706
At paytm-7289005034@ptys 
by UPI 125529188357
On 30-06''';

      final result = SmsParser.parse(sms);

      expect(result, isNotNull);
      expect(result!.amount, 20.00);
      expect(result.bank, 'HDFC');
      expect(result.paymentMethod, 'Card');
      expect(result.isExpense, true);
    });

    test('Correctly parses SBI Debit transaction', () {
      const sms = 'Dear SBI UPI user A/C X1412 debited by 1000.00 on date 30Mar26 trf to MUTUAL FUNDS ICC Refno 645596222024';

      final result = SmsParser.parse(sms);

      expect(result, isNotNull);
      expect(result!.amount, 1000.00);
      expect(result.bank, 'SBI');
      expect(result.category, 'Investment');
      expect(result.isExpense, true);
    });

    test('Correctly parses HDFC UPI transfer to merchant', () {
      const sms = '''Sent Rs.80.00
From HDFC Bank A/C *8401
To dilipbhai ghughrwala
On 11/07/26
Ref 126100685141''';

      final result = SmsParser.parse(sms);

      expect(result, isNotNull);
      expect(result!.amount, 80.00);
      expect(result.bank, 'HDFC');
      expect(result.category, 'Food & Dining');
      expect(result.isExpense, true);
    });
  });
}
