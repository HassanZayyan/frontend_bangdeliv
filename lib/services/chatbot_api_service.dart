import '../models/chatbot_model.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_service.dart';

class ChatbotApiService {
  ChatbotApiService(this._apiClient);

  final ApiClient _apiClient;
  static const Duration _chatbotTimeout = Duration(seconds: 20);

  static const Duration _historyTimeout = Duration(seconds: 15);

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

  Future<List<ChatbotSessionSummary>> fetchSessions({
    String? serviceType,
    int limit = 20,
  }) async {
    final query = <String, dynamic>{'limit': limit};

    if (serviceType != null && serviceType.trim().isNotEmpty) {
      query['service_type'] = serviceType.trim();
    }

    Map<String, dynamic> response;
    try {
      response = await _apiClient.get(
        '/chatbot/sessions',
        queryParams: query,
        headers: await AuthService.authorizedHeaders(),
        timeout: _historyTimeout,
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }

    final rawData = (response['data'] is List<dynamic>)
        ? response['data'] as List<dynamic>
        : const <dynamic>[];

    return rawData
        .whereType<Map<String, dynamic>>()
        .map(ChatbotSessionSummary.fromJson)
        .where((item) => item.sessionId.isNotEmpty)
        .toList(growable: false);
  }

  Future<ChatbotHistoryPage> fetchSessionHistory(
    String sessionId, {
    int limit = 50,
    int? beforeId,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      throw const ApiException('Session chat tidak valid.');
    }

    final query = <String, dynamic>{
      'limit': limit,
      ...?_beforeIdAsMap(beforeId),
    };

    Map<String, dynamic> response;
    try {
      response = await _apiClient.get(
        '/chatbot/sessions/$normalizedSessionId/history',
        queryParams: query,
        headers: await AuthService.authorizedHeaders(),
        timeout: _historyTimeout,
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }

    return ChatbotHistoryPage.fromApiJson(response);
  }

  Map<String, dynamic>? _beforeIdAsMap(int? beforeId) {
    if (beforeId == null) {
      return null;
    }

    return <String, dynamic>{'before_id': beforeId};
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
        timeout: _historyTimeout,
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

  Future<void> clearSession(String sessionId) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return;
    }

    try {
      await _apiClient.delete(
        '/chatbot/sessions/$normalizedSessionId',
        headers: await AuthService.authorizedHeaders(),
        timeout: _historyTimeout,
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }
  }
}
