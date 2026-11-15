import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/trip_photo.dart';
import 'file_picker_service.dart';
import 'cloudflare_r2_service.dart';
import '../core/config/app_config.dart';

class TripPhotoService {
  static final TripPhotoService instance = TripPhotoService._();
  TripPhotoService._();

  static const _uuid = Uuid();
  static const String _bucketName = 'trip-vault-photos';

  /// Returns current Supabase client or null if not initialized.
  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Current authenticated user id, fallback to 'anonymous'.
  String get currentUserId {
    return _client?.auth.currentUser?.id ?? 'anonymous';
  }

  /// Fetches all active (unexpired) photos for a split group.
  Future<List<TripPhoto>> fetchGroupPhotos(String groupId) async {
    final client = _client;
    if (client == null) return <TripPhoto>[];

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final response = await client
          .from('split_group_photos')
          .select()
          .eq('group_id', groupId)
          .gt('expires_at', nowIso)
          .order('created_at', ascending: false);

      final list = (response as List<dynamic>)
          .map((row) => TripPhoto.fromMap(row as Map<String, dynamic>))
          .toList();
      return list;
    } catch (e) {
      debugPrint('Error fetching group photos for $groupId: $e');
      return <TripPhoto>[];
    }
  }

  /// Uploads a batch of photos in a single atomic database roundtrip.
  Future<List<TripPhoto>> uploadBatch({
    required String groupId,
    required String uploaderName,
    required List<PickedFileData> files,
    bool originalQuality = false,
  }) async {
    final client = _client;
    if (client == null || files.isEmpty) return <TripPhoto>[];

    final uploaderId = currentUserId;
    final List<Map<String, dynamic>> recordsToInsert = [];
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(const Duration(hours: 48));

    for (final file in files) {
      final photoId = _uuid.v4();
      final ext = file.extension.isNotEmpty ? file.extension : 'jpg';
      final fileName = '${now.millisecondsSinceEpoch}_$photoId.$ext';
      final storagePath = 'vaults/$groupId/$uploaderId/$fileName';

      String? photoUrl;

      // 1. Try Supabase Storage bucket first
      try {
        await client.storage.from(_bucketName).uploadBinary(
              storagePath,
              file.bytes,
              fileOptions: FileOptions(
                contentType: 'image/$ext',
                upsert: true,
              ),
            );
        photoUrl = client.storage.from(_bucketName).getPublicUrl(storagePath);
      } catch (storageError) {
        debugPrint('Supabase storage upload error: $storageError');

        // 2. Fallback to Cloudflare R2 if configured
        if (AppConfig.hasR2Configured) {
          photoUrl = await CloudflareR2Service.instance.uploadBytes(
            bytes: file.bytes,
            path: storagePath,
            contentType: 'image/$ext',
          );
        }
      }

      if (photoUrl != null && photoUrl.isNotEmpty) {
        recordsToInsert.add({
          'id': photoId,
          'group_id': groupId,
          'uploader_id': uploaderId,
          'uploader_name': uploaderName,
          'photo_url': photoUrl,
          'storage_path': storagePath,
          'file_size_bytes': file.bytes.length,
          'created_at': now.toIso8601String(),
          'expires_at': expiresAt.toIso8601String(),
        });
      }
    }

    if (recordsToInsert.isEmpty) return <TripPhoto>[];

    try {
      // Single bulk insert into Supabase
      final inserted = await client
          .from('split_group_photos')
          .insert(recordsToInsert)
          .select();

      return (inserted as List<dynamic>)
          .map((row) => TripPhoto.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (dbError) {
      debugPrint('Error inserting photos to Supabase: $dbError');
      return <TripPhoto>[];
    }
  }

  /// Deletes a photo. Only the uploader is allowed to delete.
  Future<bool> deletePhoto(TripPhoto photo) async {
    final client = _client;
    if (client == null) return false;

    // Strict frontend permission check
    if (photo.uploaderId != currentUserId && currentUserId != 'anonymous') {
      debugPrint('Unauthorized: Only the uploader can delete this photo');
      return false;
    }

    try {
      // 1. Delete from database
      await client
          .from('split_group_photos')
          .delete()
          .eq('id', photo.id);

      // 2. Clean up from storage bucket
      if (photo.storagePath != null && photo.storagePath!.isNotEmpty) {
        try {
          await client.storage.from(_bucketName).remove([photo.storagePath!]);
        } catch (_) {}
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting photo: $e');
      return false;
    }
  }
}
