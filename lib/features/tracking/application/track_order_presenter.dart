import '../../../models/customer_order_model.dart';
import '../../../utils/order_status.dart';
import '../../../utils/service_type.dart';

class TrackRouteArgs {
  const TrackRouteArgs({this.orderId, this.fromHistory = false});

  final int? orderId;
  final bool fromHistory;
}

class TrackOrderPresenter {
  const TrackOrderPresenter._();

  static TrackRouteArgs extractRouteArgs(dynamic extra) {
    if (extra is int) {
      return TrackRouteArgs(orderId: extra);
    }
    if (extra is String) {
      return TrackRouteArgs(orderId: int.tryParse(extra));
    }
    if (extra is Map) {
      final map = Map<String, dynamic>.from(extra);
      final dynamic rawOrderId = map['orderId'] ?? map['order_id'] ?? map['id'];
      final orderId = rawOrderId is int
          ? rawOrderId
          : int.tryParse(rawOrderId?.toString() ?? '');
      final fromHistory = map['fromHistory'] == true;
      return TrackRouteArgs(orderId: orderId, fromHistory: fromHistory);
    }
    return const TrackRouteArgs();
  }

  static String appBarTitle({
    required bool forceHistoryTitle,
    required bool isTerminalStatus,
  }) {
    return forceHistoryTitle || isTerminalStatus
        ? 'Detail Pesanan'
        : 'Lacak Pesanan';
  }

  static bool shouldShowTrackingMap(CustomerOrderSummaryModel order) {
    if (order.isTerminalStatus) return false;
    return isDriverLocationTrackable(
          order.statusCode,
          statusLabel: order.statusLabel,
        ) ||
        normalizeServiceTypeCode(order.serviceTypeCode) !=
            ServiceTypeCodes.ride;
  }

  static bool isWaitingDriverStatus(CustomerOrderSummaryModel order) {
    final normalizedCode = normalizeOrderStatusCode(order.statusCode);
    if (normalizedCode == OrderStatusCodes.pending) {
      return true;
    }

    final normalizedLabel = order.statusLabel.trim().toUpperCase();
    return normalizedLabel.contains('MENUNGGU') &&
        normalizedLabel.contains('DRIVER');
  }

  static bool isPassengerDropoffStatus(CustomerOrderSummaryModel order) {
    final normalizedCode = normalizeOrderStatusCode(order.statusCode);
    if (normalizedCode == OrderStatusCodes.delivered ||
        normalizedCode == OrderStatusCodes.completed) {
      return true;
    }

    final normalizedLabel = order.statusLabel.trim().toUpperCase();
    return (normalizedLabel.contains('PENUMPANG') &&
            normalizedLabel.contains('TURUN')) ||
        normalizedLabel.contains('SUDAH SAMPAI TUJUAN');
  }

  static bool isDriverArrivedDestinationStatus(
    CustomerOrderSummaryModel order,
  ) {
    final normalizedLabel = order.statusLabel.trim().toUpperCase();
    return normalizedLabel.contains('DRIVER') &&
        normalizedLabel.contains('TIBA') &&
        normalizedLabel.contains('TUJUAN');
  }

  static String fixedStatusInfoMessage(CustomerOrderSummaryModel order) {
    if (order.isTerminalStatus) {
      return 'Order sudah selesai, peta tracking tidak lagi ditampilkan.';
    }

    if (isDriverArrivedDestinationStatus(order)) {
      return 'Driver sudah tiba di tujuan. Proses order akan segera diselesaikan.';
    }

    if (isPassengerDropoffStatus(order)) {
      return 'Penumpang sudah tiba di tujuan. Proses order akan segera diselesaikan.';
    }

    return 'Peta tracking akan muncul otomatis setelah driver mulai menuju titik jemput.';
  }

  static String normalizedPaymentMethod(
    CustomerOrderSummaryModel order,
    CustomerOrderDetailModel detail,
  ) {
    final detailMethod = (detail.paymentMethod ?? '').trim();
    if (detailMethod.isNotEmpty) {
      return detailMethod.toUpperCase();
    }

    final summaryMethod = (order.paymentMethod ?? '').trim();
    if (summaryMethod.isNotEmpty) {
      return summaryMethod.toUpperCase();
    }

    return 'COD';
  }
}
