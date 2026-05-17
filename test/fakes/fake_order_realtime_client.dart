import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/models/order_chat_model.dart';
import 'package:frontend_bangdeliv/services/pusher_service.dart';

class FakeOrderRealtimeClient implements OrderRealtimeClient {
  int connectCalls = 0;
  int driverOrderSubscribeCalls = 0;
  int orderTrackingSubscribeCalls = 0;
  int failDriverOrderSubscribeAttempts = 0;
  int failOrderTrackingSubscribeAttempts = 0;
  final Set<int> driverOrderSubscriptions = <int>{};
  final Set<int> orderTrackingSubscriptions = <int>{};

  final Map<int, void Function(DriverOrderModel)>
  _driverOrderAvailableHandlers = <int, void Function(DriverOrderModel)>{};
  final Map<int, void Function(String, String?)> _driverOrderRemovedHandlers =
      <int, void Function(String, String?)>{};
  final Map<int, void Function(OrderChatMessageModel)> _orderChatHandlers =
      <int, void Function(OrderChatMessageModel)>{};
  final Map<int, void Function(OrderStatusRealtimeEvent)> _orderStatusHandlers =
      <int, void Function(OrderStatusRealtimeEvent)>{};
  final Map<int, void Function(Map<String, dynamic>)> _orderContentHandlers =
      <int, void Function(Map<String, dynamic>)>{};

  @override
  Future<void> connect() async {
    connectCalls += 1;
  }

  @override
  StreamSubscription<Map<String, dynamic>> subscribeDriverOrders(
    int userId, {
    void Function(DriverOrderModel order)? onOrderAvailable,
    void Function(String orderId, String? reason)? onOrderRemoved,
    VoidCallback? onSubscribed,
    void Function(Object error)? onConnectionIssue,
  }) {
    driverOrderSubscribeCalls += 1;
    if (failDriverOrderSubscribeAttempts > 0) {
      failDriverOrderSubscribeAttempts -= 1;
      Future<void>.microtask(
        () => onConnectionIssue?.call(StateError('driver subscribe failed')),
      );
      return _subscription(onCancel: () {});
    }

    driverOrderSubscriptions.add(userId);
    if (onOrderAvailable != null) {
      _driverOrderAvailableHandlers[userId] = onOrderAvailable;
    }
    if (onOrderRemoved != null) {
      _driverOrderRemovedHandlers[userId] = onOrderRemoved;
    }
    Future<void>.microtask(() => onSubscribed?.call());

    return _subscription(
      onCancel: () {
        driverOrderSubscriptions.remove(userId);
        _driverOrderAvailableHandlers.remove(userId);
        _driverOrderRemovedHandlers.remove(userId);
      },
    );
  }

  @override
  StreamSubscription<Map<String, dynamic>> subscribeOrderTracking(
    int orderId, {
    void Function(double lat, double lng, double heading, DateTime updatedAt)?
    onLocation,
    void Function(OrderStatusRealtimeEvent event)? onStatusChanged,
    void Function(Map<String, dynamic> payload)? onContentUpdated,
    void Function(OrderChatMessageModel message)? onChatMessage,
    VoidCallback? onSubscribed,
    void Function(Object error)? onConnectionIssue,
  }) {
    orderTrackingSubscribeCalls += 1;
    if (failOrderTrackingSubscribeAttempts > 0) {
      failOrderTrackingSubscribeAttempts -= 1;
      Future<void>.microtask(
        () => onConnectionIssue?.call(StateError('tracking subscribe failed')),
      );
      return _subscription(onCancel: () {});
    }

    orderTrackingSubscriptions.add(orderId);
    if (onChatMessage != null) {
      _orderChatHandlers[orderId] = onChatMessage;
    }
    if (onStatusChanged != null) {
      _orderStatusHandlers[orderId] = onStatusChanged;
    }
    if (onContentUpdated != null) {
      _orderContentHandlers[orderId] = onContentUpdated;
    }
    Future<void>.microtask(() => onSubscribed?.call());

    return _subscription(
      onCancel: () {
        orderTrackingSubscriptions.remove(orderId);
        _orderChatHandlers.remove(orderId);
        _orderStatusHandlers.remove(orderId);
        _orderContentHandlers.remove(orderId);
      },
    );
  }

  void emitDriverOrderAvailable(int userId, DriverOrderModel order) {
    _driverOrderAvailableHandlers[userId]?.call(order);
  }

  void emitDriverOrderRemoved(int userId, String orderId, {String? reason}) {
    _driverOrderRemovedHandlers[userId]?.call(orderId, reason);
  }

  void emitOrderChatMessage(int orderId, OrderChatMessageModel message) {
    _orderChatHandlers[orderId]?.call(message);
  }

  void emitOrderStatus(int orderId, OrderStatusRealtimeEvent event) {
    _orderStatusHandlers[orderId]?.call(event);
  }

  void emitOrderContentUpdated(
    int orderId, [
    Map<String, dynamic> payload = const <String, dynamic>{},
  ]) {
    _orderContentHandlers[orderId]?.call(payload);
  }

  @override
  Future<void> disconnect() async {}

  StreamSubscription<Map<String, dynamic>> _subscription({
    required FutureOr<void> Function() onCancel,
  }) {
    final controller = StreamController<Map<String, dynamic>>();
    final subscription = controller.stream.listen((_) {});
    return _CallbackSubscription<Map<String, dynamic>>(
      subscription,
      onCancel: () async {
        await onCancel();
        await controller.close();
      },
    );
  }
}

class _CallbackSubscription<T> implements StreamSubscription<T> {
  _CallbackSubscription(this._inner, {required this.onCancel});

  final StreamSubscription<T> _inner;
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
    _inner.onData(handleData);
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
