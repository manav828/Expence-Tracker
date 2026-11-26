import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/split/split_group_detail_screen.dart';
import 'split_service.dart';

/// Top-level background FCM handler required by firebase_messaging.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[PushNotificationService] background init error: $e');
  }
}

/// Manages Firebase Cloud Messaging (FCM) initialization, token sync with
/// Supabase (`user_device_tokens`), foreground display, and notification taps.
class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._();
  PushNotificationService._();

  static const MethodChannel _pushChannel = MethodChannel('com.manav.expense/push_notifications');

  bool _initialized = false;
  String? _currentToken;
  GlobalKey<NavigatorState>? _navigatorKey;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;

  bool get _isSupportedMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Initializes Firebase and FCM listeners on supported mobile platforms.
  Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    _navigatorKey = navigatorKey ?? _navigatorKey;
    if (_initialized || !_isSupportedMobilePlatform) return;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      _onMessageSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
      // FCM HTTP v1 `message.token` requires the FCM registration token (not FID).
      // ignore: deprecated_member_use
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _currentToken = token;
        unawaited(_upsertToken(token));
      });

      final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMsg != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_handleMessageTap(initialMsg));
        });
      }

      _initialized = true;
    } catch (e) {
      debugPrint('[PushNotificationService] initialize error: $e');
    }
  }

  /// Requests notification permission and stores the device's FCM token in Supabase
  /// for the currently signed-in user.
  Future<void> syncDeviceToken() async {
    if (!_isSupportedMobilePlatform) return;
    if (!_initialized) {
      await initialize(navigatorKey: _navigatorKey);
    }
    if (!_initialized) return;

    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;

      _currentToken = token;
      await _upsertToken(token);
    } catch (e) {
      debugPrint('[PushNotificationService] syncDeviceToken error: $e');
    }
  }

  /// Removes this device's FCM token from Supabase before signing out so
  /// logged-out devices do not continue receiving notifications for this user.
  Future<void> removeCurrentDeviceToken() async {
    if (!_isSupportedMobilePlatform || !_initialized) return;

    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;

    try {
      // ignore: deprecated_member_use
      final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;

      await Supabase.instance.client
          .from('user_device_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('fcm_token', token);
      _currentToken = null;
    } catch (e) {
      debugPrint('[PushNotificationService] removeCurrentDeviceToken error: $e');
    }
  }

  String? get _currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _upsertToken(String token) async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty || token.trim().isEmpty) return;

    final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    try {
      await Supabase.instance.client.from('user_device_tokens').upsert(
        {
          'user_id': userId,
          'fcm_token': token,
          'platform': platform,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,fcm_token',
      );
    } catch (e) {
      debugPrint('[PushNotificationService] _upsertToken error: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'Payment Reminder';
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        'You have a pending split settlement.';

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _pushChannel.invokeMethod('showForegroundNotification', {
          'title': title,
          'body': body,
          'groupId': message.data['group_id']?.toString() ?? '',
        });
        return;
      } catch (e) {
        debugPrint('[PushNotificationService] foreground channel error: $e');
      }
    }

    final ctx = _navigatorKey?.currentContext;
    if (ctx != null && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('$title: $body'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleMessageTap(RemoteMessage message) async {
    final groupId = message.data['group_id']?.toString();
    if (groupId == null || groupId.isEmpty) return;

    final navState = _navigatorKey?.currentState;
    if (navState == null) return;

    try {
      final groups = await SplitService.instance.getGroupsByIds([groupId]);
      if (groups.isEmpty) return;

      await navState.push(
        MaterialPageRoute(
          builder: (_) => SplitGroupDetailScreen(
            group: groups.first,
            initialTabIndex: 1,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[PushNotificationService] _handleMessageTap navigation error: $e');
    }
  }

  @visibleForTesting
  Future<void> disposeForTesting() async {
    await _tokenRefreshSub?.cancel();
    await _onMessageSub?.cancel();
    await _onOpenedSub?.cancel();
    _tokenRefreshSub = null;
    _onMessageSub = null;
    _onOpenedSub = null;
    _initialized = false;
  }
}
