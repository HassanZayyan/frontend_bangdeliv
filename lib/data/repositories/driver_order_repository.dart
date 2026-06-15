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
    String? note,
  });

  Future<DriverOrderModel> updateDeliveryFeeOverride({
    required String orderId,
    required double amount,
    required String reason,
    bool? carefulCarryRequired,
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
    required double shoppingTotalAmount,
    double? deliveryFeeOverride,
    String? receiptNote,
    XFile? receiptPhoto,
  });

  Future<DriverOrderModel> updateShoppingItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
    String? receiptNote,
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
    String? note,
  }) {
    return _service.confirmTransferPayment(
      orderId: orderId,
      amount: amount,
      note: note,
    );
  }

  @override
  Future<DriverOrderModel> updateDeliveryFeeOverride({
    required String orderId,
    required double amount,
    required String reason,
    bool? carefulCarryRequired,
  }) {
    return _service.updateDeliveryFeeOverride(
      orderId: orderId,
      amount: amount,
      reason: reason,
      carefulCarryRequired: carefulCarryRequired,
    );
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
    required double shoppingTotalAmount,
    double? deliveryFeeOverride,
    String? receiptNote,
    XFile? receiptPhoto,
  }) {
    return _service.updateShoppingCheckout(
      orderId: orderId,
      items: items,
      shoppingTotalAmount: shoppingTotalAmount,
      deliveryFeeOverride: deliveryFeeOverride,
      receiptNote: receiptNote,
      receiptPhoto: receiptPhoto,
    );
  }

  @override
  Future<DriverOrderModel> updateShoppingItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
    String? receiptNote,
  }) {
    return _service.updateShoppingItems(
      orderId: orderId,
      items: items,
      receiptNote: receiptNote,
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
