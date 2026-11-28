import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_reminder.dart';
import '../models/expense.dart';
import '../models/split_models.dart';
import '../services/database_service.dart';
import '../services/split_service.dart';
import '../services/auth_service.dart';
import 'expense_provider.dart';

class ReminderProvider extends ChangeNotifier {
  List<PaymentReminder> _reminders = [];
  bool _isLoading = false;
  final Map<String, String> _homeDismissals = {};
  int _homeRevision = 0;
  int _sessionRevision = 0;
  StreamSubscription<AuthState>? _authSub;
  String? _lastAuthUserId;

  List<PaymentReminder> get reminders => _reminders;
  bool get isLoading => _isLoading;

  ReminderProvider({bool autoFetch = false}) {
    if (autoFetch) {
      loadReminders();
    }
    _initAuthListener(autoFetch: autoFetch);
  }

  void _initAuthListener({required bool autoFetch}) {
    try {
      _lastAuthUserId = Supabase.instance.client.auth.currentUser?.id;
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        if (event == AuthChangeEvent.signedOut) {
          _lastAuthUserId = null;
          clearStateOnLogout();
        } else if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.initialSession ||
            event == AuthChangeEvent.userUpdated) {
          final uid = data.session?.user.id;
          if (!autoFetch && event == AuthChangeEvent.initialSession) return;
          if (uid != _lastAuthUserId) {
            _lastAuthUserId = uid;
            clearStateOnLogout();
            loadReminders();
          }
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _sessionRevision++;
    _homeRevision++;
    _authSub?.cancel();
    super.dispose();
  }

  void clearStateOnLogout() {
    _sessionRevision++;
    _homeRevision++;
    _reminders = [];
    _homeDismissals.clear();
    _isLoading = false;
    notifyListeners();
  }

  /// Active (not paused, not completed) reminders sorted by due date
  List<PaymentReminder> get activeReminders {
    final list = _reminders.where((r) => r.isActive && !r.isCompleted).toList();
    list.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    return list;
  }

  /// Reminders overdue (due in past)
  List<PaymentReminder> get overdueReminders =>
      activeReminders.where((r) => r.isOverdue).toList();

  /// Reminders due today
  List<PaymentReminder> get dueTodayReminders =>
      activeReminders.where((r) => r.isDueToday).toList();

  /// Reminders due tomorrow
  List<PaymentReminder> get dueTomorrowReminders =>
      activeReminders.where((r) => r.isDueTomorrow).toList();

  /// Reminders upcoming in the next 7 days (including tomorrow)
  List<PaymentReminder> get upcomingReminders =>
      activeReminders.where((r) => r.isDueTomorrow || r.isUpcoming).toList();

  /// All actionable pending reminders for Dashboard carousel (overdue, due today, upcoming)
  List<PaymentReminder> get dashboardActionableReminders {
    final today = _todayKey;
    return activeReminders.where((reminder) {
      final dismissal = _homeDismissals[_occurrenceKey(reminder)];
      return reminder.daysUntilDue <= 7 &&
          dismissal != 'hidden' &&
          dismissal != today;
    }).toList();
  }

  /// Completed or archived reminders
  List<PaymentReminder> get completedReminders {
    final list = _reminders.where((r) => r.isCompleted).toList();
    list.sort((a, b) => (b.lastPaidDate ?? b.updatedAt).compareTo(a.lastPaidDate ?? a.updatedAt));
    return list;
  }

  /// Paused reminders
  List<PaymentReminder> get pausedReminders =>
      _reminders.where((r) => !r.isActive && !r.isCompleted).toList();

  /// Count of urgent reminders (Overdue + Due Today + Due Tomorrow) for app bar notification bell
  int get notificationBadgeCount =>
      activeReminders.where((r) => r.isOverdue || r.isDueToday || r.isDueTomorrow).length;

  /// Total normalized monthly fixed financial commitment for recurring bills
  double get totalMonthlyCommittedAmount {
    double total = 0.0;
    for (final r in activeReminders) {
      switch (r.frequency) {
        case ReminderFrequency.oneTime:
          // One-time bills only count if due in the current calendar month
          final now = DateTime.now();
          if (r.nextDueDate.year == now.year && r.nextDueDate.month == now.month) {
            total += r.amount;
          }
          break;
        case ReminderFrequency.monthly:
          total += r.amount;
          break;
        case ReminderFrequency.weekly:
          total += r.amount * 4.33;
          break;
        case ReminderFrequency.quarterly:
          total += r.amount / 3.0;
          break;
        case ReminderFrequency.yearly:
          total += r.amount / 12.0;
          break;
        case ReminderFrequency.customDays:
          final days = (r.customIntervalDays != null && r.customIntervalDays! > 0)
              ? r.customIntervalDays!
              : 30;
          total += (r.amount / days) * 30.0;
          break;
      }
    }
    return total;
  }

  String get _homePreferenceKey =>
      'reminder_home_v1_${AuthService.instance.currentUser?.id ?? 'guest'}';

  String get _todayKey => DateTime.now().toIso8601String().substring(0, 10);

  String _occurrenceKey(PaymentReminder reminder) =>
      '${reminder.id}:${reminder.nextDueDate.millisecondsSinceEpoch}';

  Future<void> _loadHomeDismissals() async {
    final key = _homePreferenceKey;
    final revision = _homeRevision;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (revision != _homeRevision) return;
      final stored = prefs.getString(key);
      final decoded =
          stored == null ? <String, String>{} : Map<String, String>.from(jsonDecode(stored) as Map);
      _homeDismissals
        ..clear()
        ..addAll(decoded);
    } catch (_) {}
  }

  Future<void> dismissFromHome(
    PaymentReminder reminder, {
    bool untilTomorrow = false,
  }) {
    _homeDismissals[_occurrenceKey(reminder)] = untilTomorrow ? _todayKey : 'hidden';
    return _saveHomeDismissals();
  }

  Future<void> restoreOnHome(PaymentReminder reminder) {
    _homeDismissals.remove(_occurrenceKey(reminder));
    return _saveHomeDismissals();
  }

  Future<void> _saveHomeDismissals() async {
    final key = _homePreferenceKey;
    final today = _todayKey;
    final activeKeys = activeReminders.map(_occurrenceKey).toSet();
    _homeDismissals.removeWhere((key, value) =>
        !activeKeys.contains(key) || (value != 'hidden' && value != today));
    final stored = jsonEncode(_homeDismissals);
    _homeRevision++;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, stored);
    } catch (_) {}
  }

  @visibleForTesting
  void setRemindersForTesting(List<PaymentReminder> list) {
    _reminders = List.from(list);
    notifyListeners();
  }

  // --- Data Operations ---

  Future<void> loadReminders() async {
    final session = _sessionRevision;
    _isLoading = true;
    notifyListeners();
    try {
      await _loadHomeDismissals();
      if (session != _sessionRevision) return;
      final list = await DatabaseService.instance.getPaymentReminders();
      if (session != _sessionRevision) return;
      _reminders = list;
      await checkAndTriggerDueAlerts();
    } catch (e) {
      debugPrint('Error loading reminders: $e');
    } finally {
      if (session == _sessionRevision) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> addReminder(PaymentReminder reminder) async {
    _reminders.add(reminder);
    notifyListeners();
    try {
      await DatabaseService.instance.savePaymentReminder(reminder);
      await checkAndTriggerDueAlerts();
    } catch (e) {
      debugPrint('Error adding reminder: $e');
    }
  }

  Future<void> updateReminder(PaymentReminder reminder) async {
    final idx = _reminders.indexWhere((r) => r.id == reminder.id);
    if (idx != -1) {
      _reminders[idx] = reminder;
      notifyListeners();
    }
    try {
      await DatabaseService.instance.savePaymentReminder(reminder);
    } catch (e) {
      debugPrint('Error updating reminder: $e');
    }
  }

  Future<void> deleteReminder(String id) async {
    _reminders.removeWhere((r) => r.id == id);
    notifyListeners();
    try {
      await DatabaseService.instance.deletePaymentReminder(id);
    } catch (e) {
      debugPrint('Error deleting reminder: $e');
    }
  }

  Future<void> toggleReminderActive(String id) async {
    final idx = _reminders.indexWhere((r) => r.id == id);
    if (idx != -1) {
      final r = _reminders[idx];
      final updated = r.copyWith(isActive: !r.isActive, updatedAt: DateTime.now());
      _reminders[idx] = updated;
      notifyListeners();
      try {
        await DatabaseService.instance.savePaymentReminder(updated);
      } catch (e) {
        debugPrint('Error toggling reminder: $e');
      }
    }
  }

  // --- 1-Tap "Mark as Paid" Flow ---

  /// 1-Tap Mark as Paid:
  /// 1. Logs the expense in personal ledger via ExpenseProvider.
  /// 2. If split-linked, automatically creates the expense/settlement in the Split group.
  /// 3. Rolls nextDueDate forward to next cycle (or archives if one-time).
  Future<PaymentReminder?> markAsPaid(
    String reminderId, {
    DateTime? paidDate,
    String? paymentMethod,
    ExpenseProvider? expenseProvider,
  }) async {
    final idx = _reminders.indexWhere((r) => r.id == reminderId);
    if (idx == -1) return null;
    final reminder = _reminders[idx];

    final now = DateTime.now();
    final effectivePaidDate = paidDate ?? now;
    final effectiveMethod = paymentMethod ?? reminder.paymentMethod;

    // 1. Auto-log personal expense
    final personalExpense = Expense(
      amount: reminder.amount,
      category: reminder.category,
      paymentMethod: effectiveMethod,
      comment: 'Auto-logged from reminder: ${reminder.title}',
      expenseDate: effectivePaidDate.millisecondsSinceEpoch,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
      type: TransactionType.expense,
    );

    if (expenseProvider != null) {
      await expenseProvider.addExpense(personalExpense);
    } else {
      await DatabaseService.instance.insertExpense(personalExpense);
    }

    // 2. If Split-linked, automatically create split expense or settlement
    if (reminder.splitGroupId != null && reminder.splitGroupId!.isNotEmpty) {
      try {
        final groupId = reminder.splitGroupId!;
        final members = await SplitService.instance.getMembers(groupId);
        final currentUser = AuthService.instance.currentUser;

        // Find my member record in this group
        SplitMember? myMember;
        if (currentUser?.id != null) {
          myMember = members.where((m) => m.userId == currentUser!.id).firstOrNull;
        }
        myMember ??= members.firstOrNull;

        if (myMember != null && members.isNotEmpty) {
          if (reminder.splitType == ReminderSplitType.settlement &&
              reminder.splitTargetMemberId != null) {
            // Record settlement
            await SplitService.instance.recordSettlement(
              groupId: groupId,
              fromMemberId: myMember.id,
              toMemberId: reminder.splitTargetMemberId!,
              amount: reminder.amount,
              note: 'Settled bill: ${reminder.title}',
            );
          } else {
            // Split expense equally across group members
            final equalShare = double.parse((reminder.amount / members.length).toStringAsFixed(2));
            final shares = <String, double>{};
            double distributed = 0.0;
            for (int i = 0; i < members.length; i++) {
              if (i == members.length - 1) {
                // Assign remainder cents to last member
                final remainder = double.parse((reminder.amount - distributed).toStringAsFixed(2));
                shares[members[i].id] = remainder;
              } else {
                shares[members[i].id] = equalShare;
                distributed += equalShare;
              }
            }

            await SplitService.instance.addExpense(
              groupId: groupId,
              title: reminder.title,
              totalAmount: reminder.amount,
              paidByMemberId: myMember.id,
              splitType: SplitType.equal,
              shares: shares,
              category: reminder.category,
              note: 'Recurring bill auto-split',
              addedByMemberId: myMember.id,
            );
          }
        }
      } catch (e) {
        debugPrint('Split auto-log error in reminder: $e');
      }
    }

    // 3. Roll forward or complete reminder
    PaymentReminder updated;
    if (reminder.frequency == ReminderFrequency.oneTime) {
      updated = reminder.copyWith(
        isCompleted: true,
        lastPaidDate: effectivePaidDate,
        updatedAt: now,
      );
    } else {
      final nextCycle = reminder.calculateNextCycleDate(reminder.nextDueDate);
      updated = reminder.copyWith(
        nextDueDate: nextCycle,
        lastPaidDate: effectivePaidDate,
        notifiedDayBeforeAt: null, // Reset Day -1 notification for new cycle
        notifiedDueDayAt: null,    // Reset Day 0 notification for new cycle
        updatedAt: now,
      );
    }

    _reminders[idx] = updated;
    notifyListeners();

    try {
      await DatabaseService.instance.savePaymentReminder(updated);
    } catch (e) {
      debugPrint('Error saving paid reminder state: $e');
    }

    return updated;
  }

  // --- Strict 2-Notification Rate Limiting Engine ---

  /// Checks active reminders and triggers alerts:
  /// Exactly 1 alert 1 day before due date, and exactly 1 alert on the due date.
  /// Zero spam: Will never notify more than these 2 times per cycle.
  Future<List<PaymentReminder>> checkAndTriggerDueAlerts() async {
    final newlyAlerted = <PaymentReminder>[];
    final now = DateTime.now();

    for (int i = 0; i < _reminders.length; i++) {
      final r = _reminders[i];
      if (!r.isActive || r.isCompleted) continue;

      final daysUntil = r.daysUntilDue;

      // Rule 1: 1 Day Before Due Date (Day -1)
      if (daysUntil == 1 && r.notifiedDayBeforeAt == null) {
        newlyAlerted.add(r);
        final updated = r.copyWith(
          notifiedDayBeforeAt: now,
          updatedAt: now,
        );
        _reminders[i] = updated;
        await DatabaseService.instance.updateReminderNotificationTimestamps(
          r.id,
          dayBefore: now.millisecondsSinceEpoch,
        );
      }
      // Rule 2: On Due Date / Overdue (Day 0+)
      else if (daysUntil <= 0 && r.notifiedDueDayAt == null) {
        newlyAlerted.add(r);
        final updated = r.copyWith(
          notifiedDueDayAt: now,
          updatedAt: now,
        );
        _reminders[i] = updated;
        await DatabaseService.instance.updateReminderNotificationTimestamps(
          r.id,
          dueDay: now.millisecondsSinceEpoch,
        );
      }
    }

    if (newlyAlerted.isNotEmpty) {
      notifyListeners();
    }
    return newlyAlerted;
  }
}
