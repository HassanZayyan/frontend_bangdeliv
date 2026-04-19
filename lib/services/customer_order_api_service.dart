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
}
