import '../../models/chatbot_model.dart';
import '../../services/chatbot_api_service.dart';
import '../../services/customer_order_api_service.dart';

abstract class ChatbotRepository {
  Future<ChatbotResult> sendMessage(
    String message, {
    required String serviceType,
    String? sessionId,
  });

  Future<List<ChatbotSessionSummary>> fetchSessions({
    String? serviceType,
    int limit = 20,
  });

  Future<ChatbotHistoryPage> fetchSessionHistory(
    String sessionId, {
    int limit = 50,
    int? beforeId,
  });

  Future<ChatbotResult> patchSessionLocation(
    String sessionId, {
    required String serviceType,
    required String target,
    required double latitude,
    required double longitude,
    String? address,
  });

  Future<ChatbotResult> patchSessionLocations(
    String sessionId, {
    required String serviceType,
    required List<ChatbotLocationPatchRequest> locations,
  });

  Future<ChatbotResult> patchSessionMerchant(
    String sessionId, {
    required String serviceType,
    int? merchantId,
    ShoppingMerchantPlacePayload? merchantPlace,
  });

  Future<void> clearSession(String sessionId);
}

class ApiChatbotRepository implements ChatbotRepository {
  const ApiChatbotRepository(this._service);

  final ChatbotApiService _service;

  @override
  Future<ChatbotResult> sendMessage(
    String message, {
    required String serviceType,
    String? sessionId,
  }) {
    return _service.sendMessage(
      message,
      serviceType: serviceType,
      sessionId: sessionId,
    );
  }

  @override
  Future<List<ChatbotSessionSummary>> fetchSessions({
    String? serviceType,
    int limit = 20,
  }) {
    return _service.fetchSessions(serviceType: serviceType, limit: limit);
  }

  @override
  Future<ChatbotHistoryPage> fetchSessionHistory(
    String sessionId, {
    int limit = 50,
    int? beforeId,
  }) {
    return _service.fetchSessionHistory(
      sessionId,
      limit: limit,
      beforeId: beforeId,
    );
  }

  @override
  Future<ChatbotResult> patchSessionLocation(
    String sessionId, {
    required String serviceType,
    required String target,
    required double latitude,
    required double longitude,
    String? address,
  }) {
    return _service.patchSessionLocation(
      sessionId,
      serviceType: serviceType,
      target: target,
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
  }

  @override
  Future<ChatbotResult> patchSessionLocations(
    String sessionId, {
    required String serviceType,
    required List<ChatbotLocationPatchRequest> locations,
  }) {
    return _service.patchSessionLocations(
      sessionId,
      serviceType: serviceType,
      locations: locations,
    );
  }

  @override
  Future<ChatbotResult> patchSessionMerchant(
    String sessionId, {
    required String serviceType,
    int? merchantId,
    ShoppingMerchantPlacePayload? merchantPlace,
  }) {
    return _service.patchSessionMerchant(
      sessionId,
      serviceType: serviceType,
      merchantId: merchantId,
      merchantPlace: merchantPlace,
    );
  }

  @override
  Future<void> clearSession(String sessionId) {
    return _service.clearSession(sessionId);
  }
}
