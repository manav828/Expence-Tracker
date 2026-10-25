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

    test('Bug #11: Correctly parses debited amount when available balance is mentioned first', () {
      const sms = 'Avl Bal is Rs 85,000.00 after debited by Rs 150.00 at Starbucks.';
      final result = SmsParser.parse(sms);
      expect(result, isNotNull);
      expect(result!.amount, 150.00);
      expect(result.isExpense, true);
    });

    test('Bug #12: Rejects OTP and 2FA authentication SMS', () {
      const sms1 = 'Your OTP for transaction of Rs. 450.00 at Swiggy is 849201. Do not share this OTP with anyone.';
      final result1 = SmsParser.parse(sms1);
      expect(result1, isNull);

      const sms2 = 'Use 948102 as your secret code for ICICI Netbanking. Valid for 5 mins.';
      final result2 = SmsParser.parse(sms2);
      expect(result2, isNull);
    });

    test('Bug #13: Rejects marketing and promotional offer SMS', () {
      const sms1 = 'Get Flat Rs. 200 off on your next order on Myntra with code STYLE200!';
      final result1 = SmsParser.parse(sms1);
      expect(result1, isNull);

      const sms2 = 'Pre-approved personal loan of Rs 5,00,000 available at 10.5% interest. Apply now!';
      final result2 = SmsParser.parse(sms2);
      expect(result2, isNull);
    });
  });
}
