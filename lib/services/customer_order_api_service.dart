import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/app_env.dart';
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

  Future<CustomerOrderDetailModel> uploadTransferEvidence(
    int orderId, {
    required XFile photo,
    String? note,
  }) async {
    final uri = _buildUri('/v1/orders/$orderId/payment/transfer/evidence');
    final request = http.MultipartRequest('POST', uri);

    try {
      request.headers.addAll(
        await AuthService.authorizedHeaders(includeJsonContentType: false),
      );
      final normalizedNote = note?.trim();
      if (normalizedNote != null && normalizedNote.isNotEmpty) {
        request.fields['note'] = normalizedNote;
      }
      request.files.add(await http.MultipartFile.fromPath('photo', photo.path));

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamed);
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('Format respons server tidak valid.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          decoded['message']?.toString() ?? 'Gagal upload bukti QRIS.',
          statusCode: response.statusCode,
        );
      }

      return _extractDetail(decoded, fallback: 'Gagal upload bukti QRIS.');
    } on AuthException catch (error) {
      throw ApiException(error.message);
    } on TimeoutException {
      throw const ApiException('Upload timeout. Coba lagi.');
    } on http.ClientException {
      throw const ApiException('Tidak dapat terhubung ke server API.');
    } on FormatException {
      throw const ApiException('Format respons server tidak valid.');
    }
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
    List<ShoppingItemDraftPayload> items,
  ) async {
    final response = await _shoppingItemRequest(
      () async => _apiClient.post(
        '/v1/orders/$orderId/items/bulk',
        body: <String, dynamic>{
          'items': items.map((item) => item.toJson()).toList(growable: false),
        },
        headers: await AuthService.authorizedHeaders(),
      ),
    );

    return CustomerOrderDetailModel.fromJson(response);
  }

  Future<CustomerOrderDetailModel> requestShoppingItemChange(
    int orderId, {
    required String action,
    String? requestKind,
    List<ShoppingItemDraftPayload> items = const <ShoppingItemDraftPayload>[],
    int? itemId,
    int? targetPickupLocationId,
    String? note,
  }) async {
    final normalizedAction = action.trim().toUpperCase();
    final response = await _shoppingItemRequest(
      () async => _apiClient.post(
        '/v1/orders/$orderId/shopping/item-change-request',
        body: <String, dynamic>{
          'action': normalizedAction,
          if ((requestKind ?? '').trim().isNotEmpty)
            'request_kind': requestKind!.trim().toUpperCase(),
          if (targetPickupLocationId != null && targetPickupLocationId > 0)
            'target_pickup_location_id': targetPickupLocationId,
          if (items.isNotEmpty)
            'items': items.map((item) => item.toJson()).toList(growable: false),
          if (itemId != null && itemId > 0) 'item_id': itemId,
          if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
        },
        headers: await AuthService.authorizedHeaders(),
      ),
    );

    return CustomerOrderDetailModel.fromJson(response);
  }

  Future<List<ShoppingMerchantOption>> searchShoppingMerchants(
    String query, {
    String? merchantType,
    int perPage = 20,
  }) async {
    final response = await _apiClient.get(
      '/v1/restaurants',
      queryParams: <String, dynamic>{
        'per_page': perPage,
        'sort': 'name',
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

  Future<CustomerOrderDetailModel> respondShoppingPriceQuote(
    int orderId, {
    required String action,
    int? pickupLocationId,
  }) async {
    final response = await _shoppingItemRequest(
      () async => _apiClient.post(
        '/v1/orders/$orderId/shopping/price-quote/respond',
        body: <String, dynamic>{
          'action': action.trim().toUpperCase(),
          'pickup_location_id': ?((pickupLocationId ?? 0) > 0
              ? pickupLocationId
              : null),
        },
        headers: await AuthService.authorizedHeaders(),
      ),
    );

    return CustomerOrderDetailModel.fromJson(response);
  }

  Future<CustomerOrderDetailModel> respondDeliveryFeeOverride(
    int orderId, {
    required String action,
    double? counterAmount,
  }) async {
    final response = await _shoppingItemRequest(
      () async => _apiClient.post(
        '/v1/orders/$orderId/delivery-fee-override/respond',
        body: <String, dynamic>{
          'action': action.trim().toUpperCase(),
          'counter_amount': ?counterAmount,
        },
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

  CustomerOrderDetailModel _extractDetail(
    Map<String, dynamic> response, {
    required String fallback,
  }) {
    final success = response['success'] == true;
    if (!success) {
      throw ApiException(response['message']?.toString() ?? fallback);
    }

    final rawData = response['data'];
    if (rawData is! Map<String, dynamic>) {
      throw const ApiException('Format detail order tidak valid dari server.');
    }

    return CustomerOrderDetailModel.fromJson(rawData);
  }

  Uri _buildUri(String path) {
    final baseUri = Uri.parse(AppEnv.apiBaseUrl);
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final fullPath = baseUri.path.endsWith('/')
        ? '${baseUri.path}$normalizedPath'
        : '${baseUri.path}/$normalizedPath';

    return baseUri.replace(path: fullPath);
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
  final double? latitude;
  final double? longitude;

  const ShoppingMerchantOption({
    required this.id,
    required this.name,
    required this.slug,
    required this.merchantType,
    required this.address,
    this.latitude,
    this.longitude,
  });

  factory ShoppingMerchantOption.fromJson(Map<String, dynamic> json) {
    return ShoppingMerchantOption(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? '-').toString(),
      slug: json['slug']?.toString(),
      merchantType: json['merchant_type']?.toString(),
      address: json['address']?.toString(),
      latitude: _toNullableDouble(json['latitude']),
      longitude: _toNullableDouble(json['longitude']),
    );
  }
}

class ShoppingMerchantPlacePayload {
  final String? placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final List<String> types;

  const ShoppingMerchantPlacePayload({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.types = const <String>[],
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if ((placeId ?? '').trim().isNotEmpty) 'place_id': placeId!.trim(),
      'name': name.trim(),
      'address': address.trim(),
      'latitude': latitude,
      'longitude': longitude,
      if (types.isNotEmpty) 'types': types,
    };
  }
}

class ShoppingMerchantPickerResult {
  const ShoppingMerchantPickerResult({required this.place, this.merchantId});

  final ShoppingMerchantPlacePayload place;
  final int? merchantId;

  bool get isOfficial => merchantId != null && merchantId! > 0;
}

class ShoppingItemDraftPayload {
  final int? merchantId;
  final ShoppingMerchantPlacePayload? merchantPlace;
  final int? menuId;
  final String itemSource;
  final String name;
  final int quantity;
  final String? notes;
  final double? unitPrice;

  const ShoppingItemDraftPayload({
    required this.merchantId,
    this.merchantPlace,
    this.menuId,
    this.itemSource = 'MANUAL',
    required this.name,
    required this.quantity,
    required this.notes,
    this.unitPrice,
  });

  Map<String, dynamic> toJson() {
    final normalizedSource = itemSource.trim().toUpperCase() == 'MENU_DB'
        ? 'MENU_DB'
        : 'MANUAL';

    return <String, dynamic>{
      if (merchantId != null && merchantId! > 0) 'merchant_id': merchantId,
      if ((merchantId == null || merchantId! <= 0) && merchantPlace != null)
        'merchant_place': merchantPlace!.toJson(),
      'item_source': normalizedSource,
      if (normalizedSource == 'MENU_DB' && menuId != null && menuId! > 0)
        'menu_id': menuId,
      if (name.trim().isNotEmpty) 'menu_name': name.trim(),
      'quantity': quantity,
      if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
    };
  }
}

class ShoppingMenuOption {
  final int id;
  final String name;
  final double price;
  final String imageUrl;

  const ShoppingMenuOption({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl = '',
  });

  factory ShoppingMenuOption.fromJson(Map<String, dynamic> json) {
    return ShoppingMenuOption(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? '-').toString(),
      price: _toDouble(json['price']),
      imageUrl: AppEnv.resolveBackendAssetUrl(json['image']?.toString()),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

double? _toNullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  final parsed = double.tryParse(value.toString());
  return parsed;
}
