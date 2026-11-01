import 'package:uuid/uuid.dart';

enum ReminderFrequency {
  oneTime,
  weekly,
  monthly,
  quarterly,
  yearly,
  customDays;

  String get label {
    switch (this) {
      case ReminderFrequency.oneTime:
        return 'One-Time';
      case ReminderFrequency.weekly:
        return 'Weekly';
      case ReminderFrequency.monthly:
        return 'Monthly';
      case ReminderFrequency.quarterly:
        return 'Quarterly';
      case ReminderFrequency.yearly:
        return 'Yearly';
      case ReminderFrequency.customDays:
        return 'Custom Interval';
    }
  }

  String toDbValue() {
    switch (this) {
      case ReminderFrequency.oneTime:
        return 'one_time';
      case ReminderFrequency.weekly:
        return 'weekly';
      case ReminderFrequency.monthly:
        return 'monthly';
      case ReminderFrequency.quarterly:
        return 'quarterly';
      case ReminderFrequency.yearly:
        return 'yearly';
      case ReminderFrequency.customDays:
        return 'custom_days';
    }
  }

  static ReminderFrequency fromDbValue(String? value) {
    switch (value?.toLowerCase()) {
      case 'one_time':
      case 'onetime':
        return ReminderFrequency.oneTime;
      case 'weekly':
        return ReminderFrequency.weekly;
      case 'quarterly':
        return ReminderFrequency.quarterly;
      case 'yearly':
        return ReminderFrequency.yearly;
      case 'custom_days':
      case 'customdays':
        return ReminderFrequency.customDays;
      case 'monthly':
      default:
        return ReminderFrequency.monthly;
    }
  }
}

enum ReminderSplitType {
  personal,
  splitExpense,
  settlement;

  String toDbValue() {
    switch (this) {
      case ReminderSplitType.personal:
        return 'personal';
      case ReminderSplitType.splitExpense:
        return 'split_expense';
      case ReminderSplitType.settlement:
        return 'settlement';
    }
  }

  static ReminderSplitType fromDbValue(String? value) {
    switch (value?.toLowerCase()) {
      case 'split_expense':
        return ReminderSplitType.splitExpense;
      case 'settlement':
        return ReminderSplitType.settlement;
      case 'personal':
      default:
        return ReminderSplitType.personal;
    }
  }
}

class PaymentReminder {
  final String id;
  final String? userId;
  final String title;
  final double amount;
  final String category;
  final String paymentMethod;
  final ReminderFrequency frequency;
  final int? customIntervalDays;
  final int? dueDay; // Day of month 1-31
  final DateTime? dueDate; // Specific target date for one-time
  final DateTime nextDueDate;
  final DateTime? lastPaidDate;
  final DateTime? notifiedDayBeforeAt;
  final DateTime? notifiedDueDayAt;
  final bool isActive;
  final bool isCompleted;
  final String? splitGroupId;
  final ReminderSplitType splitType;
  final String? splitTargetMemberId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentReminder({
    String? id,
    this.userId,
    required this.title,
    required this.amount,
    required this.category,
    required this.paymentMethod,
    this.frequency = ReminderFrequency.monthly,
    this.customIntervalDays,
    this.dueDay,
    this.dueDate,
    required this.nextDueDate,
    this.lastPaidDate,
    this.notifiedDayBeforeAt,
    this.notifiedDueDayAt,
    this.isActive = true,
    this.isCompleted = false,
    this.splitGroupId,
    this.splitType = ReminderSplitType.personal,
    this.splitTargetMemberId,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Days in month helper without external UI dependencies
  static int daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  /// Calculates the next due date when rolling forward a cycle
  DateTime calculateNextCycleDate([DateTime? referenceDate]) {
    final base = referenceDate ?? nextDueDate;
    switch (frequency) {
      case ReminderFrequency.oneTime:
        return dueDate ?? nextDueDate;
      case ReminderFrequency.weekly:
        return base.add(const Duration(days: 7));
      case ReminderFrequency.monthly:
        int nextYear = base.year;
        int nextMonth = base.month + 1;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        final targetDay = dueDay ?? base.day;
        final maxDay = daysInMonth(nextYear, nextMonth);
        final finalDay = targetDay.clamp(1, maxDay);
        return DateTime(nextYear, nextMonth, finalDay, base.hour, base.minute);
      case ReminderFrequency.quarterly:
        int nextYear = base.year;
        int nextMonth = base.month + 3;
        if (nextMonth > 12) {
          nextMonth -= 12;
          nextYear++;
        }
        final targetDay = dueDay ?? base.day;
        final maxDay = daysInMonth(nextYear, nextMonth);
        final finalDay = targetDay.clamp(1, maxDay);
        return DateTime(nextYear, nextMonth, finalDay, base.hour, base.minute);
      case ReminderFrequency.yearly:
        int nextYear = base.year + 1;
        final targetDay = dueDay ?? base.day;
        final maxDay = daysInMonth(nextYear, base.month);
        final finalDay = targetDay.clamp(1, maxDay);
        return DateTime(nextYear, base.month, finalDay, base.hour, base.minute);
      case ReminderFrequency.customDays:
        final days = (customIntervalDays != null && customIntervalDays! > 0)
            ? customIntervalDays!
            : 30;
        return base.add(Duration(days: days));
    }
  }

  /// Calendar days until due from today (0 = due today, negative = overdue)
  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    return due.difference(today).inDays;
  }

  bool get isOverdue => !isCompleted && isActive && daysUntilDue < 0;
  bool get isDueToday => !isCompleted && isActive && daysUntilDue == 0;
  bool get isDueTomorrow => !isCompleted && isActive && daysUntilDue == 1;
  bool get isUpcoming => !isCompleted && isActive && daysUntilDue > 1 && daysUntilDue <= 7;

  String get dueStatusText {
    if (isCompleted) return 'Completed';
    if (!isActive) return 'Paused';
    if (isOverdue) {
      final days = daysUntilDue.abs();
      return 'Overdue by $days ${days == 1 ? "day" : "days"}';
    }
    if (isDueToday) return 'Due Today';
    if (isDueTomorrow) return 'Due Tomorrow';
    return 'Due in $daysUntilDue days';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'amount': amount,
      'category': category,
      'payment_method': paymentMethod,
      'frequency': frequency.toDbValue(),
      'custom_interval_days': customIntervalDays,
      'due_day': dueDay,
      'due_date': dueDate?.millisecondsSinceEpoch,
      'next_due_date': nextDueDate.millisecondsSinceEpoch,
      'last_paid_date': lastPaidDate?.millisecondsSinceEpoch,
      'notified_day_before_at': notifiedDayBeforeAt?.millisecondsSinceEpoch,
      'notified_due_day_at': notifiedDueDayAt?.millisecondsSinceEpoch,
      'is_active': isActive ? 1 : 0,
      'is_completed': isCompleted ? 1 : 0,
      'split_group_id': splitGroupId,
      'split_type': splitType.toDbValue(),
      'split_target_member_id': splitTargetMemberId,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory PaymentReminder.fromMap(Map<String, dynamic> map) {
    return PaymentReminder(
      id: map['id']?.toString() ?? const Uuid().v4(),
      userId: map['user_id']?.toString(),
      title: map['title']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category']?.toString() ?? 'Bills',
      paymentMethod: map['payment_method']?.toString() ?? 'UPI',
      frequency: ReminderFrequency.fromDbValue(map['frequency']?.toString()),
      customIntervalDays: (map['custom_interval_days'] as num?)?.toInt(),
      dueDay: (map['due_day'] as num?)?.toInt(),
      dueDate: map['due_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['due_date'] as num).toInt())
          : null,
      nextDueDate: map['next_due_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['next_due_date'] as num).toInt())
          : DateTime.now(),
      lastPaidDate: map['last_paid_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['last_paid_date'] as num).toInt())
          : null,
      notifiedDayBeforeAt: map['notified_day_before_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['notified_day_before_at'] as num).toInt())
          : null,
      notifiedDueDayAt: map['notified_due_day_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['notified_due_day_at'] as num).toInt())
          : null,
      isActive: (map['is_active'] is bool)
          ? map['is_active'] as bool
          : ((map['is_active'] as num?)?.toInt() ?? 1) == 1,
      isCompleted: (map['is_completed'] is bool)
          ? map['is_completed'] as bool
          : ((map['is_completed'] as num?)?.toInt() ?? 0) == 1,
      splitGroupId: map['split_group_id']?.toString(),
      splitType: ReminderSplitType.fromDbValue(map['split_type']?.toString()),
      splitTargetMemberId: map['split_target_member_id']?.toString(),
      notes: map['notes']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['created_at'] as num).toInt())
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['updated_at'] as num).toInt())
          : DateTime.now(),
    );
  }

  PaymentReminder copyWith({
    String? id,
    String? userId,
    String? title,
    double? amount,
    String? category,
    String? paymentMethod,
    ReminderFrequency? frequency,
    int? customIntervalDays,
    int? dueDay,
    DateTime? dueDate,
    DateTime? nextDueDate,
    DateTime? lastPaidDate,
    DateTime? notifiedDayBeforeAt,
    DateTime? notifiedDueDayAt,
    bool? isActive,
    bool? isCompleted,
    String? splitGroupId,
    ReminderSplitType? splitType,
    String? splitTargetMemberId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentReminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      frequency: frequency ?? this.frequency,
      customIntervalDays: customIntervalDays ?? this.customIntervalDays,
      dueDay: dueDay ?? this.dueDay,
      dueDate: dueDate ?? this.dueDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      lastPaidDate: lastPaidDate ?? this.lastPaidDate,
      notifiedDayBeforeAt: notifiedDayBeforeAt ?? this.notifiedDayBeforeAt,
      notifiedDueDayAt: notifiedDueDayAt ?? this.notifiedDueDayAt,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      splitGroupId: splitGroupId ?? this.splitGroupId,
      splitType: splitType ?? this.splitType,
      splitTargetMemberId: splitTargetMemberId ?? this.splitTargetMemberId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
