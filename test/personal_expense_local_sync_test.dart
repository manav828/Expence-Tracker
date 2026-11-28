import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/services/storage_preference_service.dart';
import 'package:expense_tracker/utils/expense_sync_reconciler.dart';
import 'package:expense_tracker/widgets/storage_choice_dialog.dart';

Expense _exp({
  int? id,
  required int createdAt,
  required int updatedAt,
  double amount = 100.0,
  String comment = 'Coffee',
}) {
  return Expense(
    id: id,
    userId: 'user_1',
    amount: amount,
    category: 'Food & Dining',
    paymentMethod: 'UPI',
    comment: comment,
    expenseDate: createdAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StoragePreferenceService & Manual Cloud Opt-In Tests', () {
    test('Defaults to Local Storage (never auto-selects cloud)', () async {
      expect(await StoragePreferenceService.getMode(), StorageMode.local);
      expect(await StoragePreferenceService.isCloud(), isFalse);
      expect(await StoragePreferenceService.hasChosenMode(), isFalse);
      expect(
        await StoragePreferenceService.getBackupSchedule(),
        CloudBackupSchedule.weekly,
      );
    });

    test('clearSyncStateOnSignOut resets cloud opt-in, hydration, and dirty flags', () async {
      await StoragePreferenceService.setMode(StorageMode.cloud);
      await StoragePreferenceService.setBackupSchedule(CloudBackupSchedule.biweekly);
      await StoragePreferenceService.setHydratedUserId('user_1');
      await StoragePreferenceService.setBackupDirty('user_1', true);
      await StoragePreferenceService.setLastBackupAt('user_1', DateTime(2026, 11, 20));

      expect(await StoragePreferenceService.isCloud(), isTrue);
      expect(await StoragePreferenceService.isUserHydrated('user_1'), isTrue);
      expect(await StoragePreferenceService.isBackupDirty('user_1'), isTrue);

      await StoragePreferenceService.clearSyncStateOnSignOut();

      expect(await StoragePreferenceService.getMode(), StorageMode.local);
      expect(await StoragePreferenceService.hasChosenMode(), isFalse);
      expect(await StoragePreferenceService.isUserHydrated('user_1'), isFalse);
      expect(await StoragePreferenceService.isBackupDirty('user_1'), isFalse);
      expect(await StoragePreferenceService.getLastBackupAt('user_1'), isNull);
    });

    test('Weekly, 2-Weekly, and Monthly scheduled backup triggers accurately only when due with changes', () {
      final t0 = DateTime(2026, 11, 1, 10, 0);

      // Weekly (7d): not due at 6 days, skipped at 8 days if clean, due at 7+ days if dirty
      expect(
        StoragePreferenceService.isScheduledBackupDue(
          schedule: CloudBackupSchedule.weekly,
          lastBackupAt: t0,
          hasPendingChanges: true,
          now: t0.add(const Duration(days: 6)),
        ),
        isFalse,
      );
      expect(
        StoragePreferenceService.isScheduledBackupDue(
          schedule: CloudBackupSchedule.weekly,
          lastBackupAt: t0,
          hasPendingChanges: false,
          now: t0.add(const Duration(days: 8)),
        ),
        isFalse,
      );
      expect(
        StoragePreferenceService.isScheduledBackupDue(
          schedule: CloudBackupSchedule.weekly,
          lastBackupAt: t0,
          hasPendingChanges: true,
          now: t0.add(const Duration(days: 7)),
        ),
        isTrue,
      );

      // Every 2 Weeks (14d)
      expect(
        StoragePreferenceService.isScheduledBackupDue(
          schedule: CloudBackupSchedule.biweekly,
          lastBackupAt: t0,
          hasPendingChanges: true,
          now: t0.add(const Duration(days: 13)),
        ),
        isFalse,
      );
      expect(
        StoragePreferenceService.isScheduledBackupDue(
          schedule: CloudBackupSchedule.biweekly,
          lastBackupAt: t0,
          hasPendingChanges: true,
          now: t0.add(const Duration(days: 14)),
        ),
        isTrue,
      );

      // Monthly (30d)
      expect(
        StoragePreferenceService.isScheduledBackupDue(
          schedule: CloudBackupSchedule.monthly,
          lastBackupAt: t0,
          hasPendingChanges: true,
          now: t0.add(const Duration(days: 29)),
        ),
        isFalse,
      );
      expect(
        StoragePreferenceService.isScheduledBackupDue(
          schedule: CloudBackupSchedule.monthly,
          lastBackupAt: t0,
          hasPendingChanges: true,
          now: t0.add(const Duration(days: 30)),
        ),
        isTrue,
      );
    });
  });

  group('ExpenseSyncReconciler Conflict & Delete Tombstone Safety Tests', () {
    test('Local delete tombstone prevents cloud copy resurrection and queues cloud delete', () {
      final cloudStale = _exp(id: 50, createdAt: 1000, updatedAt: 1200, amount: 250);
      const tombstone = ExpenseDeleteTombstone(
        createdAt: 1000,
        cloudId: 50,
        userId: 'user_1',
        deletedAt: 1500, // Deleted after cloud's last update
      );

      final plan = ExpenseSyncReconciler.plan(
        localExpenses: const [],
        cloudExpenses: [cloudStale],
        tombstones: const [tombstone],
        allowCloudPull: true,
      );

      expect(plan.cloudDeletes.map((t) => t.createdAt), [1000]);
      expect(plan.toInsertLocally, isEmpty);
      expect(plan.resolvedExpenses, isEmpty);
      expect(plan.tombstoneCreatedAtsToClear, isEmpty); // Keeps tombstone until cloud confirms delete
    });

    test('Newer edit on another device after local delete preserves the newer record', () {
      final cloudNewer = _exp(id: 50, createdAt: 1000, updatedAt: 2000, amount: 400);
      const staleTombstone = ExpenseDeleteTombstone(
        createdAt: 1000,
        cloudId: 50,
        userId: 'user_1',
        deletedAt: 1500,
      );

      final plan = ExpenseSyncReconciler.plan(
        localExpenses: const [],
        cloudExpenses: [cloudNewer],
        tombstones: const [staleTombstone],
        allowCloudPull: true,
      );

      expect(plan.cloudDeletes, isEmpty);
      expect(plan.tombstoneCreatedAtsToClear, [1000]);
      expect(plan.toInsertLocally, hasLength(1));
      expect(plan.resolvedExpenses.single.amount, 400.0);
    });

    test('Newer updatedAt timestamp always wins in both directions (no stale overwrite)', () {
      // Case A: local edited offline more recently -> updates cloud
      final localNewer = _exp(id: 1, createdAt: 1000, updatedAt: 3000, amount: 900, comment: 'Edited locally');
      final cloudOlder = _exp(id: 99, createdAt: 1000, updatedAt: 2000, amount: 500, comment: 'Old cloud');

      // Case B: cloud edited from 2nd device more recently -> updates local
      final localOlder = _exp(id: 2, createdAt: 2000, updatedAt: 2000, amount: 120, comment: 'Old local');
      final cloudNewer = _exp(id: 105, createdAt: 2000, updatedAt: 4000, amount: 180, comment: 'Edited on 2nd device');

      final plan = ExpenseSyncReconciler.plan(
        localExpenses: [localNewer, localOlder],
        cloudExpenses: [cloudOlder, cloudNewer],
        tombstones: const [],
      );

      expect(plan.toUpdateInCloud, hasLength(1));
      expect(plan.toUpdateInCloud.single.amount, 900.0);
      expect(plan.toUpdateInCloud.single.id, 99);

      expect(plan.toUpdateLocally, hasLength(1));
      expect(plan.toUpdateLocally.single.amount, 180.0);

      expect(plan.resolvedExpenses.map((e) => e.amount).toSet(), {900.0, 180.0});
    });

    test('Fresh device with empty local cache hydrates safely from cloud without deleting anything', () {
      final cloudA = _exp(id: 10, createdAt: 1000, updatedAt: 1000, amount: 500);
      final cloudB = _exp(id: 11, createdAt: 2000, updatedAt: 2000, amount: 800);

      final plan = ExpenseSyncReconciler.plan(
        localExpenses: const [],
        cloudExpenses: [cloudA, cloudB],
        tombstones: const [],
        allowCloudPull: true,
      );

      expect(plan.cloudDeletes, isEmpty);
      expect(plan.toUploadToCloud, isEmpty);
      expect(plan.toInsertLocally, hasLength(2));
      expect(plan.resolvedExpenses, hasLength(2));
    });
  });

  group('StorageChoiceDialog Backup Frequency UI Tests', () {
    testWidgets('Selecting Cloud Storage reveals Weekly / 2 Weeks / Monthly / Real-time schedule chips', (tester) async {
      final provider = ExpenseProvider(autoFetch: false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ExpenseProvider>.value(
            value: provider,
            child: const Scaffold(
              body: StorageChoiceDialog(isDismissible: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Defaults to Local Storage (no cloud chips until Cloud Storage is tapped)
      expect(find.text('Backup Frequency'), findsNothing);

      await tester.tap(find.text('Cloud Storage'));
      await tester.pumpAndSettle();

      expect(find.text('Backup Frequency'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('2 Weeks'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Real-time'), findsOneWidget);
    });
  });
}
