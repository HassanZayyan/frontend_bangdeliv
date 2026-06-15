import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/driver_order_model.dart';
import '../../models/order_chat_model.dart';

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

abstract class OrderRealtimeClient {
  Future<void> connect();

  StreamSubscription<Map<String, dynamic>> subscribeOrderTracking(
    int orderId, {
    void Function(double lat, double lng, DateTime updatedAt)? onLocation,
    void Function(OrderStatusRealtimeEvent event)? onStatusChanged,
    void Function(Map<String, dynamic> payload)? onContentUpdated,
    void Function(OrderChatMessageModel message)? onChatMessage,
    VoidCallback? onSubscribed,
    void Function(Object error)? onConnectionIssue,
  });

  StreamSubscription<Map<String, dynamic>> subscribeDriverOrders(
    int userId, {
    void Function(DriverOrderModel order)? onOrderAvailable,
    void Function(String orderId, String? reason)? onOrderRemoved,
    VoidCallback? onSubscribed,
    void Function(Object error)? onConnectionIssue,
  });

  Future<void> disconnect();
}
