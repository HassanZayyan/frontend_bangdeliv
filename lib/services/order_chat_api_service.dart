import '../models/order_chat_model.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_service.dart';

class OrderChatApiService {
  OrderChatApiService(this._apiClient);

  final ApiClient _apiClient;

  static const Duration _chatTimeout = Duration(seconds: 10);

  Future<OrderChatMessagesPage> fetchMessages({
    required int orderId,
    int limit = 50,
    int? beforeId,
    int? afterId,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      if (beforeId != null && beforeId > 0) 'before_id': beforeId,
      if (afterId != null && afterId > 0) 'after_id': afterId,
    };

    Map<String, dynamic> response;
    try {
      response = await _apiClient.get(
        '/v1/orders/$orderId/chat/messages',
        queryParams: query,
        headers: await AuthService.authorizedHeaders(
          includeJsonContentType: false,
        ),
        timeout: _chatTimeout,
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }

    final success = response['success'] == true;
    if (!success) {
      throw ApiException(
        response['message']?.toString() ?? 'Gagal mengambil pesan chat.',
      );
    }

    return OrderChatMessagesPage.fromApiJson(response);
  }

  Future<OrderChatSendResult> sendMessage({
    required int orderId,
    required String body,
    required String clientMessageId,
  }) async {
    Map<String, dynamic> response;
    try {
      response = await _apiClient.post(
        '/v1/orders/$orderId/chat/messages',
        body: <String, dynamic>{
          'body': body.trim(),
          'client_message_id': clientMessageId,
        },
        headers: await AuthService.authorizedHeaders(),
        timeout: _chatTimeout,
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }

    final success = response['success'] == true;
    if (!success) {
      throw ApiException(
        response['message']?.toString() ?? 'Gagal mengirim pesan chat.',
      );
    }

    return OrderChatSendResult.fromApiJson(response);
  }

  Future<OrderChatUnreadSummary> fetchUnread({required int orderId}) async {
    Map<String, dynamic> response;
    try {
      response = await _apiClient.get(
        '/v1/orders/$orderId/chat/unread',
        headers: await AuthService.authorizedHeaders(
          includeJsonContentType: false,
        ),
        timeout: _chatTimeout,
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }

    final success = response['success'] == true;
    if (!success) {
      throw ApiException(
        response['message']?.toString() ??
            'Gagal mengambil jumlah pesan belum dibaca.',
      );
    }

    return OrderChatUnreadSummary.fromApiJson(response);
  }

  Future<OrderChatUnreadSummary> markRead({
    required int orderId,
    required int messageId,
  }) async {
    Map<String, dynamic> response;
    try {
      response = await _apiClient.post(
        '/v1/orders/$orderId/chat/read',
        body: <String, dynamic>{'message_id': messageId},
        headers: await AuthService.authorizedHeaders(),
        timeout: _chatTimeout,
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }

    final success = response['success'] == true;
    if (!success) {
      throw ApiException(
        response['message']?.toString() ??
            'Gagal menandai pesan chat sudah dibaca.',
      );
    }

    return OrderChatUnreadSummary.fromApiJson(response);
  }
}
