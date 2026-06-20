import 'package:image_picker/image_picker.dart';

import '../../models/driver_order_model.dart';
import '../../services/driver_order_service.dart';

abstract class DriverOrderRepository {
  Future<DriverOrdersPayload> fetchOrders();

  Future<DriverOrderModel> fetchOrderDetail(String orderId);

  Future<DriverOrderModel> acceptOrder(String orderId);

  Future<void> rejectOrder(String orderId);

  Future<DriverOrderModel> transitionStatus({
    required String orderId,
    required String actionCode,
    String? targetStatusCode,
    String? note,
  });

  Future<void> collectCod({
    required String orderId,
    required double amount,
    String? note,
  });

  Future<DriverOrderModel> confirmTransferPayment({
    required String orderId,
    required double amount,
  });

  Future<DriverOrderModel> updateDeliveryFeeOverride({
    required String orderId,
    required double amount,
    required String reason,
  });

  Future<DriverOrderModel> acceptDeliveryFeeCounterOffer({
    required String orderId,
    String? note,
  });

  Future<void> updateDriverLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    DateTime? updatedAt,
  });

  Future<void> updateCurrentDriverLocation({
    required double latitude,
    required double longitude,
    DateTime? updatedAt,
  });

  Future<DriverOrderModel> uploadProof({
    required String orderId,
    required String type,
    required XFile photo,
    String? note,
    int? pickupLocationId,
  });

  Future<DriverOrderModel> updateShoppingCheckout({
    required String orderId,
    required List<Map<String, dynamic>> items,
    XFile? receiptPhoto,
  });

  Future<DriverOrderModel> updateShoppingItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
    int? pickupLocationId,
  });

  Future<DriverOrderModel> submitShoppingPriceQuote({
    required String orderId,
    required double amount,
    int? pickupLocationId,
  });

  Future<DriverOrderModel> bypassShoppingPriceQuote({
    required String orderId,
    required int pickupLocationId,
  });

  Future<DriverOrderModel> markShoppingMerchantOpen({
    required String orderId,
    required int pickupLocationId,
  });

  Future<DriverOrderModel> respondShoppingItemChange({
    required String orderId,
    required String action,
    String? note,
  });

  Future<DriverOrderModel> recordShoppingPickupFailed({
    required String orderId,
    required int pickupLocationId,
    required String reason,
  });

  Future<String> fetchAvailabilityStatus();

  Future<String> updateAvailability({required bool isOnline});

  Future<List<DriverHistoryOrderModel>> fetchHistory();
}

class ApiDriverOrderRepository implements DriverOrderRepository {
  const ApiDriverOrderRepository(this._service);

  final DriverOrderService _service;

  @override
  Future<DriverOrdersPayload> fetchOrders() => _service.fetchOrders();

  @override
  Future<DriverOrderModel> fetchOrderDetail(String orderId) {
    return _service.fetchOrderDetail(orderId);
  }

  @override
  Future<DriverOrderModel> acceptOrder(String orderId) {
    return _service.acceptOrder(orderId);
  }

  @override
  Future<void> rejectOrder(String orderId) {
    return _service.rejectOrder(orderId);
  }

  @override
  Future<DriverOrderModel> transitionStatus({
    required String orderId,
    required String actionCode,
    String? targetStatusCode,
    String? note,
  }) {
    return _service.transitionStatus(
      orderId: orderId,
      actionCode: actionCode,
      targetStatusCode: targetStatusCode,
      note: note,
    );
  }

  @override
  Future<void> collectCod({
    required String orderId,
    required double amount,
    String? note,
  }) {
    return _service.collectCod(orderId: orderId, amount: amount, note: note);
  }

  @override
  Future<DriverOrderModel> confirmTransferPayment({
    required String orderId,
    required double amount,
  }) {
    return _service.confirmTransferPayment(orderId: orderId, amount: amount);
  }

  @override
  Future<DriverOrderModel> updateDeliveryFeeOverride({
    required String orderId,
    required double amount,
    required String reason,
  }) {
    return _service.updateDeliveryFeeOverride(
      orderId: orderId,
      amount: amount,
      reason: reason,
    );
  }

  @override
  Future<DriverOrderModel> acceptDeliveryFeeCounterOffer({
    required String orderId,
    String? note,
  }) {
    return _service.acceptDeliveryFeeCounterOffer(orderId: orderId, note: note);
  }

  @override
  Future<void> updateDriverLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    DateTime? updatedAt,
  }) {
    return _service.updateDriverLocation(
      orderId: orderId,
      latitude: latitude,
      longitude: longitude,
      updatedAt: updatedAt,
    );
  }

  @override
  Future<void> updateCurrentDriverLocation({
    required double latitude,
    required double longitude,
    DateTime? updatedAt,
  }) {
    return _service.updateCurrentDriverLocation(
      latitude: latitude,
      longitude: longitude,
      updatedAt: updatedAt,
    );
  }

  @override
  Future<DriverOrderModel> uploadProof({
    required String orderId,
    required String type,
    required XFile photo,
    String? note,
    int? pickupLocationId,
  }) {
    return _service.uploadProof(
      orderId: orderId,
      type: type,
      photo: photo,
      note: note,
      pickupLocationId: pickupLocationId,
    );
  }

  @override
  Future<DriverOrderModel> updateShoppingCheckout({
    required String orderId,
    required List<Map<String, dynamic>> items,
    XFile? receiptPhoto,
  }) {
    return _service.updateShoppingCheckout(
      orderId: orderId,
      items: items,
      receiptPhoto: receiptPhoto,
    );
  }

  @override
  Future<DriverOrderModel> updateShoppingItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
    int? pickupLocationId,
  }) {
    return _service.updateShoppingItems(
      orderId: orderId,
      items: items,
      pickupLocationId: pickupLocationId,
    );
  }

  @override
  Future<DriverOrderModel> submitShoppingPriceQuote({
    required String orderId,
    required double amount,
    int? pickupLocationId,
  }) {
    return _service.submitShoppingPriceQuote(
      orderId: orderId,
      amount: amount,
      pickupLocationId: pickupLocationId,
    );
  }

  @override
  Future<DriverOrderModel> bypassShoppingPriceQuote({
    required String orderId,
    required int pickupLocationId,
  }) {
    return _service.bypassShoppingPriceQuote(
      orderId: orderId,
      pickupLocationId: pickupLocationId,
    );
  }

  @override
  Future<DriverOrderModel> markShoppingMerchantOpen({
    required String orderId,
    required int pickupLocationId,
  }) {
    return _service.markShoppingMerchantOpen(
      orderId: orderId,
      pickupLocationId: pickupLocationId,
    );
  }

  @override
  Future<DriverOrderModel> respondShoppingItemChange({
    required String orderId,
    required String action,
    String? note,
  }) {
    return _service.respondShoppingItemChange(
      orderId: orderId,
      action: action,
      note: note,
    );
  }

  @override
  Future<DriverOrderModel> recordShoppingPickupFailed({
    required String orderId,
    required int pickupLocationId,
    required String reason,
  }) {
    return _service.recordShoppingPickupFailed(
      orderId: orderId,
      pickupLocationId: pickupLocationId,
      reason: reason,
    );
  }

  @override
  Future<String> fetchAvailabilityStatus() {
    return _service.fetchAvailabilityStatus();
  }

  @override
  Future<String> updateAvailability({required bool isOnline}) {
    return _service.updateAvailability(isOnline: isOnline);
  }

  @override
  Future<List<DriverHistoryOrderModel>> fetchHistory() {
    return _service.fetchHistory();
  }
}
