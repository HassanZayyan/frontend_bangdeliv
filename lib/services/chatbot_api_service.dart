import '../models/chatbot_model.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_service.dart';

class ChatbotApiService {
  ChatbotApiService(this._apiClient);

  final ApiClient _apiClient;
  static const Duration _chatbotTimeout = Duration(seconds: 20);

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
}
