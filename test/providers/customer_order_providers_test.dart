import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/models/customer_order_model.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';
import 'package:frontend_bangdeliv/core/di/app_providers.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/orders/application/customer_order_providers.dart';
import 'package:frontend_bangdeliv/services/api_client.dart';
import 'package:frontend_bangdeliv/services/customer_order_api_service.dart';

void main() {
  test('customerOrdersProvider returns empty list for guest session', () async {
    final fakeAuth = _FakeAuthSessionNotifier(const AuthSessionState.guest());
    final fakeService = _FakeCustomerOrderApiService(
      queuedResponses: <List<CustomerOrderSummaryModel>>[
        <CustomerOrderSummaryModel>[_order(id: 9001, number: 'ORD-9001')],
      ],
    );

    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(() => fakeAuth),
        customerOrderApiServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(customerOrdersProvider.future);

    expect(result, isEmpty);
    expect(fakeService.fetchOrdersCalls, 0);
  });

  test(
    'customerOrdersProvider refetches when authenticated user id changes',
    () async {
      final fakeAuth = _FakeAuthSessionNotifier(_customerSession(9));
      final fakeService = _FakeCustomerOrderApiService(
        queuedResponses: <List<CustomerOrderSummaryModel>>[
          <CustomerOrderSummaryModel>[_order(id: 9010, number: 'ORD-U9')],
          <CustomerOrderSummaryModel>[_order(id: 10010, number: 'ORD-U10')],
        ],
      );

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          customerOrderApiServiceProvider.overrideWithValue(fakeService),
        ],
      );
      addTearDown(container.dispose);

      final firstResult = await container.read(customerOrdersProvider.future);
      expect(firstResult.map((item) => item.orderNumber), ['ORD-U9']);
      expect(fakeService.fetchOrdersCalls, 1);

      fakeAuth.setSession(_customerSession(10));

      final secondResult = await container.read(customerOrdersProvider.future);
      expect(secondResult.map((item) => item.orderNumber), ['ORD-U10']);
      expect(fakeService.fetchOrdersCalls, 2);
    },
  );

  test(
    'customerOrdersProvider clears data when switching to driver role',
    () async {
      final fakeAuth = _FakeAuthSessionNotifier(_customerSession(9));
      final fakeService = _FakeCustomerOrderApiService(
        queuedResponses: <List<CustomerOrderSummaryModel>>[
          <CustomerOrderSummaryModel>[_order(id: 7001, number: 'ORD-CUSTOMER')],
        ],
      );

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          customerOrderApiServiceProvider.overrideWithValue(fakeService),
        ],
      );
      addTearDown(container.dispose);

      final firstResult = await container.read(customerOrdersProvider.future);
      expect(firstResult.length, 1);
      expect(fakeService.fetchOrdersCalls, 1);

      fakeAuth.setSession(_driverSession(88));

      final secondResult = await container.read(customerOrdersProvider.future);
      expect(secondResult, isEmpty);
      expect(fakeService.fetchOrdersCalls, 1);
    },
  );
}

class _FakeAuthSessionNotifier extends AuthSessionNotifier {
  _FakeAuthSessionNotifier(this._initialState);

  final AuthSessionState _initialState;

  @override
  AuthSessionState build() {
    return _initialState;
  }

  void setSession(AuthSessionState next) {
    state = next;
  }
}

class _FakeCustomerOrderApiService extends CustomerOrderApiService {
  _FakeCustomerOrderApiService({required this.queuedResponses})
    : super(ApiClient());

  final List<List<CustomerOrderSummaryModel>> queuedResponses;
  int fetchOrdersCalls = 0;

  @override
  Future<List<CustomerOrderSummaryModel>> fetchOrders({
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    fetchOrdersCalls += 1;

    if (queuedResponses.isEmpty) {
      return const <CustomerOrderSummaryModel>[];
    }

    final index = fetchOrdersCalls - 1;
    if (index >= queuedResponses.length) {
      return queuedResponses.last;
    }

    return queuedResponses[index];
  }
}

AuthSessionState _customerSession(int userId) {
  return AuthSessionState.fromProfile(
    UserProfileModel(
      id: userId,
      name: 'Customer $userId',
      phone: '08123$userId',
      email: 'customer$userId@example.com',
      avatar: null,
      avatarUrl: null,
      role: 'customer',
      driverProfile: null,
      stats: const UserStatsModel(totalOrders: 0, totalPaid: 0),
      addresses: const <SavedAddressModel>[],
    ),
  );
}

AuthSessionState _driverSession(int userId) {
  return AuthSessionState.fromProfile(
    UserProfileModel(
      id: userId,
      name: 'Driver $userId',
      phone: '08234$userId',
      email: 'driver$userId@example.com',
      avatar: null,
      avatarUrl: null,
      role: 'driver',
      driverProfile: _activeDriverProfile(),
      stats: const UserStatsModel(totalOrders: 0, totalPaid: 0),
      addresses: const <SavedAddressModel>[],
    ),
  );
}

CustomerOrderSummaryModel _order({required int id, required String number}) {
  return CustomerOrderSummaryModel(
    id: id,
    orderNumber: number,
    serviceTypeCode: 'RIDE',
    serviceTypeLabel: 'Antar Jemput',
    restaurantName: 'Bangdeliv',
    itemsSummary: '1x Ride',
    totalAmount: 12000,
    statusCode: 'PENDING',
    statusLabel: 'Menunggu',
    isTerminalStatus: false,
    createdAt: DateTime(2026, 4, 21),
    estimatedDelivery: null,
    deliveryAddress: 'Alamat Tujuan',
    paymentStatus: 'unpaid',
    paymentMethod: 'COD',
  );
}

DriverProfileModel _activeDriverProfile() {
  return const DriverProfileModel(
    registrationStatus: 'active',
    status: 'active',
    vehicleType: 'Motor Matic',
    vehicleBrand: 'Honda',
    vehicleModel: 'Beat',
    vehiclePlate: 'BG 1234 DL',
    totalDeliveries: 12,
  );
}
