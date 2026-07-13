import '../domain/order_domain.dart';

class OrderStatusCodes {
  const OrderStatusCodes._();

  static const pending = OrderStatusCode.pending;
  static const driverAssigned = OrderStatusCode.driverAssigned;
  static const arrivedMerchant = OrderStatusCode.arrivedMerchant;
  static const arrivedPickup = OrderStatusCode.arrivedPickup;
  static const pickedUp = OrderStatusCode.pickedUp;
  static const onTheWay = OrderStatusCode.onTheWay;
  static const arrivedDropoff = OrderStatusCode.arrivedDropoff;
  static const delivered = OrderStatusCode.delivered;
  static const completed = OrderStatusCode.completed;
  static const cancelled = OrderStatusCode.cancelled;
  static const cancelledWithFee = OrderStatusCode.cancelledWithFee;
}

String normalizeOrderStatusCode(String? code) {
  return OrderStatusCode.normalize(code);
}

bool isTerminalOrderStatus(String code) {
  switch (normalizeOrderStatusCode(code)) {
    case OrderStatusCodes.completed:
    case OrderStatusCodes.cancelled:
    case OrderStatusCodes.cancelledWithFee:
      return true;
    default:
      return false;
  }
}

bool isDriverRunningOrderStatus(String code) {
  switch (normalizeOrderStatusCode(code)) {
    case OrderStatusCodes.driverAssigned:
    case OrderStatusCodes.arrivedMerchant:
    case OrderStatusCodes.arrivedPickup:
    case OrderStatusCodes.pickedUp:
    case OrderStatusCodes.onTheWay:
    case OrderStatusCodes.arrivedDropoff:
    case OrderStatusCodes.delivered:
    case OrderStatusCodes.cancelledWithFee:
      return true;
    default:
      return false;
  }
}

bool isDriverRunningOrder({required String statusCode, String? paymentStatus}) {
  final normalizedStatus = normalizeOrderStatusCode(statusCode);
  if (normalizedStatus == OrderStatusCodes.cancelledWithFee) {
    return (paymentStatus ?? '').trim().toLowerCase() != 'paid';
  }

  return isDriverRunningOrderStatus(normalizedStatus);
}

bool isCancelledOrderStatus(String code) {
  switch (normalizeOrderStatusCode(code)) {
    case OrderStatusCodes.cancelled:
    case OrderStatusCodes.cancelledWithFee:
      return true;
    default:
      return false;
  }
}

bool isDriverLocationTrackable(String? code, {String? statusLabel}) {
  switch (normalizeOrderStatusCode(code)) {
    case OrderStatusCodes.driverAssigned:
    case OrderStatusCodes.arrivedMerchant:
    case OrderStatusCodes.arrivedPickup:
    case OrderStatusCodes.pickedUp:
    case OrderStatusCodes.onTheWay:
      return true;
    default:
      final compactCode = _compactStatusToken(code);
      final compactLabel = _compactStatusToken(statusLabel);

      if (_isPickupArrivalStatus(compactCode, compactLabel)) {
        return true;
      }

      return false;
  }
}

String orderStatusLabel(String code) {
  switch (normalizeOrderStatusCode(code)) {
    case OrderStatusCodes.pending:
      return 'Menunggu Driver';
    case OrderStatusCodes.driverAssigned:
      return 'Driver Ditugaskan';
    case OrderStatusCodes.arrivedMerchant:
      return 'Driver tiba di lokasi ambil';
    case OrderStatusCodes.arrivedPickup:
      return 'Driver Tiba di Titik Jemput';
    case OrderStatusCodes.pickedUp:
      return 'Pesanan Diambil';
    case OrderStatusCodes.onTheWay:
      return 'Dalam Perjalanan';
    case OrderStatusCodes.arrivedDropoff:
      return 'Driver Tiba di Tujuan';
    case OrderStatusCodes.delivered:
      return 'Sudah Sampai Tujuan';
    case OrderStatusCodes.completed:
      return 'Selesai';
    case OrderStatusCodes.cancelled:
      return 'Dibatalkan';
    case OrderStatusCodes.cancelledWithFee:
      return 'Dibatalkan Dengan Biaya';
    default:
      return code.trim().isEmpty ? 'Status Tidak Diketahui' : code;
  }
}

String orderStatusDisplayLabel(String code, {String? fallbackLabel}) {
  final normalizedCode = normalizeOrderStatusCode(code);

  if (normalizedCode == OrderStatusCodes.arrivedMerchant) {
    return orderStatusLabel(normalizedCode);
  }

  final trimmedLabel = fallbackLabel?.trim();
  if (trimmedLabel != null && trimmedLabel.isNotEmpty) {
    return trimmedLabel;
  }

  return orderStatusLabel(normalizedCode);
}

int resolveTrackingStepIndex({
  required String? statusCode,
  String? statusLabel,
}) {
  final normalizedCode = normalizeOrderStatusCode(statusCode);
  final compactCode = _compactStatusToken(statusCode);
  final compactLabel = _compactStatusToken(statusLabel);

  switch (normalizedCode) {
    case OrderStatusCodes.pending:
      return 0;
    case OrderStatusCodes.driverAssigned:
      return 1;
    case OrderStatusCodes.arrivedMerchant:
    case OrderStatusCodes.arrivedPickup:
    case OrderStatusCodes.pickedUp:
      return 2;
    case OrderStatusCodes.onTheWay:
      return 3;
    case OrderStatusCodes.arrivedDropoff:
    case OrderStatusCodes.delivered:
    case OrderStatusCodes.completed:
      return 4;
    default:
      break;
  }

  if (_isDropoffArrivalStatus(compactCode, compactLabel)) {
    return 4;
  }

  if (_containsAny(compactCode, compactLabel, const ['ON_THE_WAY']) ||
      _containsAny(compactCode, compactLabel, const ['DALAM_PERJALANAN']) ||
      _containsAny(compactCode, compactLabel, const ['PERJALANAN'])) {
    return 3;
  }

  if (_isPickupArrivalStatus(compactCode, compactLabel) ||
      _containsAny(compactCode, compactLabel, const ['PICKED_UP']) ||
      _containsAny(compactCode, compactLabel, const ['PICKUP'])) {
    return 2;
  }

  if (_containsAny(compactCode, compactLabel, const ['DRIVER_ASSIGNED']) ||
      _containsAny(compactCode, compactLabel, const ['DITUGASKAN'])) {
    return 1;
  }

  return 0;
}

bool _isDropoffArrivalStatus(String compactCode, String compactLabel) {
  return _containsAny(compactCode, compactLabel, const ['ARRIVED_DROPOFF']) ||
      _containsAny(compactCode, compactLabel, const ['DRIVER_TIBA_DI_TUJUAN']);
}

bool _isPickupArrivalStatus(String compactCode, String compactLabel) {
  return _containsAny(compactCode, compactLabel, const ['ARRIVED_PICKUP']) ||
      _containsAny(compactCode, compactLabel, const ['ARRIVED_MERCHANT']) ||
      _containsAny(compactCode, compactLabel, const ['TIBA_DI_TITIK_JEMPUT']) ||
      _containsAny(compactCode, compactLabel, const ['TIBA_DI_JEMPUT']) ||
      _containsAny(compactCode, compactLabel, const ['TIBA_DI_MERCHANT']) ||
      _containsAny(compactCode, compactLabel, const ['TIBA_DI_LOKASI_AMBIL']);
}

bool _containsAny(String compactCode, String compactLabel, List<String> keys) {
  for (final key in keys) {
    if (compactCode.contains(key) || compactLabel.contains(key)) {
      return true;
    }
  }
  return false;
}

String _compactStatusToken(String? value) {
  final normalized = normalizeOrderStatusCode(value);
  return normalized
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}
