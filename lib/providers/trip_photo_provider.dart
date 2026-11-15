import 'package:flutter/material.dart';
import '../models/trip_photo.dart';
import '../services/trip_photo_service.dart';
import '../services/trip_photo_local_likes_service.dart';
import '../services/file_picker_service.dart';
import '../services/photo_download_helper.dart';

class TripPhotoProvider with ChangeNotifier {
  List<TripPhoto> _photos = [];
  Set<String> _likedPhotoIds = {};
  String _selectedFilter = 'all'; // 'all', 'liked', or specific uploaderId
  bool _isLoading = false;
  bool _isUploading = false;
  String? _errorMessage;

  List<TripPhoto> get allPhotos => List.unmodifiable(_photos);
  Set<String> get likedPhotoIds => Set.unmodifiable(_likedPhotoIds);
  String get selectedFilter => _selectedFilter;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get errorMessage => _errorMessage;

  int get totalCount => _photos.length;
  int get likedCount => _photos.where((p) => _likedPhotoIds.contains(p.id)).length;
  int get totalSizeBytes => _photos.fold(0, (sum, p) => sum + p.fileSizeBytes);

  /// Human-readable total storage string (e.g. "184 MB / 1.0 GB").
  String get formattedStorageUsage {
    final mb = totalSizeBytes / (1024 * 1024);
    if (mb < 1.0) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(0)} KB / 1.0 GB';
    }
    return '${mb.toStringAsFixed(1)} MB / 1.0 GB';
  }

  /// Earliest remaining duration before the oldest active batch expires.
  Duration? get earliestExpiration {
    if (_photos.isEmpty) return null;
    Duration? minDuration;
    for (final p in _photos) {
      final rem = p.remainingTime;
      if (minDuration == null || rem < minDuration) {
        minDuration = rem;
      }
    }
    return minDuration;
  }

  /// Filtered list based on active tab: 'all', 'liked', or specific uploader.
  List<TripPhoto> get filteredPhotos {
    if (_selectedFilter == 'liked') {
      return _photos.where((p) => _likedPhotoIds.contains(p.id)).toList();
    } else if (_selectedFilter != 'all') {
      return _photos.where((p) => p.uploaderId == _selectedFilter).toList();
    }
    return _photos;
  }

  /// Map of uploaderId -> photo count
  Map<String, int> get contributorCounts {
    final Map<String, int> counts = {};
    for (final p in _photos) {
      counts[p.uploaderId] = (counts[p.uploaderId] ?? 0) + 1;
    }
    return counts;
  }

  /// Map of uploaderId -> uploaderName
  Map<String, String> get contributorNames {
    final Map<String, String> names = {};
    for (final p in _photos) {
      names[p.uploaderId] = p.uploaderName;
    }
    return names;
  }

  bool isPhotoLiked(String photoId) => _likedPhotoIds.contains(photoId);

  void setFilter(String filter) {
    if (_selectedFilter != filter) {
      _selectedFilter = filter;
      notifyListeners();
    }
  }

  /// Loads photos from Supabase and personal likes from SharedPreferences.
  Future<void> loadPhotos(String groupId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final photosFuture = TripPhotoService.instance.fetchGroupPhotos(groupId);
      final likesFuture = TripPhotoLocalLikesService.instance.getLikedPhotoIds(groupId);

      final results = await Future.wait([photosFuture, likesFuture]);
      _photos = results[0] as List<TripPhoto>;
      _likedPhotoIds = results[1] as Set<String>;
    } catch (e) {
      _errorMessage = 'Failed to load trip photos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggles personal like locally. 100% private.
  Future<void> toggleLike(String groupId, String photoId) async {
    final isLiked = await TripPhotoLocalLikesService.instance.toggleLike(groupId, photoId);
    if (isLiked) {
      _likedPhotoIds.add(photoId);
    } else {
      _likedPhotoIds.remove(photoId);
    }
    notifyListeners();
  }

  /// Uploads photos via single bulk insert roundtrip.
  Future<bool> uploadPhotos({
    required String groupId,
    required String uploaderName,
    required List<PickedFileData> files,
    bool originalQuality = false,
  }) async {
    if (files.isEmpty) return false;
    _isUploading = true;
    notifyListeners();

    try {
      final newPhotos = await TripPhotoService.instance.uploadBatch(
        groupId: groupId,
        uploaderName: uploaderName,
        files: files,
        originalQuality: originalQuality,
      );

      if (newPhotos.isNotEmpty) {
        _photos.insertAll(0, newPhotos);
        _photos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Failed to upload photos: $e';
      return false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  /// Deletes a photo. Enforces owner-only permission.
  Future<bool> deletePhoto(TripPhoto photo) async {
    final success = await TripPhotoService.instance.deletePhoto(photo);
    if (success) {
      _photos.removeWhere((p) => p.id == photo.id);
      _likedPhotoIds.remove(photo.id);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Downloads all personal liked photos in one click.
  Future<int> downloadAllLikedPhotos(String groupName) async {
    final likedUrls = _photos
        .where((p) => _likedPhotoIds.contains(p.id))
        .map((p) => p.photoUrl)
        .toList();

    if (likedUrls.isEmpty) return 0;
    return await saveOrShareMultiplePhotos(
      urls: likedUrls,
      groupName: groupName,
    );
  }
}
