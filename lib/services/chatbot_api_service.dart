import '../models/chatbot_model.dart';
import 'api_client.dart';
import 'api_exception.dart';

class ChatbotApiService {
  ChatbotApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<ChatbotResult> sendMessage(String message) async {
    final response = await _apiClient.post(
      '/chatbot/process',
      body: <String, dynamic>{'message': message},
    );

    final status = response['status']?.toString().toLowerCase();
    if (status == 'error') {
      throw ApiException(
        response['message']?.toString() ?? 'Layanan chatbot sedang bermasalah.',
      );
    }

    return ChatbotResult.fromApiJson(response);
  }
}
