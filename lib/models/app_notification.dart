/// Categories for promotional, product update, and tip messages stored in Supabase `app_notifications`.
enum AnnouncementCategory {
  promo,
  update,
  tip;

  static AnnouncementCategory fromString(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'update':
        return AnnouncementCategory.update;
      case 'tip':
        return AnnouncementCategory.tip;
      case 'promo':
      default:
        return AnnouncementCategory.promo;
    }
  }
}

/// Remote announcement / promotional message fetched from Supabase `app_notifications`.
class AppAnnouncement {
  final String id;
  final String title;
  final String message;
  final AnnouncementCategory category;
  final String? ctaLabel;
  final String? ctaRoute;
  final DateTime startsAt;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const AppAnnouncement({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    this.ctaLabel,
    this.ctaRoute,
    required this.startsAt,
    this.expiresAt,
    required this.createdAt,
  });

  bool isVisibleAt(DateTime now) {
    if (now.isBefore(startsAt)) return false;
    if (expiresAt != null && !now.isBefore(expiresAt!)) return false;
    return true;
  }

  factory AppAnnouncement.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw, {DateTime? fallback}) {
      if (raw is DateTime) return raw;
      if (raw is String && raw.isNotEmpty) {
        return DateTime.tryParse(raw) ?? (fallback ?? DateTime.now());
      }
      if (raw is num) {
        return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
      }
      return fallback ?? DateTime.now();
    }

    return AppAnnouncement(
      id: map['id'].toString(),
      title: (map['title'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      category: AnnouncementCategory.fromString(map['category']?.toString()),
      ctaLabel: map['cta_label']?.toString(),
      ctaRoute: map['cta_route']?.toString(),
      startsAt: parseDate(map['starts_at']),
      expiresAt: map['expires_at'] != null ? parseDate(map['expires_at']) : null,
      createdAt: parseDate(map['created_at']),
    );
  }
}
