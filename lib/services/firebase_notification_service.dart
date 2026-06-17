import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/app_routes.dart';
import '../features/tracking/application/tracking_focus_target.dart';
import '../firebase_options.dart';
import 'notification_navigation_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode) {
    debugPrint('[FCM] Background message: ${message.messageId}');
  }
}

@pragma('vm:entry-point')
void localNotificationTapBackground(NotificationResponse response) {
  final payload = response.payload?.trim() ?? '';
  if (payload.isEmpty) {
    return;
  }

  unawaited(NotificationNavigationService.queueRoute(payload));
}

class FirebaseNotificationService {
  FirebaseNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String chatNotificationChannelId = 'bangdeliv_chat_high';
  static const String _chatNotificationChannelName = 'Chat Order';
  static const String _chatNotificationChannelDescription =
      'Notifikasi prioritas tinggi untuk pesan chat order.';
  static const String statusNotificationChannelId =
      'bangdeliv_order_status_high';
  static const String _statusNotificationChannelName = 'Status Order';
  static const String _statusNotificationChannelDescription =
      'Notifikasi prioritas tinggi untuk perubahan status order.';

  static bool _firebaseInitialized = false;
  static bool _notificationsInitialized = false;
  static bool _localNotificationsInitialized = false;
  static bool _localLaunchDetailsHandled = false;
  static String? _registeredToken;
  static int? _registeredUserId;
  static FutureOr<void> Function(String route)? _openRoute;
  static bool Function(RemoteMessage message)? _shouldShowForegroundMessage;
  static Future<void> Function(String token)? _tokenRefreshHandler;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static final Set<String> _shownNotificationKeys = <String>{};

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
    FutureOr<void> Function(String route)? onOpenRoute,
    bool Function(RemoteMessage message)? shouldShowForegroundMessage,
  }) async {
    if (onOpenRoute != null) {
      _openRoute = onOpenRoute;
    }
    if (shouldShowForegroundMessage != null) {
      _shouldShowForegroundMessage = shouldShowForegroundMessage;
    }

    if (_notificationsInitialized) {
      return;
    }

    final firebaseReady = await initializeFirebase();
    if (!firebaseReady) {
      return;
    }

    await _messaging.setAutoInitEnabled(true);
    await _initializeLocalNotifications();
    await _handleLocalNotificationLaunchDetails();

    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen((token) {
      _logToken(token, label: 'Refreshed token');
      unawaited(_tokenRefreshHandler?.call(token));
    });

    FirebaseMessaging.onMessage.listen((message) {
      if (kDebugMode) {
        final notification = message.notification;
        debugPrint(
          '[FCM] Foreground message: '
          '${notification?.title ?? message.messageId ?? 'no title'}',
        );
      }

      if (_shouldShowForegroundMessage?.call(message) ?? true) {
        unawaited(_showForegroundOrderNotification(message));
      }
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

  static String? routeForNotificationData(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    if (type != 'order_chat_message' &&
        type != 'order_status_changed' &&
        type != 'order_price_changed' &&
        type != 'payment_proof_required') {
      return null;
    }

    final explicitRoute = NotificationNavigationService.normalizeRoute(
      (data['route'] ?? '').toString(),
    );
    if (explicitRoute != null) {
      return explicitRoute;
    }

    final orderId = int.tryParse((data['order_id'] ?? '').toString());
    if (orderId == null || orderId <= 0) {
      return null;
    }

    return switch (type) {
      'order_chat_message' => AppRoutes.orderChatPath(orderId),
      'payment_proof_required' => AppRoutes.orderTrackPath(
        orderId,
        focus: TrackingFocusTarget.payment,
      ),
      'order_price_changed' =>
        (data['recipient_role'] ?? '').toString().toLowerCase() == 'driver'
            ? AppRoutes.driverOrderActivePath(orderId.toString())
            : AppRoutes.orderTrackPath(
                orderId,
                focus: _trackingFocusFromNotificationData(data),
                pickupLocationId: int.tryParse(
                  (data['pickup_location_id'] ?? '').toString(),
                ),
              ),
      _ => AppRoutes.orderTrackPath(orderId),
    };
  }

  static String? _trackingFocusFromNotificationData(Map<String, dynamic> data) {
    final focus = (data['focus'] ?? '').toString().trim();
    if (focus == TrackingFocusTarget.deliveryFee ||
        focus == TrackingFocusTarget.shoppingPrice ||
        focus == TrackingFocusTarget.payment) {
      return focus;
    }

    final changeType = (data['change_type'] ?? '').toString().toUpperCase();
    if (changeType.contains('DELIVERY_FEE') || changeType.contains('FEE')) {
      return TrackingFocusTarget.deliveryFee;
    }
    if (changeType.isNotEmpty) {
      return TrackingFocusTarget.shoppingPrice;
    }

    return null;
  }

  static Future<void> showLocalOrderChatNotification({
    required int orderId,
    required int messageId,
    required String title,
    required String body,
  }) async {
    final route = AppRoutes.orderChatPath(orderId);
    final key = messageId > 0
        ? 'chat:$orderId:$messageId'
        : 'realtime:$orderId:${title.hashCode}:${body.hashCode}';
    if (!_rememberNotificationKey(key)) {
      return;
    }

    await _initializeLocalNotifications();
    await _showLocalNotification(
      id: _notificationId(orderId: orderId, messageId: messageId),
      title: title,
      body: body,
      payload: route,
      data: <String, dynamic>{
        'type': 'order_chat_message',
        'order_id': orderId.toString(),
        'message_id': messageId.toString(),
        'route': route,
      },
    );
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

  static Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) {
      return;
    }

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      );

      await _localNotifications.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload?.trim() ?? '';
          _handleOpenRoute(payload);
        },
        onDidReceiveBackgroundNotificationResponse:
            localNotificationTapBackground,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          chatNotificationChannelId,
          _chatNotificationChannelName,
          description: _chatNotificationChannelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          statusNotificationChannelId,
          _statusNotificationChannelName,
          description: _statusNotificationChannelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
      await androidPlugin?.requestNotificationsPermission();

      _localNotificationsInitialized = true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[FCM] Failed to initialize local notifications: $error');
      }
    }
  }

  static Future<void> _handleLocalNotificationLaunchDetails() async {
    if (_localLaunchDetailsHandled) {
      return;
    }

    _localLaunchDetailsHandled = true;

    try {
      final details = await _localNotifications
          .getNotificationAppLaunchDetails();
      final didLaunch = details?.didNotificationLaunchApp ?? false;
      if (!didLaunch) {
        return;
      }

      _handleOpenRoute(details?.notificationResponse?.payload);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[FCM] Failed to read local notification launch details: $error',
        );
      }
    }
  }

  static Future<void> _showForegroundOrderNotification(
    RemoteMessage message,
  ) async {
    final route = routeForNotificationData(message.data);
    if (route == null) {
      return;
    }

    final orderId = int.tryParse((message.data['order_id'] ?? '').toString());
    final messageId = int.tryParse(
      (message.data['message_id'] ?? '').toString(),
    );
    final historyId = int.tryParse(
      (message.data['history_id'] ?? '').toString(),
    );
    final priceEventId = int.tryParse(
      (message.data['price_event_id'] ?? '').toString(),
    );
    final type = (message.data['type'] ?? '').toString();
    final notificationRefId = messageId ?? historyId ?? priceEventId ?? 0;
    final key = orderId != null && orderId > 0 && notificationRefId > 0
        ? '$type:$orderId:$notificationRefId'
        : 'fcm:${message.messageId ?? ''}:${orderId ?? 0}:$notificationRefId';
    if (!_rememberNotificationKey(key)) {
      return;
    }

    await _initializeLocalNotifications();

    final notification = message.notification;
    final title = (notification?.title ?? message.data['title'] ?? 'Bang Deliv')
        .toString()
        .trim();
    final body =
        (notification?.body ??
                message.data['body'] ??
                (type == 'order_chat_message'
                    ? 'Pesan chat baru.'
                    : 'Order diperbarui.'))
            .toString()
            .trim();

    await _showLocalNotification(
      id: _notificationId(orderId: orderId ?? 0, messageId: notificationRefId),
      title: title.isEmpty ? 'Bang Deliv' : title,
      body: body.isEmpty
          ? (type == 'order_chat_message'
                ? 'Pesan chat baru.'
                : 'Order diperbarui.')
          : body,
      payload: route,
      data: message.data,
    );
  }

  static Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
    required Map<String, dynamic> data,
  }) async {
    try {
      final isStatusNotification =
          (data['type'] ?? '').toString() == 'order_status_changed' ||
          (data['type'] ?? '').toString() == 'order_price_changed';
      final android = AndroidNotificationDetails(
        isStatusNotification
            ? statusNotificationChannelId
            : chatNotificationChannelId,
        isStatusNotification
            ? _statusNotificationChannelName
            : _chatNotificationChannelName,
        channelDescription: isStatusNotification
            ? _statusNotificationChannelDescription
            : _chatNotificationChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
        ticker: isStatusNotification
            ? 'Order diperbarui'
            : 'Pesan chat order baru',
      );
      const darwin = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final details = NotificationDetails(android: android, iOS: darwin);

      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[FCM] Failed to show local notification: $error data=${jsonEncode(data)}',
        );
      }
    }
  }

  static int _notificationId({required int orderId, required int messageId}) {
    if (messageId > 0) {
      return messageId % 2147483647;
    }

    final seed = '$orderId:${DateTime.now().millisecondsSinceEpoch}';
    return seed.hashCode.abs() % 2147483647;
  }

  static bool _rememberNotificationKey(String key) {
    if (key.trim().isEmpty) {
      return true;
    }

    if (_shownNotificationKeys.contains(key)) {
      return false;
    }

    _shownNotificationKeys.add(key);
    if (_shownNotificationKeys.length > 120) {
      _shownNotificationKeys.remove(_shownNotificationKeys.first);
    }

    return true;
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
    _handleOpenRoute(route);
  }

  static void _handleOpenRoute(String? route) {
    final normalizedRoute = NotificationNavigationService.normalizeRoute(route);
    if (normalizedRoute == null) {
      return;
    }

    final openRoute = _openRoute;
    if (openRoute == null) {
      unawaited(NotificationNavigationService.queueRoute(normalizedRoute));
      return;
    }

    unawaited(Future<void>.sync(() => openRoute(normalizedRoute)));
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
