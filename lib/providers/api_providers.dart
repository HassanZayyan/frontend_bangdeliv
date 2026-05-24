import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/home_data_model.dart';
import '../services/api_client.dart';
import '../services/chatbot_api_service.dart';
import '../services/customer_order_api_service.dart';
import '../services/device_token_api_service.dart';
import '../services/home_api_service.dart';
import '../services/order_chat_api_service.dart';
import '../services/pusher_service.dart';
import '../services/ride_order_api_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final homeApiServiceProvider = Provider<HomeApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return HomeApiService(apiClient);
});

final chatbotApiServiceProvider = Provider<ChatbotApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ChatbotApiService(apiClient);
});

final rideOrderApiServiceProvider = Provider<RideOrderApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RideOrderApiService(apiClient);
});

final customerOrderApiServiceProvider = Provider<CustomerOrderApiService>((
  ref,
) {
  final apiClient = ref.watch(apiClientProvider);
  return CustomerOrderApiService(apiClient);
});

final orderChatApiServiceProvider = Provider<OrderChatApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return OrderChatApiService(apiClient);
});

final deviceTokenApiServiceProvider = Provider<DeviceTokenApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DeviceTokenApiService(apiClient);
});

final orderRealtimeClientProvider = Provider<OrderRealtimeClient>((ref) {
  return PusherService.instance;
});

class HomeSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }
}

final homeSearchQueryProvider =
    NotifierProvider<HomeSearchQueryNotifier, String>(
      HomeSearchQueryNotifier.new,
    );

final homeDataProvider = FutureProvider<HomeDataModel>((ref) async {
  final service = ref.watch(homeApiServiceProvider);
  final query = ref.watch(homeSearchQueryProvider);
  return service.fetchHomeData(search: query);
});
