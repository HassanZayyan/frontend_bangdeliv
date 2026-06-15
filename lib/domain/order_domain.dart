class ServiceTypeCode {
  const ServiceTypeCode._();

  static const ride = 'RIDE';
  static const courier = 'COURIER';
  static const shopping = 'SHOPPING';
  static const unknown = 'UNKNOWN';

  static const values = <String>{ride, courier, shopping};

  static String normalize(String raw) {
    final normalized = raw
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    switch (normalized) {
      case ride:
      case 'ANTAR_JEMPUT':
      case 'ANTAR_JEMPUT_ORANG':
        return ride;
      case courier:
      case 'KURIR':
      case 'ANTAR_BARANG':
        return courier;
      case shopping:
      case 'NITIP':
      case 'TITIP_BELANJA':
        return shopping;
      default:
        return normalized.isEmpty ? unknown : normalized;
    }
  }
}

class ChatbotServiceType {
  const ChatbotServiceType._();

  static const ride = 'antar_jemput';
  static const courier = 'kurir';
  static const shopping = 'nitip';

  static String fromServiceCode(String code) {
    switch (ServiceTypeCode.normalize(code)) {
      case ServiceTypeCode.ride:
        return ride;
      case ServiceTypeCode.courier:
        return courier;
      case ServiceTypeCode.shopping:
        return shopping;
      default:
        return shopping;
    }
  }
}

class OrderStatusCode {
  const OrderStatusCode._();

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

  static String normalize(String? code) => (code ?? '').trim().toUpperCase();
}

class PaymentMethodCode {
  const PaymentMethodCode._();

  static const cod = 'COD';
  static const transfer = 'TRANSFER';

  static String normalize(String? value) {
    final normalized = (value ?? '').trim().toUpperCase();
    return normalized == transfer ? transfer : cod;
  }
}

class ProofTypeCode {
  const ProofTypeCode._();

  static const pickup = 'pickup';
  static const delivery = 'delivery';
  static const receipt = 'receipt';
  static const storeClosed = 'store_closed';
  static const paymentTransfer = 'payment_transfer';
}

class DriverActionCode {
  const DriverActionCode._();

  static const arrivePickup = 'ARRIVE_PICKUP';
  static const confirmPickedUp = 'CONFIRM_PICKED_UP';
  static const startDelivery = 'START_DELIVERY';
  static const arriveDropoff = 'ARRIVE_DROPOFF';
  static const confirmDelivered = 'CONFIRM_DELIVERED';
  static const completeOrder = 'COMPLETE_ORDER';
  static const collectCod = 'COLLECT_COD';
  static const cancelWithFee = 'CANCEL_WITH_FEE';
}
