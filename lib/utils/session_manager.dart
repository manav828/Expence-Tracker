import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/reminder_provider.dart';
import '../providers/split_provider.dart';
import '../providers/trip_photo_provider.dart';
import '../services/announcement_service.dart';

/// Coordinates clearing and reloading all user-scoped providers across
/// sign-out, account switching, and session restoration in the same tab.
class SessionManager {
  SessionManager._();

  /// Synchronously clears all in-memory user state from root providers.
  static void clearAllProviders(BuildContext context) {
    try {
      context.read<ExpenseProvider>().clearStateOnLogout();
    } catch (_) {}
    try {
      context.read<BudgetProvider>().clearStateOnLogout();
    } catch (_) {}
    try {
      context.read<ReminderProvider>().clearStateOnLogout();
    } catch (_) {}
    try {
      context.read<SplitProvider>().clearStateOnLogout();
    } catch (_) {}
    try {
      context.read<TripPhotoProvider>().clearStateOnLogout();
    } catch (_) {}
    AnnouncementService.instance.clearStateOnLogout();
  }

  /// Clears any stale state from the prior session and reloads fresh data for
  /// the active user (or guest).
  static Future<void> reloadAllProviders(BuildContext context) async {
    ExpenseProvider? expenseProv;
    BudgetProvider? budgetProv;
    ReminderProvider? reminderProv;
    SplitProvider? splitProv;
    TripPhotoProvider? photoProv;

    try {
      expenseProv = context.read<ExpenseProvider>();
    } catch (_) {}
    try {
      budgetProv = context.read<BudgetProvider>();
    } catch (_) {}
    try {
      reminderProv = context.read<ReminderProvider>();
    } catch (_) {}
    try {
      splitProv = context.read<SplitProvider>();
    } catch (_) {}
    try {
      photoProv = context.read<TripPhotoProvider>();
    } catch (_) {}

    expenseProv?.clearStateOnLogout();
    budgetProv?.clearStateOnLogout();
    reminderProv?.clearStateOnLogout();
    splitProv?.clearStateOnLogout();
    photoProv?.clearStateOnLogout();
    AnnouncementService.instance.clearStateOnLogout();

    await Future.wait([
      if (expenseProv != null) expenseProv.fetchExpenses(),
      if (budgetProv != null) budgetProv.fetchBudgets(),
      if (reminderProv != null) reminderProv.loadReminders(),
      if (splitProv != null) splitProv.loadGroups(),
      AnnouncementService.instance.refresh(force: true),
    ]);
  }
}
