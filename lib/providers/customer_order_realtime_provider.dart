import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/pusher_service.dart';

final customerOrderRealtimeHubProvider = Provider<CustomerOrderRealtimeHub>((
  ref,
) {
  final hub = CustomerOrderRealtimeHub(PusherService.instance);
  ref.onDispose(hub.dispose);
  return hub;
});

class CustomerOrderRealtimeHub {
  CustomerOrderRealtimeHub(this._pusher);

  final PusherService _pusher;
  final _eventsController =
      StreamController<CustomerOrderRealtimeEvent>.broadcast();
  final Map<int, StreamSubscription<Map<String, dynamic>>> _subscriptions = {};
  final Map<int, int> _retainCounts = {};
  final Map<int, Future<void>> _pendingSubscriptions = {};
  final Map<int, Timer> _retryTimers = {};
  final Map<int, int> _retryAttempts = {};
  bool _disposed = false;

  Stream<CustomerOrderRealtimeEvent> get events => _eventsController.stream;

  Future<void> retainOrder(int orderId) {
    if (_disposed || orderId <= 0) {
      return Future<void>.value();
    }

    _retainCounts[orderId] = (_retainCounts[orderId] ?? 0) + 1;

    if (_subscriptions.containsKey(orderId)) {
      return Future<void>.value();
    }

    final pending = _pendingSubscriptions[orderId];
    if (pending != null) {
      return pending;
    }

    final nextPending = _subscribe(orderId);
    _pendingSubscriptions[orderId] = nextPending;
    return nextPending.whenComplete(() {
      _pendingSubscriptions.remove(orderId);
    });
  }

  Future<void> _subscribe(int orderId) async {
    try {
      await _pusher.connect();
      if (_disposed || (_retainCounts[orderId] ?? 0) <= 0) {
        return;
      }

      final subscription = _pusher.subscribeOrderTracking(
        orderId,
        onLocation: (lat, lng, heading, updatedAt) {
          _emit(
            CustomerOrderRealtimeEvent.location(
              orderId: orderId,
              latitude: lat,
              longitude: lng,
              heading: heading,
              updatedAt: updatedAt,
            ),
          );
        },
        onStatusChanged: (event) {
          _emit(
            CustomerOrderRealtimeEvent.status(
              orderId: orderId,
              status: event,
            ),
          );
        },
      );

      _subscriptions[orderId] = subscription;
      _retryAttempts.remove(orderId);
    } catch (error) {
      _emit(
        CustomerOrderRealtimeEvent.connectionIssue(
          orderId: orderId,
          message: 'Realtime order belum tersambung.',
          error: error,
        ),
      );
      _scheduleRetry(orderId);
    }
  }

  void releaseOrder(int orderId) {
    final current = _retainCounts[orderId] ?? 0;
    if (current <= 1) {
      _retainCounts.remove(orderId);
      _retryAttempts.remove(orderId);
      _retryTimers.remove(orderId)?.cancel();
      final subscription = _subscriptions.remove(orderId);
      unawaited(subscription?.cancel());
      return;
    }

    _retainCounts[orderId] = current - 1;
  }

  void _scheduleRetry(int orderId) {
    if (_disposed || (_retainCounts[orderId] ?? 0) <= 0) {
      return;
    }

    _retryTimers.remove(orderId)?.cancel();
    final attempt = (_retryAttempts[orderId] ?? 0) + 1;
    _retryAttempts[orderId] = attempt;
    final delaySeconds = (attempt * 5).clamp(5, 30).toInt();

    _retryTimers[orderId] = Timer(Duration(seconds: delaySeconds), () {
      _retryTimers.remove(orderId);
      if (_disposed ||
          (_retainCounts[orderId] ?? 0) <= 0 ||
          _subscriptions.containsKey(orderId)) {
        return;
      }

      final pending = _subscribe(orderId);
      _pendingSubscriptions[orderId] = pending;
      unawaited(
        pending.whenComplete(() {
          _pendingSubscriptions.remove(orderId);
        }),
      );
    });
  }

  void _emit(CustomerOrderRealtimeEvent event) {
    if (_disposed || _eventsController.isClosed) {
      return;
    }

    _eventsController.add(event);
  }

  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions.values) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _retainCounts.clear();
    _pendingSubscriptions.clear();
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _retryAttempts.clear();
    unawaited(_eventsController.close());
  }
}

enum CustomerOrderRealtimeEventType {
  status,
  location,
  connectionIssue,
}

class CustomerOrderRealtimeEvent {
  const CustomerOrderRealtimeEvent._({
    required this.type,
    required this.orderId,
    this.status,
    this.latitude,
    this.longitude,
    this.heading,
    this.updatedAt,
    this.message,
    this.error,
  });

  factory CustomerOrderRealtimeEvent.status({
    required int orderId,
    required OrderStatusRealtimeEvent status,
  }) {
    return CustomerOrderRealtimeEvent._(
      type: CustomerOrderRealtimeEventType.status,
      orderId: orderId,
      status: status,
    );
  }

  factory CustomerOrderRealtimeEvent.location({
    required int orderId,
    required double latitude,
    required double longitude,
    required double heading,
    required DateTime updatedAt,
  }) {
    return CustomerOrderRealtimeEvent._(
      type: CustomerOrderRealtimeEventType.location,
      orderId: orderId,
      latitude: latitude,
      longitude: longitude,
      heading: heading,
      updatedAt: updatedAt,
    );
  }

  factory CustomerOrderRealtimeEvent.connectionIssue({
    required int orderId,
    required String message,
    Object? error,
  }) {
    return CustomerOrderRealtimeEvent._(
      type: CustomerOrderRealtimeEventType.connectionIssue,
      orderId: orderId,
      message: message,
      error: error,
    );
  }

  final CustomerOrderRealtimeEventType type;
  final int orderId;
  final OrderStatusRealtimeEvent? status;
  final double? latitude;
  final double? longitude;
  final double? heading;
  final DateTime? updatedAt;
  final String? message;
  final Object? error;
}
