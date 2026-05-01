import 'dart:async';
import 'dart:convert';

import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import '../config/app_env.dart';
import 'auth_service.dart';

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

    await _pusher!.init(
      apiKey: AppEnv.pusherAppKey,
      cluster: AppEnv.pusherCluster,
      useTLS: false,
      proxy: _reverbProxyUrl,
      authEndpoint:
          '${AppEnv.apiBaseUrl.replaceFirst('/api', '')}/broadcasting/auth',
      onAuthorizer: (channelName, socketId, options) async {
        try {
          final headers = await AuthService.authorizedHeaders(
            includeJsonContentType: false,
          );
          return {
            'headers': {
              'Authorization': headers['Authorization'] ?? '',
            },
          };
        } catch (_) {
          return null;
        }
      },
    );

    await _pusher!.connect();
    _connected = true;
  }

  StreamSubscription<Map<String, dynamic>> subscribeOrderTracking(
    int orderId, {
    void Function(double lat, double lng, double heading, DateTime updatedAt)?
        onLocation,
    void Function(
      String statusCode,
      String? previousStatusCode,
      int? historyId,
      DateTime changedAt,
    )?
        onStatusChanged,
  }) {
    final channelName = 'private-order.tracking.$orderId';
    late final StreamController<Map<String, dynamic>> controller;

    controller = StreamController<Map<String, dynamic>>.broadcast(
      onCancel: () {
        _pusher?.unsubscribe(channelName: channelName);
      },
    );

    _pusher?.subscribe(
      channelName: channelName,
      onEvent: (event) {
        if (event.eventName != _driverLocationUpdatedEvent &&
            event.eventName != _orderStatusChangedEvent) {
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

      if (eventName == _driverLocationUpdatedEvent && onLocation != null) {
        _handleLocationPayload(payload, onLocation);
        return;
      }

      if (eventName == _orderStatusChangedEvent && onStatusChanged != null) {
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

  void _handleLocationPayload(
    Map<String, dynamic> payload,
    void Function(double lat, double lng, double heading, DateTime updatedAt)
        onLocation,
  ) {
    final lat = (payload['latitude'] as num?)?.toDouble();
    final lng = (payload['longitude'] as num?)?.toDouble();
    final heading = (payload['heading'] as num?)?.toDouble() ?? 0.0;
    final updatedAtRaw = payload['updated_at'] as String?;
    final updatedAt =
        updatedAtRaw != null ? DateTime.tryParse(updatedAtRaw) : null;

    if (lat != null && lng != null) {
      onLocation(lat, lng, heading, updatedAt ?? DateTime.now());
    }
  }

  void _handleStatusPayload(
    Map<String, dynamic> payload,
    void Function(
      String statusCode,
      String? previousStatusCode,
      int? historyId,
      DateTime changedAt,
    ) onStatusChanged,
  ) {
    final statusCode =
        (payload['status_code'] ?? '').toString().trim().toUpperCase();
    if (statusCode.isEmpty) return;

    final previousStatusCode =
        payload['previous_status_code']?.toString().trim().toUpperCase();
    final historyId = (payload['history_id'] as num?)?.toInt();
    final changedAt = DateTime.tryParse(
      (payload['changed_at'] as String?) ?? '',
    );

    onStatusChanged(
      statusCode,
      previousStatusCode,
      historyId,
      changedAt ?? DateTime.now(),
    );
  }

  Future<void> disconnect() async {
    await _pusher?.disconnect();
    _connected = false;
  }
}
