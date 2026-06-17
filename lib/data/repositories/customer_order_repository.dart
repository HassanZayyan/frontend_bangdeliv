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

  Future<CustomerOrderDetailModel> requestShoppingItemChange(
    int orderId, {
    required String action,
    String? requestKind,
    List<ShoppingItemDraftPayload> items,
    int? itemId,
    int? targetPickupLocationId,
    String? note,
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

  Future<CustomerOrderDetailModel> respondShoppingPriceQuote(
    int orderId, {
    required String action,
    double? counterAmount,
    int? pickupLocationId,
  });

  Future<CustomerOrderDetailModel> respondDeliveryFeeOverride(
    int orderId, {
    required String action,
    double? counterAmount,
  });

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
  Future<CustomerOrderDetailModel> requestShoppingItemChange(
    int orderId, {
    required String action,
    String? requestKind,
    List<ShoppingItemDraftPayload> items = const <ShoppingItemDraftPayload>[],
    int? itemId,
    int? targetPickupLocationId,
    String? note,
  }) {
    return _service.requestShoppingItemChange(
      orderId,
      action: action,
      requestKind: requestKind,
      items: items,
      itemId: itemId,
      targetPickupLocationId: targetPickupLocationId,
      note: note,
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
  Future<CustomerOrderDetailModel> respondShoppingPriceQuote(
    int orderId, {
    required String action,
    double? counterAmount,
    int? pickupLocationId,
  }) {
    return _service.respondShoppingPriceQuote(
      orderId,
      action: action,
      counterAmount: counterAmount,
      pickupLocationId: pickupLocationId,
    );
  }

  @override
  Future<CustomerOrderDetailModel> respondDeliveryFeeOverride(
    int orderId, {
    required String action,
    double? counterAmount,
  }) {
    return _service.respondDeliveryFeeOverride(
      orderId,
      action: action,
      counterAmount: counterAmount,
    );
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
