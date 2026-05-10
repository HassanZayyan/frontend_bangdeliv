import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_env.dart';
import '../models/driver_order_model.dart';
import '../models/order_chat_model.dart';
import '../utils/order_formatters.dart';
import 'auth_service.dart';

class OrderStatusRealtimeEvent {
  const OrderStatusRealtimeEvent({
    required this.statusCode,
    required this.changedAt,
    this.statusLabel,
    this.previousStatusCode,
    this.historyId,
    this.isTerminal,
  });

  final String statusCode;
  final String? statusLabel;
  final String? previousStatusCode;
  final int? historyId;
  final DateTime changedAt;
  final bool? isTerminal;
}

class _PusherProtocolMessage {
  const _PusherProtocolMessage({
    required this.eventName,
    this.channelName,
    this.data,
  });

  final String eventName;
  final String? channelName;
  final dynamic data;
}

class _RawRealtimeEvent {
  const _RawRealtimeEvent({required this.eventName, required this.payload});

  final String eventName;
  final Map<String, dynamic> payload;
}

/// Pusher protocol client for Laravel Reverb.
///
/// This implementation connects to Reverb's Pusher-compatible WebSocket
/// endpoint directly so the configured host, port, and scheme are honored on
/// every Flutter platform.
class PusherService {
  PusherService._();

  static final PusherService instance = PusherService._();
  static const _driverLocationUpdatedEvent =
      'App\\Events\\DriverLocationUpdated';
  static const _orderStatusChangedEvent = 'App\\Events\\OrderStatusChanged';
  static const _orderChatMessageSentEvent = 'App\\Events\\OrderChatMessageSent';
  static const _orderChatMessageSentAlias = 'order.chat.message.sent';
  static const _driverOrderAvailableEvent = 'driver.order.available';
  static const _driverOrderRemovedEvent = 'driver.order.removed';
  static const _protocolVersion = '7';

  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSub;
  Future<void>? _connectFuture;
  String? _socketId;
  bool _connected = false;
  bool _manualDisconnect = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  final Map<String, StreamController<_RawRealtimeEvent>> _channelControllers =
      <String, StreamController<_RawRealtimeEvent>>{};
  final Map<String, int> _channelRetainCounts = <String, int>{};
  final Set<String> _subscribedChannels = <String>{};
  final Set<String> _pendingChannels = <String>{};

  static Uri get _reverbUri {
    return Uri(
      scheme: AppEnv.normalizedWsScheme,
      host: AppEnv.wsHost,
      port: AppEnv.wsPort,
      path: '/app/${Uri.encodeComponent(AppEnv.pusherAppKey)}',
      queryParameters: const <String, String>{
        'protocol': _protocolVersion,
        'client': 'flutter',
        'version': '1.0.0',
        'flash': 'false',
      },
    );
  }

  static String get _broadcastAuthEndpoint {
    return '${AppEnv.backendOrigin}/broadcasting/auth';
  }

  Future<void> connect() {
    if (_connected && _socketId != null) {
      return Future<void>.value();
    }

    final currentConnect = _connectFuture;
    if (currentConnect != null) {
      return currentConnect;
    }

    _manualDisconnect = false;
    final nextConnect = _connect();
    _connectFuture = nextConnect;
    return nextConnect.whenComplete(() {
      if (identical(_connectFuture, nextConnect)) {
        _connectFuture = null;
      }
    });
  }

  Future<void> _connect() async {
    if (!AppEnv.hasPusherAppKey) {
      throw StateError('PUSHER_APP_KEY belum dikonfigurasi.');
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final connected = Completer<void>();
    _log('connecting to $_reverbUri');

    final socket = WebSocketChannel.connect(_reverbUri);
    _socket = socket;

    _socketSub = socket.stream.listen(
      (raw) {
        final message = _decodeProtocolMessage(raw);
        if (message == null) {
          return;
        }

        _handleProtocolMessage(message, connected);
      },
      onError: (error, stackTrace) {
        _log('socket error: $error');
        if (!connected.isCompleted) {
          connected.completeError(error, stackTrace);
        }
        _handleSocketClosed();
      },
      onDone: () {
        _log('socket closed');
        if (!connected.isCompleted) {
          connected.completeError(
            StateError('Realtime socket ditutup sebelum tersambung.'),
          );
        }
        _handleSocketClosed();
      },
      cancelOnError: true,
    );

    try {
      await socket.ready.timeout(const Duration(seconds: 8));
      await connected.future.timeout(const Duration(seconds: 8));
      _connected = true;
      _reconnectAttempts = 0;
      _log('connected as socket $_socketId');
    } catch (_) {
      await _socketSub?.cancel();
      await socket.sink.close();
      _socket = null;
      _socketSub = null;
      _connected = false;
      _socketId = null;
      rethrow;
    }
  }

  StreamSubscription<Map<String, dynamic>> subscribeOrderTracking(
    int orderId, {
    void Function(double lat, double lng, double heading, DateTime updatedAt)?
    onLocation,
    void Function(OrderStatusRealtimeEvent event)? onStatusChanged,
    void Function(OrderChatMessageModel message)? onChatMessage,
    VoidCallback? onSubscribed,
    void Function(Object error)? onConnectionIssue,
  }) {
    final channelName = 'private-order.tracking.$orderId';
    final controller = _retainChannel(channelName);

    unawaited(
      _subscribeChannel(
        channelName,
      ).then((_) => onSubscribed?.call()).catchError((Object error) {
        _log('subscribe failed for $channelName: $error');
        onConnectionIssue?.call(error);
      }),
    );

    final rawSubscription = controller.stream.listen((rawEvent) {
      if (_isDriverLocationEvent(rawEvent.eventName) && onLocation != null) {
        _handleLocationPayload(rawEvent.payload, onLocation);
        return;
      }

      if (_isOrderStatusEvent(rawEvent.eventName) && onStatusChanged != null) {
        _handleStatusPayload(rawEvent.payload, onStatusChanged);
        return;
      }

      if (_isOrderChatMessageEvent(rawEvent.eventName) &&
          onChatMessage != null) {
        _handleChatPayload(rawEvent.payload, onChatMessage);
      }
    });

    return _MappedStreamSubscription<Map<String, dynamic>>(
      rawSubscription,
      onCancel: () => _releaseChannel(channelName),
    );
  }

  StreamSubscription<Map<String, dynamic>> subscribeDriverOrders(
    int userId, {
    void Function(DriverOrderModel order)? onOrderAvailable,
    void Function(String orderId, String? reason)? onOrderRemoved,
    VoidCallback? onSubscribed,
    void Function(Object error)? onConnectionIssue,
  }) {
    final channelName = 'private-driver.orders.user.$userId';
    final controller = _retainChannel(channelName);

    unawaited(
      _subscribeChannel(
        channelName,
      ).then((_) => onSubscribed?.call()).catchError((Object error) {
        _log('subscribe failed for $channelName: $error');
        onConnectionIssue?.call(error);
      }),
    );

    final rawSubscription = controller.stream.listen((rawEvent) {
      if (_isDriverOrderAvailableEvent(rawEvent.eventName) &&
          onOrderAvailable != null) {
        _handleDriverOrderAvailablePayload(rawEvent.payload, onOrderAvailable);
        return;
      }

      if (_isDriverOrderRemovedEvent(rawEvent.eventName) &&
          onOrderRemoved != null) {
        _handleDriverOrderRemovedPayload(rawEvent.payload, onOrderRemoved);
      }
    });

    return _MappedStreamSubscription<Map<String, dynamic>>(
      rawSubscription,
      onCancel: () => _releaseChannel(channelName),
    );
  }

  StreamController<_RawRealtimeEvent> _retainChannel(String channelName) {
    final existing = _channelControllers[channelName];
    _channelRetainCounts[channelName] =
        (_channelRetainCounts[channelName] ?? 0) + 1;

    if (existing != null && !existing.isClosed) {
      return existing;
    }

    final controller = StreamController<_RawRealtimeEvent>.broadcast();
    _channelControllers[channelName] = controller;
    return controller;
  }

  Future<void> _releaseChannel(String channelName) async {
    final current = _channelRetainCounts[channelName] ?? 0;
    if (current > 1) {
      _channelRetainCounts[channelName] = current - 1;
      return;
    }

    _channelRetainCounts.remove(channelName);
    _pendingChannels.remove(channelName);
    _subscribedChannels.remove(channelName);
    final controller = _channelControllers.remove(channelName);
    unawaited(controller?.close());

    if (_socket != null && _connected) {
      _sendProtocolEvent('pusher:unsubscribe', <String, dynamic>{
        'channel': channelName,
      });
    }

    if (_channelControllers.isEmpty) {
      unawaited(disconnect());
    }
  }

  Future<void> _subscribeChannel(String channelName) async {
    if (_subscribedChannels.contains(channelName) ||
        _pendingChannels.contains(channelName)) {
      return;
    }

    _pendingChannels.add(channelName);
    try {
      await connect();

      if (!_channelControllers.containsKey(channelName)) {
        return;
      }

      final authPayload = await _authorizeChannel(channelName);
      _sendProtocolEvent('pusher:subscribe', <String, dynamic>{
        'channel': channelName,
        ...authPayload,
      });
      _log('subscribing $channelName');
    } catch (error) {
      _log('subscribe failed for $channelName: $error');
      rethrow;
    } finally {
      _pendingChannels.remove(channelName);
    }
  }

  Future<Map<String, dynamic>> _authorizeChannel(String channelName) async {
    final socketId = _socketId;
    if (socketId == null || socketId.isEmpty) {
      throw StateError('Realtime socket belum memiliki socket_id.');
    }

    final response = await http
        .post(
          Uri.parse(_broadcastAuthEndpoint),
          headers: await AuthService.authorizedHeaders(),
          body: jsonEncode(<String, dynamic>{
            'socket_id': socketId,
            'channel_name': channelName,
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Auth realtime gagal untuk $channelName (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Respons auth realtime tidak valid.');
    }

    return decoded;
  }

  void _handleProtocolMessage(
    _PusherProtocolMessage message,
    Completer<void> connected,
  ) {
    final eventName = message.eventName;
    if (eventName == 'pusher:connection_established') {
      final data = _decodePayload(message.data);
      final socketId = data?['socket_id']?.toString().trim();
      if (socketId == null || socketId.isEmpty) {
        if (!connected.isCompleted) {
          connected.completeError(
            StateError('Realtime socket_id tidak ditemukan.'),
          );
        }
        return;
      }

      _socketId = socketId;
      if (!connected.isCompleted) {
        connected.complete();
      }
      return;
    }

    if (eventName == 'pusher:ping') {
      _sendProtocolEvent('pusher:pong', const <String, dynamic>{});
      return;
    }

    if (eventName == 'pusher:error') {
      _log('protocol error: ${message.data}');
      return;
    }

    if (eventName == 'pusher_internal:subscription_succeeded' ||
        eventName == 'pusher:subscription_succeeded') {
      final channelName = message.channelName;
      if (channelName != null) {
        _subscribedChannels.add(channelName);
        _log('subscription succeeded $channelName');
      }
      return;
    }

    final channelName = message.channelName;
    if (channelName == null ||
        !_channelControllers.containsKey(channelName) ||
        (!_isDriverLocationEvent(eventName) &&
            !_isOrderStatusEvent(eventName) &&
            !_isOrderChatMessageEvent(eventName) &&
            !_isDriverOrderEvent(eventName))) {
      return;
    }

    final payload = _decodePayload(message.data);
    if (payload == null) {
      return;
    }

    _log('event $eventName on $channelName: $payload');
    _channelControllers[channelName]?.add(
      _RawRealtimeEvent(eventName: eventName, payload: payload),
    );
  }

  Future<void> _resubscribeAllChannels() async {
    final channels = _channelControllers.keys.toList(growable: false);
    _subscribedChannels.clear();
    _pendingChannels.clear();

    for (final channelName in channels) {
      if (_channelControllers.containsKey(channelName)) {
        await _subscribeChannel(channelName);
      }
    }
  }

  void _handleSocketClosed() {
    _socket = null;
    _socketSub = null;
    _connected = false;
    _socketId = null;
    _subscribedChannels.clear();
    _pendingChannels.clear();

    if (!_manualDisconnect && _channelControllers.isNotEmpty) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null) {
      return;
    }

    _reconnectAttempts += 1;
    final delaySeconds = switch (_reconnectAttempts) {
      1 => 1,
      2 => 2,
      3 => 5,
      _ => 15,
    };
    _log('reconnecting in ${delaySeconds}s');

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;
      if (_channelControllers.isEmpty) {
        return;
      }

      unawaited(
        connect().then((_) => _resubscribeAllChannels()).catchError((
          Object error,
        ) {
          _log('reconnect failed: $error');
          _scheduleReconnect();
        }),
      );
    });
  }

  void _sendProtocolEvent(String eventName, Map<String, dynamic> data) {
    final socket = _socket;
    if (socket == null) {
      return;
    }

    socket.sink.add(
      jsonEncode(<String, dynamic>{'event': eventName, 'data': data}),
    );
  }

  _PusherProtocolMessage? _decodeProtocolMessage(dynamic raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final eventName = decoded['event']?.toString() ?? '';
      if (eventName.trim().isEmpty) {
        return null;
      }

      return _PusherProtocolMessage(
        eventName: eventName,
        channelName: decoded['channel']?.toString(),
        data: decoded['data'],
      );
    } catch (error) {
      _log('message decode failed: $error');
      return null;
    }
  }

  Map<String, dynamic>? _decodePayload(dynamic raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  bool _isDriverLocationEvent(String eventName) {
    return _matchesEvent(eventName, _driverLocationUpdatedEvent);
  }

  bool _isOrderStatusEvent(String eventName) {
    return _matchesEvent(eventName, _orderStatusChangedEvent) ||
        _matchesEvent(eventName, 'order.status.changed');
  }

  bool _isOrderChatMessageEvent(String eventName) {
    return _matchesEvent(eventName, _orderChatMessageSentEvent) ||
        _matchesEvent(eventName, _orderChatMessageSentAlias);
  }

  bool _isDriverOrderEvent(String eventName) {
    return _isDriverOrderAvailableEvent(eventName) ||
        _isDriverOrderRemovedEvent(eventName);
  }

  bool _isDriverOrderAvailableEvent(String eventName) {
    return _matchesEvent(eventName, _driverOrderAvailableEvent);
  }

  bool _isDriverOrderRemovedEvent(String eventName) {
    return _matchesEvent(eventName, _driverOrderRemovedEvent);
  }

  bool _matchesEvent(String rawEventName, String expectedEventName) {
    final eventName = rawEventName.trim().replaceFirst(RegExp(r'^\.'), '');
    final expected = expectedEventName.trim().replaceFirst(RegExp(r'^\.'), '');
    final shortName = expected.split('\\').last;
    final compactEventName = _compactEventName(eventName);

    return eventName == expected ||
        eventName == shortName ||
        compactEventName == _compactEventName(expected) ||
        compactEventName == _compactEventName(shortName);
  }

  String _compactEventName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
  }

  void _handleLocationPayload(
    Map<String, dynamic> payload,
    void Function(double lat, double lng, double heading, DateTime updatedAt)
    onLocation,
  ) {
    final location = (payload['location'] is Map<String, dynamic>)
        ? payload['location'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final driver = (payload['driver'] is Map<String, dynamic>)
        ? payload['driver'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final lat = _asDouble(
      payload['latitude'] ??
          payload['current_latitude'] ??
          location['latitude'] ??
          driver['current_latitude'] ??
          driver['latitude'],
    );
    final lng = _asDouble(
      payload['longitude'] ??
          payload['current_longitude'] ??
          location['longitude'] ??
          driver['current_longitude'] ??
          driver['longitude'],
    );
    final heading = _asDouble(payload['heading'] ?? location['heading']) ?? 0.0;
    final updatedAt = parseBackendDateTime(
      payload['updated_at'] ??
          payload['timestamp'] ??
          location['updated_at'] ??
          driver['location_updated_at'] ??
          driver['updated_at'],
    );

    if (lat != null && lng != null) {
      onLocation(lat, lng, heading, updatedAt ?? DateTime.now().toUtc());
    }
  }

  void _handleStatusPayload(
    Map<String, dynamic> payload,
    void Function(OrderStatusRealtimeEvent event) onStatusChanged,
  ) {
    final status = (payload['status'] is Map<String, dynamic>)
        ? payload['status'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final history = (payload['history'] is Map<String, dynamic>)
        ? payload['history'] as Map<String, dynamic>
        : (payload['status_history'] is Map<String, dynamic>)
        ? payload['status_history'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawStatusCode =
        payload['status_code'] ??
        status['code'] ??
        history['status_code'] ??
        (payload['status'] is String ? payload['status'] : null);
    final statusCode = (rawStatusCode ?? '').toString().trim().toUpperCase();
    if (statusCode.isEmpty) return;

    final previousStatusCode = payload['previous_status_code']
        ?.toString()
        .trim()
        .toUpperCase();
    final statusLabel =
        (payload['status_label'] ??
                payload['status_display_name'] ??
                status['display_name'] ??
                status['name'] ??
                history['status_display_name'])
            ?.toString()
            .trim();
    final historyId = _asInt(payload['history_id'] ?? history['id']);
    final isTerminal = _asBool(
      payload['is_terminal'] ?? status['is_terminal'] ?? history['is_terminal'],
    );
    final changedAt = parseBackendDateTime(
      payload['changed_at'] ??
          history['created_at'] ??
          payload['created_at'] ??
          payload['updated_at'],
    );

    onStatusChanged(
      OrderStatusRealtimeEvent(
        statusCode: statusCode,
        statusLabel: statusLabel == null || statusLabel.isEmpty
            ? null
            : statusLabel,
        previousStatusCode:
            previousStatusCode == null || previousStatusCode.isEmpty
            ? null
            : previousStatusCode,
        historyId: historyId,
        changedAt: changedAt ?? DateTime.now().toUtc(),
        isTerminal: isTerminal,
      ),
    );
  }

  void _handleChatPayload(
    Map<String, dynamic> payload,
    void Function(OrderChatMessageModel message) onChatMessage,
  ) {
    final message = (payload['message'] is Map<String, dynamic>)
        ? payload['message'] as Map<String, dynamic>
        : payload;

    try {
      onChatMessage(OrderChatMessageModel.fromJson(message));
    } catch (error) {
      _log('chat payload decode failed: $error');
    }
  }

  void _handleDriverOrderAvailablePayload(
    Map<String, dynamic> payload,
    void Function(DriverOrderModel order) onOrderAvailable,
  ) {
    final order = (payload['order'] is Map<String, dynamic>)
        ? payload['order'] as Map<String, dynamic>
        : payload;

    try {
      onOrderAvailable(DriverOrderModel.fromJson(order));
    } catch (error) {
      _log('driver order available payload decode failed: $error');
    }
  }

  void _handleDriverOrderRemovedPayload(
    Map<String, dynamic> payload,
    void Function(String orderId, String? reason) onOrderRemoved,
  ) {
    final rawOrderId =
        payload['order_id'] ?? payload['orderId'] ?? payload['id'];
    final orderId = rawOrderId?.toString().trim() ?? '';
    if (orderId.isEmpty) {
      return;
    }

    final reason = payload['reason']?.toString().trim();
    onOrderRemoved(orderId, reason == null || reason.isEmpty ? null : reason);
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();

    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;

    return double.tryParse(raw);
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;

    return int.tryParse(raw);
  }

  bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final raw = value?.toString().trim().toLowerCase() ?? '';
    if (raw.isEmpty) return null;

    if (raw == 'true' || raw == '1' || raw == 'yes') return true;
    if (raw == 'false' || raw == '0' || raw == 'no') return false;

    return null;
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _connected = false;
    _socketId = null;
    _subscribedChannels.clear();
    _pendingChannels.clear();

    await _socketSub?.cancel();
    _socketSub = null;
    final socket = _socket;
    _socket = null;
    await socket?.sink.close();
    _log('disconnected');
  }

  void _log(String message) {
    assert(() {
      debugPrint('[PusherService] $message');
      return true;
    }());
  }
}

class _MappedStreamSubscription<T> implements StreamSubscription<T> {
  _MappedStreamSubscription(this._inner, {required this.onCancel});

  final StreamSubscription<dynamic> _inner;
  final FutureOr<void> Function() onCancel;
  bool _cancelled = false;

  @override
  Future<void> cancel() async {
    if (_cancelled) {
      return;
    }

    _cancelled = true;
    await _inner.cancel();
    await onCancel();
  }

  @override
  void onData(void Function(T data)? handleData) {
    _inner.onData(handleData == null ? null : (data) => handleData(data as T));
  }

  @override
  void onError(Function? handleError) {
    _inner.onError(handleError);
  }

  @override
  void onDone(void Function()? handleDone) {
    _inner.onDone(handleDone);
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    _inner.pause(resumeSignal);
  }

  @override
  void resume() {
    _inner.resume();
  }

  @override
  bool get isPaused => _inner.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    return _inner.asFuture<E>(futureValue);
  }
}
