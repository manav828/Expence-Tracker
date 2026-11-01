import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/payment_reminder.dart';

void main() {
  group('PaymentReminder Model & Frequency Tests', () {
    test('ReminderFrequency enum conversions', () {
      expect(ReminderFrequency.oneTime.toDbValue(), 'one_time');
      expect(ReminderFrequency.monthly.toDbValue(), 'monthly');
      expect(ReminderFrequency.weekly.toDbValue(), 'weekly');
      expect(ReminderFrequency.quarterly.toDbValue(), 'quarterly');
      expect(ReminderFrequency.yearly.toDbValue(), 'yearly');
      expect(ReminderFrequency.customDays.toDbValue(), 'custom_days');

      expect(ReminderFrequency.fromDbValue('one_time'), ReminderFrequency.oneTime);
      expect(ReminderFrequency.fromDbValue('weekly'), ReminderFrequency.weekly);
      expect(ReminderFrequency.fromDbValue('quarterly'), ReminderFrequency.quarterly);
      expect(ReminderFrequency.fromDbValue('yearly'), ReminderFrequency.yearly);
      expect(ReminderFrequency.fromDbValue('custom_days'), ReminderFrequency.customDays);
      expect(ReminderFrequency.fromDbValue('invalid'), ReminderFrequency.monthly);
    });

    test('ReminderSplitType enum conversions', () {
      expect(ReminderSplitType.personal.toDbValue(), 'personal');
      expect(ReminderSplitType.splitExpense.toDbValue(), 'split_expense');
      expect(ReminderSplitType.settlement.toDbValue(), 'settlement');

      expect(ReminderSplitType.fromDbValue('personal'), ReminderSplitType.personal);
      expect(ReminderSplitType.fromDbValue('split_expense'), ReminderSplitType.splitExpense);
      expect(ReminderSplitType.fromDbValue('settlement'), ReminderSplitType.settlement);
      expect(ReminderSplitType.fromDbValue(null), ReminderSplitType.personal);
    });

    test('PaymentReminder serialization toMap and fromMap roundtrip', () {
      final now = DateTime.now();
      final reminder = PaymentReminder(
        id: 'rem-101',
        userId: 'user-xyz',
        title: 'House Rent',
        amount: 18500.0,
        category: 'Bills & Utilities',
        paymentMethod: 'UPI',
        frequency: ReminderFrequency.monthly,
        dueDay: 5,
        nextDueDate: DateTime(2026, 11, 5),
        splitGroupId: 'group-flat',
        splitType: ReminderSplitType.splitExpense,
        notes: 'Pay to landlord UPI by 5th',
        createdAt: now,
        updatedAt: now,
      );

      final map = reminder.toMap();
      final reconstructed = PaymentReminder.fromMap(map);

      expect(reconstructed.id, 'rem-101');
      expect(reconstructed.userId, 'user-xyz');
      expect(reconstructed.title, 'House Rent');
      expect(reconstructed.amount, 18500.0);
      expect(reconstructed.category, 'Bills & Utilities');
      expect(reconstructed.paymentMethod, 'UPI');
      expect(reconstructed.frequency, ReminderFrequency.monthly);
      expect(reconstructed.dueDay, 5);
      expect(reconstructed.splitGroupId, 'group-flat');
      expect(reconstructed.splitType, ReminderSplitType.splitExpense);
      expect(reconstructed.notes, 'Pay to landlord UPI by 5th');
      expect(reconstructed.isActive, true);
      expect(reconstructed.isCompleted, false);
    });

    test('One-Time reminder next cycle calculation preserves target due date', () {
      final targetDate = DateTime(2026, 12, 15);
      final reminder = PaymentReminder(
        title: 'College Exam Fee',
        amount: 3500.0,
        category: 'Education',
        paymentMethod: 'Card',
        frequency: ReminderFrequency.oneTime,
        dueDate: targetDate,
        nextDueDate: targetDate,
      );

      final next = reminder.calculateNextCycleDate();
      expect(next, targetDate);
    });

    test('Weekly reminder next cycle calculation adds exactly 7 days', () {
      final start = DateTime(2026, 11, 2);
      final reminder = PaymentReminder(
        title: 'Weekly Vegetable Fund',
        amount: 800.0,
        category: 'Food & Dining',
        paymentMethod: 'Cash',
        frequency: ReminderFrequency.weekly,
        nextDueDate: start,
      );

      final next = reminder.calculateNextCycleDate(start);
      expect(next, DateTime(2026, 11, 9));
    });

    test('Monthly reminder rolls to next month with month-end safety', () {
      // 31st Jan -> 28th Feb (non-leap) or 29th (leap)
      final jan31 = DateTime(2026, 1, 31);
      final reminder = PaymentReminder(
        title: 'Broadband Bill',
        amount: 999.0,
        category: 'Bills & Utilities',
        paymentMethod: 'UPI',
        frequency: ReminderFrequency.monthly,
        dueDay: 31,
        nextDueDate: jan31,
      );

      final febDueDate = reminder.calculateNextCycleDate(jan31);
      expect(febDueDate.month, 2);
      expect(febDueDate.day, 28); // 2026 is non-leap
    });

    test('Quarterly reminder adds 3 months correctly', () {
      final start = DateTime(2026, 3, 10);
      final reminder = PaymentReminder(
        title: 'Society Maintenance',
        amount: 6000.0,
        category: 'Bills & Utilities',
        paymentMethod: 'NetBanking',
        frequency: ReminderFrequency.quarterly,
        dueDay: 10,
        nextDueDate: start,
      );

      final next = reminder.calculateNextCycleDate(start);
      expect(next.month, 6);
      expect(next.day, 10);
      expect(next.year, 2026);
    });

    test('Yearly reminder adds 1 year correctly', () {
      final start = DateTime(2026, 7, 20);
      final reminder = PaymentReminder(
        title: 'Car Insurance',
        amount: 14000.0,
        category: 'Transport',
        paymentMethod: 'Card',
        frequency: ReminderFrequency.yearly,
        dueDay: 20,
        nextDueDate: start,
      );

      final next = reminder.calculateNextCycleDate(start);
      expect(next.year, 2027);
      expect(next.month, 7);
      expect(next.day, 20);
    });

    test('CustomDays reminder adds specified interval (e.g. 28 days for prepaid plan)', () {
      final start = DateTime(2026, 11, 1);
      final reminder = PaymentReminder(
        title: 'Mobile Recharge',
        amount: 299.0,
        category: 'Bills & Utilities',
        paymentMethod: 'UPI',
        frequency: ReminderFrequency.customDays,
        customIntervalDays: 28,
        nextDueDate: start,
      );

      final next = reminder.calculateNextCycleDate(start);
      expect(next, DateTime(2026, 11, 29));
    });

    test('Due status getters correctly evaluate overdue, today, tomorrow, and upcoming', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final overdueRem = PaymentReminder(
        title: 'Electricity',
        amount: 1200.0,
        category: 'Bills',
        paymentMethod: 'UPI',
        nextDueDate: today.subtract(const Duration(days: 2)),
      );
      expect(overdueRem.isOverdue, true);
      expect(overdueRem.isDueToday, false);
      expect(overdueRem.daysUntilDue, -2);
      expect(overdueRem.dueStatusText, 'Overdue by 2 days');

      final todayRem = PaymentReminder(
        title: 'Rent',
        amount: 15000.0,
        category: 'Bills',
        paymentMethod: 'UPI',
        nextDueDate: today,
      );
      expect(todayRem.isDueToday, true);
      expect(todayRem.isOverdue, false);
      expect(todayRem.daysUntilDue, 0);
      expect(todayRem.dueStatusText, 'Due Today');

      final tomorrowRem = PaymentReminder(
        title: 'Gym Fee',
        amount: 1500.0,
        category: 'Health',
        paymentMethod: 'Card',
        nextDueDate: today.add(const Duration(days: 1)),
      );
      expect(tomorrowRem.isDueTomorrow, true);
      expect(tomorrowRem.dueStatusText, 'Due Tomorrow');

      final upcomingRem = PaymentReminder(
        title: 'Netflix',
        amount: 649.0,
        category: 'Entertainment',
        paymentMethod: 'Card',
        nextDueDate: today.add(const Duration(days: 4)),
      );
      expect(upcomingRem.isUpcoming, true);
      expect(upcomingRem.dueStatusText, 'Due in 4 days');
    });

    test('Completed or paused reminders do not flag as overdue or due today', () {
      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 5));

      final completed = PaymentReminder(
        title: 'One-Time Dentist Bill',
        amount: 2000.0,
        category: 'Health',
        paymentMethod: 'UPI',
        nextDueDate: pastDate,
        isCompleted: true,
      );
      expect(completed.isOverdue, false);
      expect(completed.isDueToday, false);
      expect(completed.dueStatusText, 'Completed');

      final paused = PaymentReminder(
        title: 'Magazine Sub',
        amount: 500.0,
        category: 'Entertainment',
        paymentMethod: 'UPI',
        nextDueDate: pastDate,
        isActive: false,
      );
      expect(paused.isOverdue, false);
      expect(paused.isDueToday, false);
      expect(paused.dueStatusText, 'Paused');
    });
  });
}
