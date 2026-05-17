import '../models/customer_order_model.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_service.dart';

class CustomerOrderApiService {
  CustomerOrderApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<CustomerOrderSummaryModel>> fetchOrders({
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if ((status ?? '').trim().isNotEmpty) 'status': status!.trim(),
    };

    Map<String, dynamic> response;
    try {
      response = await _apiClient.get(
        '/v1/orders',
        queryParams: queryParams,
        headers: await AuthService.authorizedHeaders(
          includeJsonContentType: false,
        ),
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }

    final success = response['success'] == true;
    if (!success) {
      throw ApiException(
        response['message']?.toString() ?? 'Gagal mengambil daftar order.',
      );
    }

    final rawData = response['data'];
    if (rawData is! List) {
      return const <CustomerOrderSummaryModel>[];
    }

    return rawData
        .whereType<Map<String, dynamic>>()
        .map(CustomerOrderSummaryModel.fromJson)
        .toList(growable: false);
  }

  Future<CustomerOrderDetailModel> fetchOrderDetail(int orderId) async {
    Map<String, dynamic> response;
    try {
      response = await _apiClient.get(
        '/v1/orders/$orderId',
        headers: await AuthService.authorizedHeaders(
          includeJsonContentType: false,
        ),
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }

    final success = response['success'] == true;
    if (!success) {
      throw ApiException(
        response['message']?.toString() ?? 'Gagal mengambil detail order.',
      );
    }

    final rawData = response['data'];
    if (rawData is! Map<String, dynamic>) {
      throw const ApiException('Format detail order tidak valid dari server.');
    }

    return CustomerOrderDetailModel.fromJson(rawData);
  }

  Future<void> cancelOrder(int orderId, {required String reason}) async {
    Map<String, dynamic> response;
    try {
      response = await _apiClient.post(
        '/v1/orders/$orderId/cancel',
        body: <String, dynamic>{'reason': reason.trim()},
        headers: await AuthService.authorizedHeaders(),
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }

    final success = response['success'] == true;
    if (!success) {
      throw ApiException(
        response['message']?.toString() ?? 'Gagal membatalkan order.',
      );
    }
  }

  Future<CustomerOrderDetailModel> addShoppingItem(
    int orderId, {
    int? merchantId,
    required String name,
    required int quantity,
    String? notes,
  }) async {
    return addShoppingItems(orderId, [
      ShoppingItemDraftPayload(
        merchantId: merchantId,
        name: name,
        quantity: quantity,
        notes: notes,
      ),
    ]);
  }

  Future<CustomerOrderDetailModel> addShoppingItems(
    int orderId,
    List<ShoppingItemDraftPayload> items, {
    int? replacementForPickupLocationId,
  }) async {
    final response = await _shoppingItemRequest(
      () async => _apiClient.post(
        '/v1/orders/$orderId/items/bulk',
        body: <String, dynamic>{
          if (replacementForPickupLocationId != null &&
              replacementForPickupLocationId > 0)
            'replacement_for_pickup_location_id':
                replacementForPickupLocationId,
          'items': items.map((item) => item.toJson()).toList(growable: false),
        },
        headers: await AuthService.authorizedHeaders(),
      ),
    );

    return CustomerOrderDetailModel.fromJson(response);
  }

  Future<List<ShoppingMerchantOption>> searchShoppingMerchants(
    String query, {
    String? merchantType,
  }) async {
    final response = await _apiClient.get(
      '/v1/restaurants',
      queryParams: <String, dynamic>{
        'per_page': 20,
        'sort': 'rating',
        if ((merchantType ?? '').trim().isNotEmpty)
          'merchant_type': merchantType!.trim(),
        if (query.trim().isNotEmpty) 'search': query.trim(),
      },
    );

    return _extractList(
      response['data'],
    ).map(ShoppingMerchantOption.fromJson).toList(growable: false);
  }

  Future<List<ShoppingMenuOption>> searchMerchantMenus(
    int merchantId,
    String query,
  ) async {
    final response = await _apiClient.get(
      '/v1/restaurants/$merchantId/menus',
      queryParams: <String, dynamic>{
        'only_available': '1',
        if (query.trim().isNotEmpty) 'search': query.trim(),
      },
    );
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return _extractList(
      data['menus'],
    ).map(ShoppingMenuOption.fromJson).toList(growable: false);
  }

  Future<CustomerOrderDetailModel> updateShoppingItem(
    int orderId,
    int itemId, {
    required String name,
    required int quantity,
    String? notes,
  }) async {
    final response = await _shoppingItemRequest(
      () async => _apiClient.patch(
        '/v1/orders/$orderId/items/$itemId',
        body: <String, dynamic>{
          'menu_name': name.trim(),
          'quantity': quantity,
          'notes': notes?.trim(),
        },
        headers: await AuthService.authorizedHeaders(),
      ),
    );

    return CustomerOrderDetailModel.fromJson(response);
  }

  Future<CustomerOrderDetailModel> removeShoppingItem(
    int orderId,
    int itemId,
  ) async {
    final response = await _shoppingItemRequest(
      () async => _apiClient.delete(
        '/v1/orders/$orderId/items/$itemId',
        headers: await AuthService.authorizedHeaders(
          includeJsonContentType: false,
        ),
      ),
    );

    return CustomerOrderDetailModel.fromJson(response);
  }

  Future<CustomerOrderDetailModel> skipFailedShoppingStop(
    int orderId,
    int pickupLocationId,
  ) async {
    final response = await _shoppingItemRequest(
      () async => _apiClient.post(
        '/v1/orders/$orderId/shopping-stops/$pickupLocationId/skip',
        headers: await AuthService.authorizedHeaders(),
      ),
    );

    return CustomerOrderDetailModel.fromJson(response);
  }

  Future<Map<String, dynamic>> _shoppingItemRequest(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    Map<String, dynamic> response;
    try {
      response = await request();
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }

    final success = response['success'] == true;
    if (!success) {
      throw ApiException(
        response['message']?.toString() ?? 'Gagal memperbarui item belanja.',
      );
    }

    final rawData = response['data'];
    if (rawData is! Map<String, dynamic>) {
      throw const ApiException('Format detail order tidak valid dari server.');
    }

    return rawData;
  }

  List<Map<String, dynamic>> _extractList(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList(growable: false);
    }

    return const <Map<String, dynamic>>[];
  }
}

class ShoppingMerchantOption {
  final int id;
  final String name;
  final String? slug;
  final String? merchantType;
  final String? address;

  const ShoppingMerchantOption({
    required this.id,
    required this.name,
    required this.slug,
    required this.merchantType,
    required this.address,
  });

  factory ShoppingMerchantOption.fromJson(Map<String, dynamic> json) {
    return ShoppingMerchantOption(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? '-').toString(),
      slug: json['slug']?.toString(),
      merchantType: json['merchant_type']?.toString(),
      address: json['address']?.toString(),
    );
  }
}

class ShoppingItemDraftPayload {
  final int? merchantId;
  final String name;
  final int quantity;
  final String? notes;

  const ShoppingItemDraftPayload({
    required this.merchantId,
    required this.name,
    required this.quantity,
    required this.notes,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (merchantId != null && merchantId! > 0) 'merchant_id': merchantId,
      'item_source': 'MANUAL',
      'menu_name': name.trim(),
      'quantity': quantity,
      if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
    };
  }
}

class ShoppingMenuOption {
  final int id;
  final String name;
  final double price;

  const ShoppingMenuOption({
    required this.id,
    required this.name,
    required this.price,
  });

  factory ShoppingMenuOption.fromJson(Map<String, dynamic> json) {
    return ShoppingMenuOption(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? '-').toString(),
      price: _toDouble(json['price']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
