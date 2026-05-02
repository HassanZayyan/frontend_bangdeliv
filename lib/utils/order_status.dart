class OrderStatusCodes {
  const OrderStatusCodes._();

  static const pending = 'PENDING';
  static const driverAssigned = 'DRIVER_ASSIGNED';
  static const arrivedMerchant = 'ARRIVED_MERCHANT';
  static const arrivedPickup = 'ARRIVED_PICKUP';
  static const pickedUp = 'PICKED_UP';
  static const onTheWay = 'ON_THE_WAY';
  static const arrivedDropoff = 'ARRIVED_DROPOFF';
  static const delivered = 'DELIVERED';
  static const completed = 'COMPLETED';
  static const cancelled = 'CANCELLED';
  static const cancelledWithFee = 'CANCELLED_WITH_FEE';
}

String normalizeOrderStatusCode(String? code) {
  return (code ?? '').trim().toUpperCase();
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
    case OrderStatusCodes.arrivedDropoff:
      return true;
    default:
      final compactCode = _compactStatusToken(code);
      final compactLabel = _compactStatusToken(statusLabel);

      if (_isDropoffArrivalStatus(compactCode, compactLabel) ||
          _isPickupArrivalStatus(compactCode, compactLabel)) {
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
      return 'Driver Tiba di Merchant';
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
      _containsAny(compactCode, compactLabel, const ['TIBA_DI_MERCHANT']);
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
