import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/app_env.dart';
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

  Future<OrderChatSendResult> sendAttachment({
    required int orderId,
    required XFile file,
    required String clientMessageId,
    String? body,
    String attachmentType = 'image',
  }) async {
    final uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/v1/orders/$orderId/chat/messages',
    );
    final request = http.MultipartRequest('POST', uri);

    try {
      request.headers.addAll(
        await AuthService.authorizedHeaders(includeJsonContentType: false),
      );
      request.fields.addAll(<String, String>{
        'body': (body ?? '').trim(),
        'client_message_id': clientMessageId,
        'attachment_type': attachmentType,
      });
      request.files.add(
        await http.MultipartFile.fromPath('attachment', file.path),
      );

      final streamed = await request.send().timeout(_chatTimeout);
      final response = await http.Response.fromStream(streamed);
      final decoded = response.body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('Format respons chat tidak valid.');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          AuthService.extractErrorMessage(
            response,
            fallback: 'Gagal mengirim foto chat.',
          ),
          statusCode: response.statusCode,
        );
      }

      final success = decoded['success'] == true;
      if (!success) {
        throw ApiException(
          decoded['message']?.toString() ?? 'Gagal mengirim foto chat.',
        );
      }

      return OrderChatSendResult.fromApiJson(decoded);
    } on TimeoutException {
      throw const ApiException('Upload foto chat timeout.', statusCode: 408);
    } on AuthException catch (error) {
      throw ApiException(error.message);
    } on FormatException {
      throw const ApiException('Format respons chat tidak valid.');
    }
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
