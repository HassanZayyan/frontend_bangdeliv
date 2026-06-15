import 'package:image_picker/image_picker.dart';

import '../../models/customer_order_model.dart';
import '../../services/customer_order_api_service.dart';

abstract class CustomerOrderRepository {
  Future<List<CustomerOrderSummaryModel>> fetchOrders({
    String? status,
    int page = 1,
    int perPage = 20,
  });

  Future<CustomerOrderDetailModel> fetchOrderDetail(int orderId);

  Future<void> cancelOrder(int orderId, {required String reason});

  Future<CustomerOrderDetailModel> uploadTransferEvidence(
    int orderId, {
    required XFile photo,
    String? note,
  });

  Future<CustomerOrderDetailModel> addShoppingItems(
    int orderId,
    List<ShoppingItemDraftPayload> items, {
    int? replacementForPickupLocationId,
  });

  Future<CustomerOrderDetailModel> updateShoppingItem(
    int orderId,
    int itemId, {
    required String name,
    required int quantity,
    String? notes,
  });

  Future<CustomerOrderDetailModel> removeShoppingItem(int orderId, int itemId);

  Future<CustomerOrderDetailModel> skipFailedShoppingStop(
    int orderId,
    int pickupLocationId,
  );

  Future<List<ShoppingMerchantOption>> searchShoppingMerchants(
    String query, {
    String? merchantType,
  });

  Future<List<ShoppingMenuOption>> searchMerchantMenus(
    int merchantId,
    String query,
  );
}

class ApiCustomerOrderRepository implements CustomerOrderRepository {
  const ApiCustomerOrderRepository(this._service);

  final CustomerOrderApiService _service;

  @override
  Future<List<CustomerOrderSummaryModel>> fetchOrders({
    String? status,
    int page = 1,
    int perPage = 20,
  }) {
    return _service.fetchOrders(status: status, page: page, perPage: perPage);
  }

  @override
  Future<CustomerOrderDetailModel> fetchOrderDetail(int orderId) {
    return _service.fetchOrderDetail(orderId);
  }

  @override
  Future<void> cancelOrder(int orderId, {required String reason}) {
    return _service.cancelOrder(orderId, reason: reason);
  }

  @override
  Future<CustomerOrderDetailModel> uploadTransferEvidence(
    int orderId, {
    required XFile photo,
    String? note,
  }) {
    return _service.uploadTransferEvidence(orderId, photo: photo, note: note);
  }

  @override
  Future<CustomerOrderDetailModel> addShoppingItems(
    int orderId,
    List<ShoppingItemDraftPayload> items, {
    int? replacementForPickupLocationId,
  }) {
    return _service.addShoppingItems(
      orderId,
      items,
      replacementForPickupLocationId: replacementForPickupLocationId,
    );
  }

  @override
  Future<CustomerOrderDetailModel> updateShoppingItem(
    int orderId,
    int itemId, {
    required String name,
    required int quantity,
    String? notes,
  }) {
    return _service.updateShoppingItem(
      orderId,
      itemId,
      name: name,
      quantity: quantity,
      notes: notes,
    );
  }

  @override
  Future<CustomerOrderDetailModel> removeShoppingItem(int orderId, int itemId) {
    return _service.removeShoppingItem(orderId, itemId);
  }

  @override
  Future<CustomerOrderDetailModel> skipFailedShoppingStop(
    int orderId,
    int pickupLocationId,
  ) {
    return _service.skipFailedShoppingStop(orderId, pickupLocationId);
  }

  @override
  Future<List<ShoppingMerchantOption>> searchShoppingMerchants(
    String query, {
    String? merchantType,
  }) {
    return _service.searchShoppingMerchants(query, merchantType: merchantType);
  }

  @override
  Future<List<ShoppingMenuOption>> searchMerchantMenus(
    int merchantId,
    String query,
  ) {
    return _service.searchMerchantMenus(merchantId, query);
  }
}
