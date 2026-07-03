import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/firebase_notification_service.dart';
import '../../../utils/order_status.dart';
import '../../auth/application/auth_session_provider.dart';
import 'order_realtime_hub_provider.dart';

final orderStatusHeadsUpNotificationProvider = Provider<void>((ref) {
  final session = ref.watch(authSessionProvider);
  if (!session.isAuthenticated ||
      session.role != SessionUserRole.customer ||
      session.profile == null) {
    return;
  }

  final subscription = ref
      .watch(orderRealtimeHubProvider)
      .events
      .where((event) => event.type == OrderRealtimeEventType.status)
      .listen((event) {
        final status = event.status;
        if (status == null || event.orderId <= 0) {
          return;
        }

        final statusCode = normalizeOrderStatusCode(status.statusCode);
        if (statusCode.isEmpty) {
          return;
        }

        final statusLabel = orderStatusDisplayLabel(
          statusCode,
          fallbackLabel: status.statusLabel,
        );

        unawaited(
          FirebaseNotificationService.showLocalOrderStatusNotification(
            orderId: event.orderId,
            historyId: status.historyId ?? 0,
            statusCode: statusCode,
            title: _statusNotificationTitle(statusCode),
            body: _statusNotificationBody(statusCode, statusLabel),
          ),
        );
      });

  ref.onDispose(() {
    unawaited(subscription.cancel());
  });
});

String _statusNotificationTitle(String statusCode) {
  return switch (normalizeOrderStatusCode(statusCode)) {
    OrderStatusCodes.driverAssigned => 'Driver sudah ditugaskan',
    OrderStatusCodes.arrivedMerchant => 'Driver tiba di merchant',
    OrderStatusCodes.arrivedPickup => 'Driver tiba di titik jemput',
    OrderStatusCodes.pickedUp => 'Pesanan sudah diambil',
    OrderStatusCodes.onTheWay => 'Dalam perjalanan',
    OrderStatusCodes.arrivedDropoff => 'Driver tiba di tujuan',
    OrderStatusCodes.delivered => 'Pesanan sudah diterima',
    OrderStatusCodes.completed => 'Order selesai',
    OrderStatusCodes.cancelled ||
    OrderStatusCodes.cancelledWithFee => 'Order dibatalkan',
    _ => 'Status order diperbarui',
  };
}

String _statusNotificationBody(String statusCode, String statusLabel) {
  final normalizedCode = normalizeOrderStatusCode(statusCode);
  final label = statusLabel.trim().isEmpty
      ? orderStatusLabel(normalizedCode)
      : statusLabel.trim();

  return switch (normalizedCode) {
    OrderStatusCodes.driverAssigned =>
      'Driver sudah menerima order kamu dan akan menuju titik awal.',
    OrderStatusCodes.arrivedMerchant =>
      'Driver sudah tiba di merchant dan mulai memproses pesanan kamu.',
    OrderStatusCodes.arrivedPickup =>
      'Driver sudah tiba di titik ambil. Silakan bersiap.',
    OrderStatusCodes.pickedUp =>
      'Pesanan sudah diambil driver dan akan segera diantar.',
    OrderStatusCodes.onTheWay => 'Driver sedang menuju alamat tujuan.',
    OrderStatusCodes.arrivedDropoff => 'Driver sudah tiba di alamat tujuan.',
    OrderStatusCodes.delivered => 'Pesanan sudah diterima.',
    OrderStatusCodes.completed =>
      'Order kamu sudah selesai. Terima kasih sudah memakai BangDeliv.',
    OrderStatusCodes.cancelledWithFee =>
      'Order dibatalkan dengan biaya sesuai ketentuan.',
    OrderStatusCodes.cancelled => 'Order kamu sudah dibatalkan.',
    _ => 'Status order kamu sekarang: $label.',
  };
}
