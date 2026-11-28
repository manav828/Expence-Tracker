import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import 'auth_service.dart';

/// Fetches optional promotional / update announcements from Supabase (`app_notifications`)
/// and persists local read/dismiss state per user.
class AnnouncementService extends ChangeNotifier {
  static final AnnouncementService instance = AnnouncementService._();
  AnnouncementService._();

  static const String _dismissedPrefix = 'announcement_dismissed_ids_';

  List<AppAnnouncement> _announcements = [];
  Set<String> _dismissedIds = {};
  bool _isLoading = false;
  DateTime? _lastFetchAt;

  List<AppAnnouncement> get activeAnnouncements {
    final now = DateTime.now();
    return _announcements
        .where((a) => !_dismissedIds.contains(a.id) && a.isVisibleAt(now))
        .toList();
  }

  int get unreadCount => activeAnnouncements.length;
  bool get isLoading => _isLoading;

  String get _prefsKey {
    final uid = AuthService.instance.currentUser?.id ?? 'guest';
    return '$_dismissedPrefix$uid';
  }

  @visibleForTesting
  void setAnnouncementsForTesting(
    List<AppAnnouncement> list, {
    Set<String> dismissedIds = const {},
  }) {
    _announcements = List.from(list);
    _dismissedIds = Set.from(dismissedIds);
    notifyListeners();
  }

  Future<void> loadDismissedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? const [];
      _dismissedIds = list.toSet();
      notifyListeners();
    } catch (_) {}
  }

  /// Fetches active announcements from Supabase (max once per 15 min unless forced).
  Future<void> refresh({bool force = false}) async {
    await loadDismissedIds();

    final last = _lastFetchAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 15)) {
      return;
    }

    SupabaseClient? client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final res = await client
          .from('app_notifications')
          .select()
          .eq('is_active', true)
          .lte('starts_at', nowIso)
          .order('created_at', ascending: false)
          .limit(20);

      _announcements = (res as List)
          .map((row) => AppAnnouncement.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();
      _lastFetchAt = DateTime.now();
    } catch (e) {
      debugPrint('AnnouncementService.refresh skipped/error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> dismissAnnouncement(String id) async {
    _dismissedIds.add(id);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _dismissedIds.toList());
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    for (final item in activeAnnouncements) {
      _dismissedIds.add(item.id);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _dismissedIds.toList());
    } catch (_) {}
  }

  void clearStateOnLogout() {
    _dismissedIds = {};
    _lastFetchAt = null;
    notifyListeners();
  }
}
