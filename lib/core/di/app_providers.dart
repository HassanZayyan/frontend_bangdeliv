import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/address_repository.dart';
import '../../data/repositories/chatbot_repository.dart';
import '../../data/repositories/customer_order_repository.dart';
import '../../data/repositories/driver_order_repository.dart';
import '../../data/repositories/realtime_order_client.dart';
import '../../models/home_data_model.dart';
import '../../services/api_client.dart';
import '../../services/chatbot_api_service.dart';
import '../../services/customer_order_api_service.dart';
import '../../services/device_token_api_service.dart';
import '../../services/driver_order_service.dart';
import '../../services/home_api_service.dart';
import '../../services/order_chat_api_service.dart';
import '../../services/pusher_service.dart';
import '../../services/qris_download_service.dart';
import '../../services/ride_order_api_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.close);
  return client;
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

final customerOrderRepositoryProvider = Provider<CustomerOrderRepository>((
  ref,
) {
  return ApiCustomerOrderRepository(ref.watch(customerOrderApiServiceProvider));
});

final chatbotRepositoryProvider = Provider<ChatbotRepository>((ref) {
  return ApiChatbotRepository(ref.watch(chatbotApiServiceProvider));
});

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return const AuthAddressRepository();
});

final driverOrderServiceProvider = Provider<DriverOrderService>((ref) {
  final service = DriverOrderService();
  ref.onDispose(service.close);
  return service;
});

final driverOrderRepositoryProvider = Provider<DriverOrderRepository>((ref) {
  return ApiDriverOrderRepository(ref.watch(driverOrderServiceProvider));
});

final orderChatApiServiceProvider = Provider<OrderChatApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return OrderChatApiService(apiClient);
});

final deviceTokenApiServiceProvider = Provider<DeviceTokenApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DeviceTokenApiService(apiClient);
});

final qrisDownloadServiceProvider = Provider<QrisDownloadService>((ref) {
  final service = QrisDownloadService();
  ref.onDispose(service.close);
  return service;
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
