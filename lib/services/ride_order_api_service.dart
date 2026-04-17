import 'api_client.dart';
import 'api_exception.dart';
import 'auth_service.dart';

class RideOrderSubmissionResult {
  final int orderId;
  final String? orderNumber;

  const RideOrderSubmissionResult({
    required this.orderId,
    required this.orderNumber,
  });

  factory RideOrderSubmissionResult.fromApiJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    final orderId = int.tryParse(data['id']?.toString() ?? '') ?? 0;
    final orderNumber = data['order_number']?.toString();

    return RideOrderSubmissionResult(
      orderId: orderId,
      orderNumber: orderNumber,
    );
  }
}

class RideOrderApiService {
  RideOrderApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<RideOrderSubmissionResult> createRideOrder({
    required int addressId,
    required String destinationAddress,
    String? notes,
  }) async {
    Map<String, dynamic> response;
    try {
      response = await _apiClient.post(
        '/v1/orders/ride',
        body: <String, dynamic>{
          'address_id': addressId,
          'destination_address': destinationAddress,
          if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
        },
        headers: await AuthService.authorizedHeaders(),
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }

    final success = response['success'] == true;
    if (!success) {
      throw ApiException(
        response['message']?.toString() ?? 'Gagal membuat order Antar Jemput.',
      );
    }

    return RideOrderSubmissionResult.fromApiJson(response);
  }
}
