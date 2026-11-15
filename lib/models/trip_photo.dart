// Model for Ephemeral 48-Hour Trip Photo Vault
class TripPhoto {
  final String id;
  final String groupId;
  final String uploaderId;
  final String uploaderName;
  final String photoUrl;
  final String? thumbnailUrl;
  final String? storagePath;
  final int fileSizeBytes;
  final int? width;
  final int? height;
  final DateTime createdAt;
  final DateTime expiresAt;

  TripPhoto({
    required this.id,
    required this.groupId,
    required this.uploaderId,
    required this.uploaderName,
    required this.photoUrl,
    this.thumbnailUrl,
    this.storagePath,
    this.fileSizeBytes = 0,
    this.width,
    this.height,
    required this.createdAt,
    required this.expiresAt,
  });

  /// True if 48-hour expiration has passed.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Duration until auto-deletion.
  Duration get remainingTime {
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// True when less than 6 hours remain before auto-deletion.
  bool get isUrgent => remainingTime.inHours < 6;

  /// Human-readable remaining time (e.g. "34h 18m left" or "Expired").
  String get formattedRemainingTime {
    final rem = remainingTime;
    if (rem == Duration.zero) return 'Expired';
    final hours = rem.inHours;
    final minutes = rem.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m left';
    }
    return '${minutes}m left';
  }

  /// Human-readable file size (e.g. "1.8 MB", "840 KB").
  String get formattedFileSize {
    if (fileSizeBytes <= 0) return '';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'group_id': groupId,
        'uploader_id': uploaderId,
        'uploader_name': uploaderName,
        'photo_url': photoUrl,
        'thumbnail_url': thumbnailUrl,
        'storage_path': storagePath,
        'file_size_bytes': fileSizeBytes,
        'width': width,
        'height': height,
        'created_at': createdAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      };

  factory TripPhoto.fromMap(Map<String, dynamic> m) {
    return TripPhoto(
      id: m['id'] as String,
      groupId: m['group_id'] as String,
      uploaderId: m['uploader_id'] as String? ?? '',
      uploaderName: m['uploader_name'] as String? ?? 'Member',
      photoUrl: m['photo_url'] as String,
      thumbnailUrl: m['thumbnail_url'] as String?,
      storagePath: m['storage_path'] as String?,
      fileSizeBytes: (m['file_size_bytes'] as num?)?.toInt() ?? 0,
      width: (m['width'] as num?)?.toInt(),
      height: (m['height'] as num?)?.toInt(),
      createdAt: m['created_at'] != null
          ? DateTime.parse(m['created_at'] as String)
          : DateTime.now(),
      expiresAt: m['expires_at'] != null
          ? DateTime.parse(m['expires_at'] as String)
          : DateTime.now().add(const Duration(hours: 48)),
    );
  }

  TripPhoto copyWith({
    String? id,
    String? groupId,
    String? uploaderId,
    String? uploaderName,
    String? photoUrl,
    String? thumbnailUrl,
    String? storagePath,
    int? fileSizeBytes,
    int? width,
    int? height,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return TripPhoto(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      uploaderId: uploaderId ?? this.uploaderId,
      uploaderName: uploaderName ?? this.uploaderName,
      photoUrl: photoUrl ?? this.photoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      storagePath: storagePath ?? this.storagePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
