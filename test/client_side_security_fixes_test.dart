import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/core/config/app_config.dart';
import 'package:expense_tracker/services/cloudflare_r2_service.dart';
import 'package:expense_tracker/services/data_export_service.dart';
import 'package:expense_tracker/services/split_service.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/split_models.dart';

void main() {
  group('[SEC-03] Cloudflare R2 Master Storage Secrets', () {
    test('Default R2 credentials are empty strings and hasR2Configured is false', () {
      expect(AppConfig.r2AccessKeyId, isEmpty);
      expect(AppConfig.r2SecretAccessKey, isEmpty);
      expect(AppConfig.hasR2Configured, isFalse);
    });

    test('CloudflareR2Service aborts gracefully when R2 is unconfigured', () async {
      final uploadRes = await CloudflareR2Service.instance.uploadBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        path: 'receipts/test.jpg',
      );
      expect(uploadRes, isNull);

      final deleteUrlRes = await CloudflareR2Service.instance.deleteByUrl(
        'https://pub-r2.dev/receipts/test.jpg',
      );
      expect(deleteUrlRes, isFalse);

      final deleteFileRes = await CloudflareR2Service.instance.deleteFile('receipts/test.jpg');
      expect(deleteFileRes, isFalse);
    });
  });

  group('[SEC-08] & BUG-07 Split Balances & Validation', () {
    test('computeBalancesFromData isolates balances strictly to member IDs in members list', () {
      final members = [
        SplitMember(id: 'm1', groupId: 'g1', name: 'Alice', joinedAt: DateTime.now()),
        SplitMember(id: 'm2', groupId: 'g1', name: 'Bob', joinedAt: DateTime.now()),
      ];
      final orphanExpense = SplitExpense(
        id: 'e_orphan',
        groupId: 'g1',
        title: 'Deleted User Dinner',
        totalAmount: 100.0,
        paidByMemberId: 'm_deleted',
        splitType: SplitType.equal,
        addedByMemberId: 'm1',
        createdAt: DateTime.now(),
      );
      final shares = [
        SplitShare(id: 's1', expenseId: 'e_orphan', memberId: 'm1', shareAmount: 50.0),
        SplitShare(id: 's2', expenseId: 'e_orphan', memberId: 'm2', shareAmount: 50.0),
        SplitShare(id: 's3', expenseId: 'e_orphan', memberId: 'm_deleted', shareAmount: 0.0),
      ];

      final balances = SplitService.instance.computeBalancesFromData(
        members: members,
        expenses: [orphanExpense],
        settlements: [],
        shares: shares,
      );

      // Balances must contain keys strictly for m1 and m2
      expect(balances.containsKey('m_deleted'), isFalse);
      expect(balances['m1'], -50.0);
      expect(balances['m2'], -50.0);
    });

    test('addExpense throws ArgumentError when custom share amount is negative', () async {
      expect(
        () => SplitService.instance.addExpense(
          groupId: 'g1',
          title: 'Dinner',
          totalAmount: 100.0,
          paidByMemberId: 'm1',
          splitType: SplitType.unequal,
          shares: {'m1': 150.0, 'm2': -50.0},
          addedByMemberId: 'm1',
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Share amount cannot be negative'),
        )),
      );
    });
  });

  group('[SEC-09] & [SEC-10] CSV & JSON Export Security', () {
    test('generateCsv outputs Type column, formats signed amounts, and neutralizes leading whitespace injection', () {
      final now = DateTime.now();
      final expense = Expense(
        id: 1,
        amount: 250.0,
        category: 'Food',
        paymentMethod: 'UPI',
        comment: '   =cmd|\' /C calc\'!A0', // Whitespace prefix injection
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
        type: TransactionType.expense,
      );
      final income = Expense(
        id: 2,
        amount: 1000.0,
        category: 'Salary',
        paymentMethod: 'Bank Transfer',
        comment: 'Bonus',
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
        type: TransactionType.income,
      );

      final csv = DataExportService.instance.generateCsv([expense, income]);

      expect(csv, contains('ID,Type,Date,Time,Category,Amount (INR),Payment Method,Note / Payee,Created Timestamp'));
      expect(csv, contains(',Expense,'));
      expect(csv, contains('-250.00'));
      expect(csv, contains(',Income,'));
      expect(csv, contains('+1000.00'));
      expect(csv, contains("'   =cmd"));
    });

    test('generateJson includes type and isExpense keys', () {
      final now = DateTime.now();
      final income = Expense(
        id: 5,
        amount: 5000.0,
        category: 'Freelance',
        paymentMethod: 'Cash',
        expenseDate: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
        type: TransactionType.income,
      );

      final jsonStr = DataExportService.instance.generateJson([income]);
      expect(jsonStr, contains('"type": "income"'));
      expect(jsonStr, contains('"isExpense": false'));
    });
  });
}
