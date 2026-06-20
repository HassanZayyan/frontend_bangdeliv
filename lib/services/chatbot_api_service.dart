import '../models/chatbot_model.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_service.dart';
import 'customer_order_api_service.dart';

class ChatbotLocationPatchRequest {
  const ChatbotLocationPatchRequest({
    required this.target,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final String target;
  final double latitude;
  final double longitude;
  final String? address;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'target': target,
      'latitude': latitude,
      'longitude': longitude,
      ...?((address ?? '').trim().isEmpty
          ? null
          : <String, dynamic>{'address': address!.trim()}),
    };
  }
}

class ChatbotApiService {
  ChatbotApiService(this._apiClient);

  final ApiClient _apiClient;
  static const Duration _chatbotTimeout = Duration(seconds: 20);

  static const Duration _actionTimeout = Duration(seconds: 15);

  Future<ChatbotResult> sendMessage(
    String message, {
    required String serviceType,
    String? sessionId,
  }) async {
    final requestBody = <String, dynamic>{
      'message': message,
      'service_type': serviceType,
    };

    if (sessionId != null && sessionId.trim().isNotEmpty) {
      requestBody['session_id'] = sessionId.trim();
    }

    Map<String, dynamic> response;
    try {
      response = await _apiClient.post(
        '/chatbot/process',
        body: requestBody,
        headers: await AuthService.authorizedHeaders(),
        timeout: _chatbotTimeout,
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }

    final status = response['status']?.toString().toLowerCase();
    if (status == 'error') {
      throw ApiException(
        response['message']?.toString() ?? 'Layanan chatbot sedang bermasalah.',
      );
    }

    return ChatbotResult.fromApiJson(response);
  }

  Future<ChatbotResult> patchSessionLocation(
    String sessionId, {
    required String serviceType,
    required String target,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      throw const ApiException('Session chat tidak valid.');
    }

    final requestBody = <String, dynamic>{
      'service_type': serviceType,
      'target': target,
      'latitude': latitude,
      'longitude': longitude,
      ...?(address == null || address.trim().isEmpty
          ? null
          : <String, dynamic>{'address': address.trim()}),
    };

    Map<String, dynamic> response;
    try {
      response = await _apiClient.post(
        '/chatbot/sessions/$normalizedSessionId/location',
        body: requestBody,
        headers: await AuthService.authorizedHeaders(),
        timeout: _actionTimeout,
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }

    final status = response['status']?.toString().toLowerCase();
    if (status == 'error') {
      throw ApiException(
        response['message']?.toString() ??
            'Gagal memperbarui titik lokasi chatbot.',
      );
    }

    return ChatbotResult.fromApiJson(response);
  }

  Future<ChatbotResult> patchSessionLocations(
    String sessionId, {
    required String serviceType,
    required List<ChatbotLocationPatchRequest> locations,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      throw const ApiException('Session chat tidak valid.');
    }
    if (locations.isEmpty) {
      throw const ApiException('Titik rute belum dipilih.');
    }

    final requestBody = <String, dynamic>{
      'service_type': serviceType,
      'locations': locations
          .map((location) => location.toJson())
          .toList(growable: false),
    };

    Map<String, dynamic> response;
    try {
      response = await _apiClient.post(
        '/chatbot/sessions/$normalizedSessionId/locations',
        body: requestBody,
        headers: await AuthService.authorizedHeaders(),
        timeout: _actionTimeout,
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }

    final status = response['status']?.toString().toLowerCase();
    if (status == 'error') {
      throw ApiException(
        response['message']?.toString() ??
            'Gagal memperbarui titik rute chatbot.',
      );
    }

    return ChatbotResult.fromApiJson(response);
  }

  Future<ChatbotResult> patchSessionMerchant(
    String sessionId, {
    required String serviceType,
    int? merchantId,
    ShoppingMerchantPlacePayload? merchantPlace,
    String mode = 'select',
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      throw const ApiException('Session chat tidak valid.');
    }
    if ((merchantId == null || merchantId <= 0) && merchantPlace == null) {
      throw const ApiException('Merchant belum dipilih.');
    }

    final requestBody = <String, dynamic>{
      'service_type': serviceType,
      'mode': mode.trim().toLowerCase() == 'add' ? 'add' : 'select',
      if (merchantId != null && merchantId > 0) 'merchant_id': merchantId,
      if (merchantPlace != null) 'merchant_place': merchantPlace.toJson(),
    };

    Map<String, dynamic> response;
    try {
      response = await _apiClient.post(
        '/chatbot/sessions/$normalizedSessionId/merchant',
        body: requestBody,
        headers: await AuthService.authorizedHeaders(),
        timeout: _actionTimeout,
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }

    final status = response['status']?.toString().toLowerCase();
    if (status == 'error') {
      throw ApiException(
        response['message']?.toString() ??
            'Gagal memperbarui merchant chatbot.',
      );
    }

    return ChatbotResult.fromApiJson(response);
  }

  Future<void> clearSession(String sessionId) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return;
    }

    try {
      await _apiClient.delete(
        '/chatbot/sessions/$normalizedSessionId',
        headers: await AuthService.authorizedHeaders(),
        timeout: _actionTimeout,
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }
  }
}
