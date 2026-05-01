class OrderStatusCodes {
  const OrderStatusCodes._();

  static const pending = 'PENDING';
  static const driverAssigned = 'DRIVER_ASSIGNED';
  static const pickedUp = 'PICKED_UP';
  static const onTheWay = 'ON_THE_WAY';
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

String orderStatusLabel(String code) {
  switch (normalizeOrderStatusCode(code)) {
    case OrderStatusCodes.pending:
      return 'Menunggu Driver';
    case OrderStatusCodes.driverAssigned:
      return 'Driver Ditugaskan';
    case OrderStatusCodes.pickedUp:
      return 'Pesanan Diambil';
    case OrderStatusCodes.onTheWay:
      return 'Dalam Perjalanan';
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

