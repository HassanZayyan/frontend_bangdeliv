import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/firebase_notification_service.dart';
import '../../auth/application/auth_session_provider.dart';
import 'order_realtime_hub_provider.dart';

typedef OrderPriceChangedNotification =
    Future<void> Function({
      required int orderId,
      required String recipientRole,
      required String changeType,
      int priceEventId,
      bool requiresResponse,
      num? amount,
      num? oldTotalPrice,
      num? newTotalPrice,
      String? focus,
      int? pickupLocationId,
    });

final orderPriceChangedNotificationProvider =
    Provider<OrderPriceChangedNotification>((ref) {
      return ({
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
      }) {
        return FirebaseNotificationService.showLocalOrderPriceChangedNotification(
          orderId: orderId,
          recipientRole: recipientRole,
          changeType: changeType,
          priceEventId: priceEventId,
          requiresResponse: requiresResponse,
          amount: amount,
          oldTotalPrice: oldTotalPrice,
          newTotalPrice: newTotalPrice,
          focus: focus,
          pickupLocationId: pickupLocationId,
        );
      };
    });

final orderPriceHeadsUpNotificationProvider = Provider<void>((ref) {
  final session = ref.watch(authSessionIdentityProvider);
  if (!session.isOrderChatParticipant) {
    return;
  }

  final recipientRole = session.isDriver ? 'driver' : 'customer';
  final subscription = ref
      .watch(orderRealtimeHubProvider)
      .events
      .where((event) => event.type == OrderRealtimeEventType.content)
      .listen((event) {
        if (event.orderId <= 0) {
          return;
        }

        final payload = event.payload ?? const <String, dynamic>{};
        final changeType = _stringValue(
          payload['change_type'] ?? payload['changeType'],
        ).toUpperCase();
        if (!_isPricingChange(changeType)) {
          return;
        }

        final pricing = _mapValue(payload['pricing']);
        // Pembatalan sudah dikabarkan lewat notifikasi status order. Ongkir
        // sengaja dinolkan pada pembatalan berbiaya, jadi notifikasi harga di
        // sini hanya akan melaporkan Rp0.
        if (_isCancelledOrder(payload, pricing)) {
          return;
        }
        final priceEventId = _intValue(
          payload['price_event_id'] ?? pricing['price_event_id'],
        );
        final amount = _amountForChange(changeType, payload, pricing);
        final oldTotalPrice = _numValue(
          payload['old_total_price'] ?? pricing['old_total_price'],
        );
        final newTotalPrice = _numValue(
          payload['new_total_price'] ??
              pricing['new_total_price'] ??
              pricing['total_price'],
        );
        final pickupLocationId = _intValue(
          payload['pickup_location_id'] ?? pricing['pickup_location_id'],
        );

        unawaited(
          ref.read(orderPriceChangedNotificationProvider)(
            orderId: event.orderId,
            recipientRole: recipientRole,
            changeType: changeType,
            priceEventId: priceEventId,
            requiresResponse: _requiresResponse(changeType, recipientRole),
            amount: amount,
            oldTotalPrice: oldTotalPrice,
            newTotalPrice: newTotalPrice,
            focus: _focusForChange(changeType),
            pickupLocationId: pickupLocationId,
          ),
        );
      });

  ref.onDispose(() {
    unawaited(subscription.cancel());
  });
});

bool _isCancelledOrder(
  Map<String, dynamic> payload,
  Map<String, dynamic> pricing,
) {
  final statusCode = _stringValue(
    payload['status_code'] ?? pricing['status_code'],
  ).toUpperCase();

  return statusCode == 'CANCELLED' || statusCode == 'CANCELLED_WITH_FEE';
}

bool _isPricingChange(String changeType) {
  if (changeType.isEmpty) {
    return false;
  }

  return changeType.contains('PRICE') ||
      changeType.contains('FEE') ||
      changeType.contains('TOTAL') ||
      changeType.contains('NEGOTIATION');
}

bool _requiresResponse(String changeType, String recipientRole) {
  if (changeType.contains('PENDING_CUSTOMER')) {
    return recipientRole == 'customer';
  }
  if (changeType.contains('PENDING_DRIVER') || changeType.contains('COUNTER')) {
    return recipientRole == 'driver';
  }
  if (changeType.contains('QUOTED')) {
    return recipientRole == 'customer';
  }

  return false;
}

String? _focusForChange(String changeType) {
  if (changeType.contains('DELIVERY_FEE') || changeType.contains('FEE')) {
    return 'delivery_fee';
  }
  if (changeType.contains('PRICE') ||
      changeType.contains('TOTAL') ||
      changeType.contains('NEGOTIATION')) {
    return 'shopping_price';
  }

  return null;
}

num? _amountForChange(
  String changeType,
  Map<String, dynamic> payload,
  Map<String, dynamic> pricing,
) {
  final keys = changeType.contains('DELIVERY_FEE') || changeType.contains('FEE')
      ? const <String>[
          'new_delivery_fee',
          'delivery_fee',
          'quoted_amount',
          'counter_amount',
          'approved_amount',
          'amount',
        ]
      : const <String>[
          'new_total_price',
          'total_price',
          'new_subtotal',
          'subtotal',
          'quoted_amount',
          'counter_amount',
          'approved_amount',
          'amount',
        ];

  for (final key in keys) {
    final value = _numValue(payload[key] ?? pricing[key]);
    if (value != null) {
      return value;
    }
  }

  return null;
}

Map<String, dynamic> _mapValue(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return const <String, dynamic>{};
}

String _stringValue(Object? value) {
  return value?.toString().trim() ?? '';
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

num? _numValue(Object? value) {
  if (value is num) {
    return value;
  }

  return num.tryParse(value?.toString() ?? '');
}
