import 'package:shared_preferences/shared_preferences.dart';

enum StorageMode { local, cloud }

enum CloudBackupSchedule {
  onEveryChange,
  weekly,
  biweekly,
  monthly;

  String get storageValue {
    switch (this) {
      case CloudBackupSchedule.onEveryChange:
        return 'every_change';
      case CloudBackupSchedule.weekly:
        return 'weekly';
      case CloudBackupSchedule.biweekly:
        return 'biweekly';
      case CloudBackupSchedule.monthly:
        return 'monthly';
    }
  }

  String get label {
    switch (this) {
      case CloudBackupSchedule.onEveryChange:
        return 'On every change';
      case CloudBackupSchedule.weekly:
        return 'Weekly (Every 7 days)';
      case CloudBackupSchedule.biweekly:
        return 'Every 2 Weeks (14 days)';
      case CloudBackupSchedule.monthly:
        return 'Monthly (Every 30 days)';
    }
  }

  String get shortLabel {
    switch (this) {
      case CloudBackupSchedule.onEveryChange:
        return 'Real-time';
      case CloudBackupSchedule.weekly:
        return 'Weekly';
      case CloudBackupSchedule.biweekly:
        return '2 Weeks';
      case CloudBackupSchedule.monthly:
        return 'Monthly';
    }
  }

  Duration? get interval {
    switch (this) {
      case CloudBackupSchedule.onEveryChange:
        return null;
      case CloudBackupSchedule.weekly:
        return const Duration(days: 7);
      case CloudBackupSchedule.biweekly:
        return const Duration(days: 14);
      case CloudBackupSchedule.monthly:
        return const Duration(days: 30);
    }
  }

  static CloudBackupSchedule fromStorageValue(String? raw) {
    switch (raw) {
      case 'every_change':
        return CloudBackupSchedule.onEveryChange;
      case 'biweekly':
        return CloudBackupSchedule.biweekly;
      case 'monthly':
        return CloudBackupSchedule.monthly;
      case 'weekly':
      default:
        return CloudBackupSchedule.weekly;
    }
  }
}

/// Persists manual storage selection and personal-expense cloud backup metadata.
///
/// Cloud backup is strictly opt-in: [getMode] defaults to [StorageMode.local]
/// until the user explicitly chooses [StorageMode.cloud].
class StoragePreferenceService {
  static const String _modeKey = 'storage_mode_v1';
  static const String _chosenKey = 'storage_mode_has_chosen_v1';
  static const String _backupScheduleKey = 'personal_cloud_backup_schedule_v1';
  static const String _hydratedUserKey = 'personal_expenses_hydrated_uid_v1';
  static const String _lastBackupPrefix = 'personal_last_backup_at_';
  static const String _dirtyPrefix = 'personal_sync_dirty_';

  static Future<StorageMode> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_modeKey);
    return val == 'cloud' ? StorageMode.cloud : StorageMode.local;
  }

  static Future<void> setMode(StorageMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode == StorageMode.cloud ? 'cloud' : 'local');
    await prefs.setBool(_chosenKey, true);
  }

  static Future<bool> isCloud() async {
    return (await getMode()) == StorageMode.cloud;
  }

  static Future<bool> hasChosenMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chosenKey) ?? false;
  }

  static Future<void> resetChoice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chosenKey);
  }

  static Future<CloudBackupSchedule> getBackupSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    return CloudBackupSchedule.fromStorageValue(
      prefs.getString(_backupScheduleKey),
    );
  }

  static Future<void> setBackupSchedule(CloudBackupSchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backupScheduleKey, schedule.storageValue);
  }

  static Future<String?> getHydratedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_hydratedUserKey);
  }

  static Future<bool> isUserHydrated(String userId) async {
    if (userId.isEmpty) return false;
    final hydratedUid = await getHydratedUserId();
    return hydratedUid == userId;
  }

  static Future<void> setHydratedUserId(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId == null || userId.isEmpty) {
      await prefs.remove(_hydratedUserKey);
    } else {
      await prefs.setString(_hydratedUserKey, userId);
    }
  }

  static Future<DateTime?> getLastBackupAt(String userId) async {
    if (userId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('$_lastBackupPrefix$userId');
    if (ms == null || ms <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> setLastBackupAt(String userId, DateTime time) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_lastBackupPrefix$userId', time.millisecondsSinceEpoch);
  }

  static Future<bool> isBackupDirty(String userId) async {
    if (userId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_dirtyPrefix$userId') ?? false;
  }

  static Future<void> setBackupDirty(String userId, bool dirty) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_dirtyPrefix$userId', dirty);
  }

  /// Pure helper used by scheduler and unit tests to decide if a periodic backup is due.
  static bool isScheduledBackupDue({
    required CloudBackupSchedule schedule,
    required DateTime? lastBackupAt,
    required bool hasPendingChanges,
    DateTime? now,
  }) {
    final interval = schedule.interval;
    if (interval == null) return false;
    if (!hasPendingChanges && lastBackupAt != null) return false;
    if (lastBackupAt == null) return hasPendingChanges;
    final currentTime = now ?? DateTime.now();
    return currentTime.difference(lastBackupAt) >= interval;
  }

  /// Clears user-scoped sync flags on sign-out without deleting cloud records.
  static Future<void> clearSyncStateOnSignOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hydratedUserKey);
    await prefs.remove(_chosenKey);
    await prefs.setString(_modeKey, 'local');
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_lastBackupPrefix) || key.startsWith(_dirtyPrefix)) {
        await prefs.remove(key);
      }
    }
  }
}
