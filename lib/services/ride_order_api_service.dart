import 'api_client.dart';
import 'api_exception.dart';
import 'auth_service.dart';

class RideDestinationValidationResult {
  final String formattedAddress;
  final double latitude;
  final double longitude;

  const RideDestinationValidationResult({
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  factory RideDestinationValidationResult.fromApiJson(
    Map<String, dynamic> json,
  ) {
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    return RideDestinationValidationResult(
      formattedAddress: data['formatted_address']?.toString().trim() ?? '',
      latitude: double.tryParse(data['latitude']?.toString() ?? '') ?? 0,
      longitude: double.tryParse(data['longitude']?.toString() ?? '') ?? 0,
    );
  }
}

class RideOrderSubmissionResult {
  final int orderId;
  final String? orderNumber;
  final double? deliveryFee;

  const RideOrderSubmissionResult({
    required this.orderId,
    required this.orderNumber,
    this.deliveryFee,
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
      deliveryFee: _asDoubleOrNull(data['delivery_fee']),
    );
  }

  static double? _asDoubleOrNull(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return null;
    }

    return parsed;
  }
}

class RideOrderApiService {
  RideOrderApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<RideDestinationValidationResult> validateDestinationAddress({
    required String destinationAddress,
  }) async {
    Map<String, dynamic> response;
    try {
      response = await _apiClient.post(
        '/v1/orders/ride/validate-destination',
        body: <String, dynamic>{
          'destination_address': destinationAddress.trim(),
        },
        headers: await AuthService.authorizedHeaders(),
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }

    final success = response['success'] == true;
    if (!success) {
      throw ApiException(
        response['message']?.toString() ??
            'Gagal memvalidasi alamat tujuan Antar Jemput.',
      );
    }

    return RideDestinationValidationResult.fromApiJson(response);
  }

  Future<RideOrderSubmissionResult> createRideOrder({
    required int addressId,
    required String destinationAddress,
  }) async {
    Map<String, dynamic> response;
    try {
      response = await _apiClient.post(
        '/v1/orders/ride',
        body: <String, dynamic>{
          'address_id': addressId,
          'destination_address': destinationAddress,
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
