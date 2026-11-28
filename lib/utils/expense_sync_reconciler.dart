import '../models/expense.dart';

/// Represents a locally deleted personal expense waiting to be removed from cloud.
class ExpenseDeleteTombstone {
  final int createdAt;
  final int? cloudId;
  final String? userId;
  final int deletedAt;

  const ExpenseDeleteTombstone({
    required this.createdAt,
    this.cloudId,
    this.userId,
    required this.deletedAt,
  });

  factory ExpenseDeleteTombstone.fromMap(Map<String, dynamic> map) {
    return ExpenseDeleteTombstone(
      createdAt: (map['created_at'] as num).toInt(),
      cloudId: (map['cloud_id'] as num?)?.toInt(),
      userId: map['user_id'] as String?,
      deletedAt: (map['deleted_at'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'created_at': createdAt,
      'cloud_id': cloudId,
      'user_id': userId,
      'deleted_at': deletedAt,
    };
  }
}

/// Output of a conflict-free 3-way personal expense reconciliation pass.
class ExpenseReconcilePlan {
  final List<Expense> toUploadToCloud;
  final List<Expense> toUpdateInCloud;
  final List<ExpenseDeleteTombstone> cloudDeletes;
  final List<int> tombstoneCreatedAtsToClear;
  final List<Expense> toInsertLocally;
  final List<Expense> toUpdateLocally;
  final List<Expense> localIdAlignments;
  final List<Expense> resolvedExpenses;

  const ExpenseReconcilePlan({
    required this.toUploadToCloud,
    required this.toUpdateInCloud,
    required this.cloudDeletes,
    required this.tombstoneCreatedAtsToClear,
    required this.toInsertLocally,
    required this.toUpdateLocally,
    required this.localIdAlignments,
    required this.resolvedExpenses,
  });
}

/// Pure 3-way reconciler preventing stale overwrites and resurrected deletes
/// between local SQLite personal expenses and Supabase `user_expenses`.
class ExpenseSyncReconciler {
  ExpenseSyncReconciler._();

  static ExpenseReconcilePlan plan({
    required List<Expense> localExpenses,
    required List<Expense> cloudExpenses,
    required List<ExpenseDeleteTombstone> tombstones,
    bool allowCloudPull = true,
  }) {
    final localByKey = <int, Expense>{};
    for (final exp in localExpenses) {
      final existing = localByKey[exp.createdAt];
      if (existing == null || exp.updatedAt >= existing.updatedAt) {
        localByKey[exp.createdAt] = exp;
      }
    }

    final cloudByKey = <int, Expense>{};
    for (final exp in cloudExpenses) {
      final existing = cloudByKey[exp.createdAt];
      if (existing == null || exp.updatedAt >= existing.updatedAt) {
        cloudByKey[exp.createdAt] = exp;
      }
    }

    final activeDeleteKeys = <int>{};
    final cloudDeletes = <ExpenseDeleteTombstone>[];
    final tombstoneCreatedAtsToClear = <int>[];

    // 1. Resolve delete tombstones first so deleted records never resurrect.
    for (final tomb in tombstones) {
      final cloudMatch = cloudByKey[tomb.createdAt];
      if (cloudMatch == null) {
        // Already absent in cloud -> safe to clean up local tombstone.
        tombstoneCreatedAtsToClear.add(tomb.createdAt);
      } else if (tomb.deletedAt >= cloudMatch.updatedAt) {
        // Local delete happened at or after cloud's last update -> delete in cloud.
        cloudDeletes.add(tomb);
        activeDeleteKeys.add(tomb.createdAt);
      } else {
        // Another device edited this record *after* our delete -> preserve newer edit.
        tombstoneCreatedAtsToClear.add(tomb.createdAt);
      }
    }

    final toUploadToCloud = <Expense>[];
    final toUpdateInCloud = <Expense>[];
    final toInsertLocally = <Expense>[];
    final toUpdateLocally = <Expense>[];
    final localIdAlignments = <Expense>[];
    final resolvedByKey = <int, Expense>{};

    // 2. Reconcile local records against cloud copies.
    for (final entry in localByKey.entries) {
      final createdAt = entry.key;
      final local = entry.value;
      if (activeDeleteKeys.contains(createdAt)) continue;

      final cloud = cloudByKey[createdAt];
      if (cloud == null) {
        toUploadToCloud.add(local);
        resolvedByKey[createdAt] = local;
      } else if (local.updatedAt > cloud.updatedAt) {
        final merged = local.copyWith(id: cloud.id ?? local.id);
        toUpdateInCloud.add(merged);
        resolvedByKey[createdAt] = merged;
      } else if (cloud.updatedAt > local.updatedAt) {
        toUpdateLocally.add(cloud);
        resolvedByKey[createdAt] = cloud;
      } else {
        // Identical updatedAt: keep synced copy and align local cloud ID if needed.
        if (cloud.id != null && local.id != cloud.id) {
          localIdAlignments.add(cloud);
          resolvedByKey[createdAt] = cloud;
        } else {
          resolvedByKey[createdAt] = local;
        }
      }
    }

    // 3. Bring down cloud-only entries that weren't deleted locally.
    for (final entry in cloudByKey.entries) {
      final createdAt = entry.key;
      if (localByKey.containsKey(createdAt) ||
          activeDeleteKeys.contains(createdAt)) {
        continue;
      }
      final cloud = entry.value;
      if (allowCloudPull) {
        toInsertLocally.add(cloud);
        resolvedByKey[createdAt] = cloud;
      }
    }

    final resolvedExpenses = resolvedByKey.values.toList()
      ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

    return ExpenseReconcilePlan(
      toUploadToCloud: toUploadToCloud,
      toUpdateInCloud: toUpdateInCloud,
      cloudDeletes: cloudDeletes,
      tombstoneCreatedAtsToClear: tombstoneCreatedAtsToClear,
      toInsertLocally: toInsertLocally,
      toUpdateLocally: toUpdateLocally,
      localIdAlignments: localIdAlignments,
      resolvedExpenses: resolvedExpenses,
    );
  }
}
