import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import '../config/app_env.dart';
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

/// Wrapper around [PusherChannelsFlutter] for Laravel Reverb.
class PusherService {
  PusherService._();

  static final PusherService instance = PusherService._();
  static const _driverLocationUpdatedEvent =
      'App\\Events\\DriverLocationUpdated';
  static const _orderStatusChangedEvent = 'App\\Events\\OrderStatusChanged';

  PusherChannelsFlutter? _pusher;
  bool _connected = false;

  static String get _reverbProxyUrl {
    return 'ws://${AppEnv.wsHost}:${AppEnv.wsPort}';
  }

  Future<void> connect() async {
    if (_connected) return;

    _pusher = PusherChannelsFlutter.getInstance();
    _log('connecting to $_reverbProxyUrl');

    await _pusher!.init(
      apiKey: AppEnv.pusherAppKey,
      cluster: AppEnv.pusherCluster,
      useTLS: false,
      proxy: _reverbProxyUrl,
      authEndpoint: _broadcastAuthEndpoint,
      onAuthorizer: (channelName, socketId, options) async {
        try {
          final response = await http.post(
            Uri.parse(_broadcastAuthEndpoint),
            headers: await AuthService.authorizedHeaders(),
            body: jsonEncode(<String, dynamic>{
              'socket_id': socketId,
              'channel_name': channelName,
            }),
          );

          if (response.statusCode < 200 || response.statusCode >= 300) {
            _log(
              'auth failed for $channelName (${response.statusCode})',
            );
            return null;
          }

          final decoded = jsonDecode(response.body);
          return decoded is Map<String, dynamic> ? decoded : null;
        } catch (error) {
          _log('auth error for $channelName: $error');
          return null;
        }
      },
    );

    await _pusher!.connect();
    _connected = true;
    _log('connected');
  }

  static String get _broadcastAuthEndpoint {
    return '${AppEnv.apiBaseUrl.replaceFirst('/api', '')}/broadcasting/auth';
  }

  StreamSubscription<Map<String, dynamic>> subscribeOrderTracking(
    int orderId, {
    void Function(double lat, double lng, double heading, DateTime updatedAt)?
        onLocation,
    void Function(OrderStatusRealtimeEvent event)? onStatusChanged,
  }) {
    final channelName = 'private-order.tracking.$orderId';
    late final StreamController<Map<String, dynamic>> controller;

    controller = StreamController<Map<String, dynamic>>.broadcast(
      onCancel: () {
        _pusher?.unsubscribe(channelName: channelName);
      },
    );

    _log('subscribing $channelName');
    _pusher?.subscribe(
      channelName: channelName,
      onEvent: (event) {
        _log('event ${event.eventName} on $channelName: ${event.data}');
        if (!_isDriverLocationEvent(event.eventName) &&
            !_isOrderStatusEvent(event.eventName)) {
          return;
        }

        final payload = _decodePayload(event.data);
        if (payload == null) return;

        controller.add(<String, dynamic>{
          'event_name': event.eventName,
          'payload': payload,
        });
      },
    );

    return controller.stream.listen((rawEvent) {
      final eventName = (rawEvent['event_name'] ?? '').toString();
      final payload = (rawEvent['payload'] is Map<String, dynamic>)
          ? rawEvent['payload'] as Map<String, dynamic>
          : const <String, dynamic>{};

      if (_isDriverLocationEvent(eventName) && onLocation != null) {
        _handleLocationPayload(payload, onLocation);
        return;
      }

      if (_isOrderStatusEvent(eventName) && onStatusChanged != null) {
        _handleStatusPayload(payload, onStatusChanged);
      }
    });
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
    return _matchesEvent(eventName, _orderStatusChangedEvent);
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
    final rawStatusCode = payload['status_code'] ??
        status['code'] ??
        history['status_code'] ??
        (payload['status'] is String ? payload['status'] : null);
    final statusCode = (rawStatusCode ?? '').toString().trim().toUpperCase();
    if (statusCode.isEmpty) return;

    final previousStatusCode =
        payload['previous_status_code']?.toString().trim().toUpperCase();
    final statusLabel = (payload['status_label'] ??
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
    await _pusher?.disconnect();
    _connected = false;
    _log('disconnected');
  }

  void _log(String message) {
    assert(() {
      debugPrint('[PusherService] $message');
      return true;
    }());
  }
}
