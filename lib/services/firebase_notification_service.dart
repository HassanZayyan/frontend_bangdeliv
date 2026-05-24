import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/app_routes.dart';
import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode) {
    debugPrint('[FCM] Background message: ${message.messageId}');
  }
}

class FirebaseNotificationService {
  FirebaseNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static bool _firebaseInitialized = false;
  static bool _notificationsInitialized = false;
  static String? _registeredToken;
  static int? _registeredUserId;
  static void Function(String route)? _openRoute;
  static Future<void> Function(String token)? _tokenRefreshHandler;
  static StreamSubscription<String>? _tokenRefreshSubscription;

  static Future<bool> initializeFirebase() async {
    if (_firebaseInitialized) {
      return true;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _firebaseInitialized = true;
      return true;
    } on UnsupportedError catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[FCM] Firebase is not configured for this platform: $error',
        );
      }
      return false;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[FCM] Failed to initialize Firebase: $error');
      }
      return false;
    }
  }

  static Future<void> initializeNotifications({
    void Function(String route)? onOpenRoute,
  }) async {
    if (onOpenRoute != null) {
      _openRoute = onOpenRoute;
    }

    if (_notificationsInitialized) {
      return;
    }

    final firebaseReady = await initializeFirebase();
    if (!firebaseReady) {
      return;
    }

    await _messaging.setAutoInitEnabled(true);

    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen((token) {
      _logToken(token, label: 'Refreshed token');
      unawaited(_tokenRefreshHandler?.call(token));
    });

    FirebaseMessaging.onMessage.listen((message) {
      if (!kDebugMode) {
        return;
      }

      final notification = message.notification;
      debugPrint(
        '[FCM] Foreground message: '
        '${notification?.title ?? message.messageId ?? 'no title'}',
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (kDebugMode) {
        debugPrint('[FCM] Notification opened: ${message.messageId}');
      }
      _openRouteFromMessage(message);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null && kDebugMode) {
      debugPrint('[FCM] Initial notification: ${initialMessage.messageId}');
    }
    if (initialMessage != null) {
      _openRouteFromMessage(initialMessage);
    }

    _notificationsInitialized = true;
  }

  static Future<void> syncTokenWithBackend({
    required int userId,
    required Future<void> Function(String token) registerToken,
  }) async {
    final firebaseReady = await initializeFirebase();
    if (!firebaseReady) {
      return;
    }

    await _requestNotificationPermission();

    _tokenRefreshHandler = (token) {
      return _registerTokenForUser(
        userId: userId,
        token: token,
        registerToken: registerToken,
      );
    };

    try {
      final token = await _messaging.getToken();
      _logToken(token, label: 'Current token');
      if (token == null || token.isEmpty) {
        return;
      }

      await _registerTokenForUser(
        userId: userId,
        token: token,
        registerToken: registerToken,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[FCM] Failed to sync token: $error');
      }
    }
  }

  static void clearBackendTokenSync() {
    _tokenRefreshHandler = null;
    _registeredToken = null;
    _registeredUserId = null;
  }

  static Future<void> unregisterCurrentToken({
    required Future<void> Function(String token) unregisterToken,
  }) async {
    try {
      final firebaseReady = await initializeFirebase();
      if (!firebaseReady) {
        clearBackendTokenSync();
        return;
      }

      final token = _registeredToken ?? await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await unregisterToken(token);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[FCM] Failed to unregister token: $error');
      }
    } finally {
      clearBackendTokenSync();
    }
  }

  @visibleForTesting
  static String? routeForNotificationData(Map<String, dynamic> data) {
    if ((data['type'] ?? '').toString() != 'order_chat_message') {
      return null;
    }

    final orderId = int.tryParse((data['order_id'] ?? '').toString());
    if (orderId == null || orderId <= 0) {
      return null;
    }

    return AppRoutes.orderChatPath(orderId);
  }

  static Future<NotificationSettings> _requestNotificationPermission() {
    return _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  static Future<void> _registerTokenForUser({
    required int userId,
    required String token,
    required Future<void> Function(String token) registerToken,
  }) async {
    if (_registeredUserId == userId && _registeredToken == token) {
      return;
    }

    try {
      await registerToken(token);
      _registeredUserId = userId;
      _registeredToken = token;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[FCM] Failed to register token on backend: $error');
      }
    }
  }

  static void _openRouteFromMessage(RemoteMessage message) {
    final route = routeForNotificationData(message.data);
    if (route == null) {
      return;
    }

    _openRoute?.call(route);
  }

  static void _logToken(String? token, {required String label}) {
    if (!kDebugMode) {
      return;
    }

    if (token == null || token.isEmpty) {
      debugPrint('[FCM] $label is empty');
      return;
    }

    debugPrint('[FCM] $label: $token');
  }
}
