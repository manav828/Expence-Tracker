import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';
import '../core/errors/error_handler.dart';
import 'storage_preference_service.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  static const String _onboardingKey = 'has_completed_onboarding_v1';
  static const String _guestKey = 'is_guest_mode_v1';
  static const String _userNameKey = 'user_display_name_cached';
  static const String _userPhotoKey = 'user_photo_url_cached';

  // Google OAuth Client IDs configured via AppConfig / --dart-define
  static String get _webClientId => AppConfig.googleWebClientId;
  static String get androidClientId => AppConfig.googleAndroidClientId;
  static String get _iosClientId => AppConfig.googleIosClientId;

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser {
    try {
      return _client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isAuthenticated {
    try {
      return currentUser != null;
    } catch (_) {
      return false;
    }
  }

  String? _cachedDisplayName;
  String? _cachedPhotoUrl;

  Future<void> initUserCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedDisplayName = prefs.getString(_userNameKey);
      _cachedPhotoUrl = prefs.getString(_userPhotoKey);
    } catch (_) {}
  }

  String? get userAvatarUrl {
    final meta = currentUser?.userMetadata;
    final url = (meta?['avatar_url'] ?? meta?['picture']) as String?;
    if (url != null && url.isNotEmpty) return url;
    return _cachedPhotoUrl;
  }

  String get userDisplayName {
    final meta = currentUser?.userMetadata;
    final name = (meta?['full_name'] ?? meta?['name']) as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    if (_cachedDisplayName != null && _cachedDisplayName!.trim().isNotEmpty) {
      return _cachedDisplayName!.trim();
    }
    final email = currentUser?.email;
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'Guest User';
  }

  String get userInitial {
    final name = userDisplayName.trim();
    if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return 'U';
  }

  String get userEmail {
    return currentUser?.email ?? 'Offline Mode (Local Storage)';
  }

  bool get isGoogleUser {
    final meta = currentUser?.appMetadata;
    if (meta != null && meta['provider'] == 'google') return true;
    final identities = currentUser?.identities;
    if (identities != null && identities.any((i) => i.provider == 'google')) {
      return true;
    }
    final avatar = userAvatarUrl;
    if (avatar != null && avatar.contains('googleusercontent')) {
      return true;
    }
    return false;
  }

  Future<bool> isGuest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_guestKey) ?? false;
  }

  Future<void> setGuestMode(bool isGuest) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestKey, isGuest);
  }

  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await setGuestMode(false);
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    await StoragePreferenceService.setMode(StorageMode.cloud);
    return response;
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await setGuestMode(false);
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
    );
    await StoragePreferenceService.setMode(StorageMode.cloud);

    try {
      _cachedDisplayName = fullName.trim();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userNameKey, fullName.trim());
    } catch (_) {}

    return response;
  }

  /// Native In-App Google Sign-In:
  /// - On Web: Uses OAuth flow (`signInWithOAuth`), redirecting cleanly via Google
  /// - On Mobile (Android/iOS): Uses native Google Play Services bottom sheet (`GoogleSignIn` + `signInWithIdToken`)
  Future<dynamic> signInWithGoogle() async {
    try {
      await setGuestMode(false);

      if (kIsWeb) {
        await StoragePreferenceService.setMode(StorageMode.cloud);
        final code = Uri.base.queryParameters['code'] ??
            Uri.base.queryParameters['join'] ??
            Uri.base.queryParameters['split'];
        if (code != null && code.trim().isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pending_invite_code', code.trim().toUpperCase());
        }
        final redirectUri = Uri.base.origin;
        return await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectUri,
        );
      }

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: _webClientId,
        clientId: defaultTargetPlatform == TargetPlatform.iOS ? _iosClientId : null,
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Sign-in cancelled');
      }

      // Cache Google profile photo and name immediately
      try {
        final prefs = await SharedPreferences.getInstance();
        if (googleUser.displayName != null && googleUser.displayName!.isNotEmpty) {
          _cachedDisplayName = googleUser.displayName;
          await prefs.setString(_userNameKey, googleUser.displayName!);
        }
        if (googleUser.photoUrl != null && googleUser.photoUrl!.isNotEmpty) {
          _cachedPhotoUrl = googleUser.photoUrl;
          await prefs.setString(_userPhotoKey, googleUser.photoUrl!);
        }
      } catch (_) {}

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception(
          'Google Sign-In failed to authenticate. Please check your network and try again.',
        );
      }

      final res = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      await StoragePreferenceService.setMode(StorageMode.cloud);
      return res;
    } catch (e, st) {
      ErrorHandler.log('AuthService.signInWithGoogle', e, st);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e, st) {
      ErrorHandler.log('AuthService.signOut.supabase', e, st);
    }
    if (!kIsWeb) {
      try {
        final googleSignIn = GoogleSignIn();
        if (await googleSignIn.isSignedIn()) {
          await googleSignIn.signOut();
        }
      } catch (e, st) {
        ErrorHandler.log('AuthService.signOut.google', e, st);
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userNameKey);
      await prefs.remove(_userPhotoKey);
      _cachedDisplayName = null;
      _cachedPhotoUrl = null;
    } catch (_) {}

    await setGuestMode(false);
    await StoragePreferenceService.setMode(StorageMode.local);
  }
}
