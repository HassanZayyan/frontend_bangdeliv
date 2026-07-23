import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../features/tracking/application/tracking_focus_target.dart';
import '../firebase_options.dart';
import '../utils/order_formatters.dart';
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
  static const String driverOrderNotificationChannelId =
      'bangdeliv_driver_order_high';
  static const String _driverOrderNotificationChannelName =
      'Order Masuk Driver';
  static const String _driverOrderNotificationChannelDescription =
      'Notifikasi prioritas tinggi untuk order baru yang tersedia untuk driver.';

  static bool _firebaseInitialized = false;
  static bool _notificationsInitialized = false;
  static bool _localNotificationsInitialized = false;
  static bool _localLaunchDetailsHandled = false;
  static Future<bool>? _firebaseInitializationFuture;
  static Future<void>? _notificationsInitializationFuture;
  static Future<void>? _tokenSyncFuture;
  static String? _registeredToken;
  static int? _registeredUserId;
  static int? _tokenSyncUserId;
  static int _tokenSyncGeneration = 0;
  static FutureOr<void> Function(String route)? _openRoute;
  static bool Function(RemoteMessage message)? _shouldShowForegroundMessage;
  static Future<void> Function(String token)? _tokenRefreshHandler;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static final Set<String> _shownNotificationKeys = <String>{};

  static Future<bool> initializeFirebase() {
    if (_firebaseInitialized) {
      return Future<bool>.value(true);
    }

    final currentInitialization = _firebaseInitializationFuture;
    if (currentInitialization != null) {
      return currentInitialization;
    }

    final nextInitialization = _initializeFirebase();
    _firebaseInitializationFuture = nextInitialization;
    return nextInitialization;
  }

  static Future<bool> _initializeFirebase() async {
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
      _firebaseInitializationFuture = null;
      return false;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[FCM] Failed to initialize Firebase: $error');
      }
      _firebaseInitializationFuture = null;
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

    final currentInitialization = _notificationsInitializationFuture;
    if (currentInitialization != null) {
      await currentInitialization;
      return;
    }

    final nextInitialization = _initializeNotifications();
    _notificationsInitializationFuture = nextInitialization;
    await nextInitialization;
  }

  static Future<void> _initializeNotifications() async {
    final firebaseReady = await initializeFirebase();
    if (!firebaseReady) {
      _notificationsInitializationFuture = null;
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
    _notificationsInitializationFuture = null;
  }

  static Future<void> syncTokenWithBackend({
    required int userId,
    required Future<void> Function(String token) registerToken,
  }) async {
    _tokenRefreshHandler = (token) {
      return _registerTokenForUser(
        userId: userId,
        token: token,
        registerToken: registerToken,
      );
    };

    if (_registeredUserId == userId &&
        _registeredToken != null &&
        _registeredToken!.isNotEmpty) {
      return;
    }

    final currentSync = _tokenSyncFuture;
    if (_tokenSyncUserId == userId && currentSync != null) {
      await currentSync;
      return;
    }

    final generation = _tokenSyncGeneration;
    final nextSync = _syncTokenWithBackend(
      userId: userId,
      registerToken: registerToken,
      generation: generation,
    );
    _tokenSyncUserId = userId;
    _tokenSyncFuture = nextSync;
    try {
      await nextSync;
    } finally {
      if (identical(_tokenSyncFuture, nextSync)) {
        _tokenSyncFuture = null;
        _tokenSyncUserId = null;
      }
    }
  }

  static Future<void> _syncTokenWithBackend({
    required int userId,
    required Future<void> Function(String token) registerToken,
    required int generation,
  }) async {
    final firebaseReady = await initializeFirebase();
    if (!firebaseReady) {
      return;
    }

    await _requestNotificationPermission();

    if (generation != _tokenSyncGeneration) {
      return;
    }

    try {
      final token = await _messaging.getToken();
      if (generation != _tokenSyncGeneration) {
        return;
      }
      if (_registeredUserId == userId && _registeredToken == token) {
        return;
      }
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
    _tokenSyncGeneration += 1;
    _tokenRefreshHandler = null;
    _tokenSyncFuture = null;
    _tokenSyncUserId = null;
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
        type != 'payment_proof_required' &&
        type != 'driver_order_available' &&
        type != 'shopping_item_unavailable' &&
        type != 'shopping_merchant_failed') {
      return null;
    }

    final explicitRoute = NotificationNavigationService.normalizeRoute(
      (data['route'] ?? '').toString(),
    );
    if (explicitRoute != null) {
      return explicitRoute;
    }

    if (type == 'driver_order_available') {
      return AppRoutes.driverOrders;
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
      'driver_order_available' => AppRoutes.driverOrders,
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
      'shopping_item_unavailable' ||
      'shopping_merchant_failed' => AppRoutes.orderTrackPath(
        orderId,
        focus: TrackingFocusTarget.shoppingPrice,
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
        ? 'order_chat_message:$orderId:$messageId'
        : 'order_chat_message:$orderId:${title.hashCode}:${body.hashCode}';
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

  static Future<void> showLocalOrderPriceChangedNotification({
    required int orderId,
    required String recipientRole,
    required String changeType,
    int priceEventId = 0,
    bool requiresResponse = false,
    num? amount,
    num? oldTotalPrice,
    num? newTotalPrice,
    String? focus,
    int? pickupLocationId,
  }) async {
    final normalizedRole = recipientRole.trim().toLowerCase() == 'driver'
        ? 'driver'
        : 'customer';
    final normalizedChangeType = changeType.trim().toUpperCase();
    final resolvedAmount = amount ?? newTotalPrice;
    final resolvedFocus =
        focus ??
        (normalizedChangeType.contains('DELIVERY_FEE') ||
                normalizedChangeType.contains('FEE')
            ? TrackingFocusTarget.deliveryFee
            : TrackingFocusTarget.shoppingPrice);
    final data = <String, dynamic>{
      'type': 'order_price_changed',
      'order_id': orderId.toString(),
      'change_type': normalizedChangeType,
      'recipient_role': normalizedRole,
      'requires_response': requiresResponse ? '1' : '0',
      'amount': resolvedAmount != null ? _amountData(resolvedAmount) : '',
      'old_total_price': oldTotalPrice != null
          ? _amountData(oldTotalPrice)
          : '',
      'new_total_price': newTotalPrice != null
          ? _amountData(newTotalPrice)
          : '',
      'price_event_id': priceEventId > 0 ? priceEventId.toString() : '',
      'focus': resolvedFocus,
      'pickup_location_id': pickupLocationId != null && pickupLocationId > 0
          ? pickupLocationId.toString()
          : '',
    };
    final route =
        routeForNotificationData(data) ?? AppRoutes.orderTrackPath(orderId);
    data['route'] = route;

    final key = priceEventId > 0
        ? 'order_price_changed:$orderId:$priceEventId'
        : 'order_price_changed:$orderId:$normalizedChangeType:${_amountData(resolvedAmount ?? 0)}:${pickupLocationId ?? 0}';
    if (!_rememberNotificationKey(key)) {
      return;
    }

    final copy = _priceNotificationCopy(
      changeType: normalizedChangeType,
      recipientRole: normalizedRole,
      requiresResponse: requiresResponse,
      amount: resolvedAmount,
    );

    await _initializeLocalNotifications();
    await _showLocalNotification(
      id: _notificationId(orderId: orderId, messageId: priceEventId),
      title: copy.$1,
      body: copy.$2,
      payload: route,
      data: data,
    );
  }

  static Future<void> showLocalOrderStatusNotification({
    required int orderId,
    required int historyId,
    required String statusCode,
    required String title,
    required String body,
  }) async {
    final route = AppRoutes.orderTrackPath(orderId);
    final normalizedStatusCode = statusCode.trim().toUpperCase();
    final key = historyId > 0
        ? 'order_status_changed:$orderId:$historyId'
        : 'order_status_changed:$orderId:$normalizedStatusCode';
    if (!_rememberNotificationKey(key)) {
      return;
    }

    await _initializeLocalNotifications();
    await _showLocalNotification(
      id: _notificationId(orderId: orderId, messageId: historyId),
      title: title,
      body: body,
      payload: route,
      data: <String, dynamic>{
        'type': 'order_status_changed',
        'order_id': orderId.toString(),
        'history_id': historyId > 0 ? historyId.toString() : '',
        'status_code': normalizedStatusCode,
        'route': route,
      },
    );
  }

  static Future<void> showLocalDriverOrderAvailableNotification({
    required int orderId,
    required String title,
    required String body,
    String orderNumber = '',
    String serviceTypeCode = '',
  }) async {
    final route = AppRoutes.driverOrders;
    final key = 'driver_order_available:$orderId:$orderId';
    if (!_rememberNotificationKey(key)) {
      return;
    }

    await _initializeLocalNotifications();
    await _showLocalNotification(
      id: _notificationId(orderId: orderId, messageId: orderId),
      title: title,
      body: body,
      payload: route,
      data: <String, dynamic>{
        'type': 'driver_order_available',
        'order_id': orderId.toString(),
        'order_number': orderNumber,
        'service_type_code': serviceTypeCode,
        'event_id': orderId.toString(),
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
      const android = AndroidInitializationSettings(
        '@drawable/ic_stat_bangdeliv',
      );
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
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          driverOrderNotificationChannelId,
          _driverOrderNotificationChannelName,
          description: _driverOrderNotificationChannelDescription,
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
    final eventId = int.tryParse((message.data['event_id'] ?? '').toString());
    final type = (message.data['type'] ?? '').toString();
    final notificationRefId =
        messageId ?? historyId ?? priceEventId ?? eventId ?? 0;
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
          (data['type'] ?? '').toString() == 'order_price_changed' ||
          (data['type'] ?? '').toString() == 'shopping_item_unavailable';
      final isDriverOrderNotification =
          (data['type'] ?? '').toString() == 'driver_order_available';
      final android = AndroidNotificationDetails(
        isDriverOrderNotification
            ? driverOrderNotificationChannelId
            : isStatusNotification
            ? statusNotificationChannelId
            : chatNotificationChannelId,
        isDriverOrderNotification
            ? _driverOrderNotificationChannelName
            : isStatusNotification
            ? _statusNotificationChannelName
            : _chatNotificationChannelName,
        channelDescription: isDriverOrderNotification
            ? _driverOrderNotificationChannelDescription
            : isStatusNotification
            ? _statusNotificationChannelDescription
            : _chatNotificationChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: isDriverOrderNotification
            ? AndroidNotificationCategory.status
            : AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
        color: AppColors.primary,
        icon: 'ic_stat_bangdeliv',
        ticker: isDriverOrderNotification
            ? 'Order driver baru'
            : isStatusNotification
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

  static (String, String) _priceNotificationCopy({
    required String changeType,
    required String recipientRole,
    required bool requiresResponse,
    required num? amount,
  }) {
    final type = changeType.toUpperCase();
    final amountText = amount != null ? formatCurrency(amount) : null;

    if (type.contains('DELIVERY_FEE') || type.contains('FEE')) {
      if (requiresResponse && recipientRole == 'customer') {
        return (
          'Revisi ongkir perlu persetujuan',
          amountText == null
              ? 'Driver mengirim revisi ongkir. Buka order untuk merespons.'
              : 'Driver mengirim revisi ongkir $amountText. Buka order untuk merespons.',
        );
      }
      if (requiresResponse && recipientRole == 'driver') {
        return (
          'Customer menawar ongkir',
          amountText == null
              ? 'Tawaran ongkir perlu kamu tanggapi.'
              : 'Tawaran ongkir $amountText perlu kamu tanggapi.',
        );
      }

      return (
        'Ongkir diperbarui',
        amountText == null
            ? 'Buka order untuk melihat perubahan ongkir.'
            : 'Ongkir order sekarang $amountText.',
      );
    }

    if (type.contains('COUNTER')) {
      return (
        'Customer mengirim tawaran',
        amountText == null
            ? 'Tawaran harga perlu kamu tanggapi.'
            : 'Tawaran harga $amountText perlu kamu tanggapi.',
      );
    }

    if (type.contains('APPROVED')) {
      return (
        'Harga disetujui',
        amountText == null
            ? 'Harga sudah disetujui. Silakan lanjutkan order.'
            : 'Harga $amountText sudah disetujui. Silakan lanjutkan order.',
      );
    }

    if (type.contains('CANCEL')) {
      return (
        'Perubahan harga dibatalkan',
        'Customer membatalkan bagian order terkait perubahan harga.',
      );
    }

    if (requiresResponse && recipientRole == 'customer') {
      return (
        'Harga perlu persetujuan',
        amountText == null
            ? 'Driver mengirim harga. Buka order untuk OK, Tawar, atau Batal.'
            : 'Driver mengirim harga $amountText. Buka order untuk OK, Tawar, atau Batal.',
      );
    }

    return (
      'Total order diperbarui',
      amountText == null
          ? 'Buka order untuk melihat total pembayaran terbaru.'
          : 'Total pembayaran sekarang $amountText.',
    );
  }

  static String _amountData(num amount) {
    return amount.toStringAsFixed(2);
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
