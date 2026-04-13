import '../models/chatbot_model.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_service.dart';

class ChatbotApiService {
  ChatbotApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<ChatbotResult> sendMessage(
    String message, {
    required String serviceType,
  }) async {
    Map<String, dynamic> response;
    try {
      response = await _apiClient.post(
        '/chatbot/process',
        body: <String, dynamic>{
          'message': message,
          'service_type': serviceType,
        },
        headers: await AuthService.authorizedHeaders(),
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
