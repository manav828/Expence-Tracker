import 'package:shared_preferences/shared_preferences.dart';

/// Manages personal photo likes locally on the device via SharedPreferences.
/// Likes never touch the cloud/server, ensuring 100% privacy, zero latency,
/// and zero database row overhead.
class TripPhotoLocalLikesService {
  static final TripPhotoLocalLikesService instance = TripPhotoLocalLikesService._();
  TripPhotoLocalLikesService._();

  static const String _prefPrefix = 'expencircle_trip_vault_likes_';

  String _getKey(String groupId) => '$_prefPrefix$groupId';

  /// Retrieves the set of photo IDs liked by the user for the given group.
  Future<Set<String>> getLikedPhotoIds(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_getKey(groupId)) ?? <String>[];
    return list.toSet();
  }

  /// Checks if a photo is liked.
  Future<bool> isPhotoLiked(String groupId, String photoId) async {
    final liked = await getLikedPhotoIds(groupId);
    return liked.contains(photoId);
  }

  /// Toggles like state for a photo. Returns true if now liked, false if unliked.
  Future<bool> toggleLike(String groupId, String photoId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey(groupId);
    final list = prefs.getStringList(key) ?? <String>[];
    final set = list.toSet();

    final bool isNowLiked;
    if (set.contains(photoId)) {
      set.remove(photoId);
      isNowLiked = false;
    } else {
      set.add(photoId);
      isNowLiked = true;
    }

    await prefs.setStringList(key, set.toList());
    return isNowLiked;
  }

  /// Clears local likes for an expired or deleted group.
  Future<void> clearGroupLikes(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getKey(groupId));
  }
}
