import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/realtime/application/order_price_heads_up_notification_provider.dart';
import 'package:frontend_bangdeliv/features/realtime/application/order_realtime_hub_provider.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';

import '../../fakes/fake_order_realtime_client.dart';

void main() {
  test(
    'customer content pricing event shows local price notification',
    () async {
      final fakeRealtime = FakeOrderRealtimeClient();
      final hub = OrderRealtimeHub(fakeRealtime);
      final fakeAuth = _FakeAuthSessionNotifier(_customerSession(7));
      final notifications = <Map<String, Object?>>[];
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderRealtimeHubProvider.overrideWithValue(hub),
          orderPriceChangedNotificationProvider.overrideWithValue(({
            required int orderId,
            required String recipientRole,
            required String changeType,
            int priceEventId = 0,
            bool requiresResponse = false,
            num? amount,
            num? oldTotalPrice,
            num? newTotalPrice,
            String? focus,
            int? pickupLocationId,
          }) async {
            notifications.add(<String, Object?>{
              'orderId': orderId,
              'recipientRole': recipientRole,
              'changeType': changeType,
              'priceEventId': priceEventId,
              'requiresResponse': requiresResponse,
              'amount': amount,
              'oldTotalPrice': oldTotalPrice,
              'newTotalPrice': newTotalPrice,
              'focus': focus,
              'pickupLocationId': pickupLocationId,
            });
          }),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(hub.dispose);

      final subscription = container.listen<void>(
        orderPriceHeadsUpNotificationProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await hub.retainOrder(42);
      await Future<void>.delayed(Duration.zero);

      fakeRealtime.emitOrderContentUpdated(42, const <String, dynamic>{
        'change_type': 'DRIVER_FEE_QUOTED',
        'pricing': <String, dynamic>{
          'price_event_id': 91,
          'delivery_fee': 22000,
          'old_total_price': 15000,
          'new_total_price': 22000,
        },
      });
      await Future<void>.delayed(Duration.zero);

      expect(notifications, hasLength(1));
      expect(notifications.single['orderId'], 42);
      expect(notifications.single['recipientRole'], 'customer');
      expect(notifications.single['changeType'], 'DRIVER_FEE_QUOTED');
      expect(notifications.single['priceEventId'], 91);
      expect(notifications.single['requiresResponse'], isTrue);
      expect(notifications.single['amount'], 22000);
      expect(notifications.single['oldTotalPrice'], 15000);
      expect(notifications.single['newTotalPrice'], 22000);
      expect(notifications.single['focus'], 'delivery_fee');
    },
  );

  test(
    'driver content pricing event targets driver active order route',
    () async {
      final fakeRealtime = FakeOrderRealtimeClient();
      final hub = OrderRealtimeHub(fakeRealtime);
      final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
      final notifications = <Map<String, Object?>>[];
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderRealtimeHubProvider.overrideWithValue(hub),
          orderPriceChangedNotificationProvider.overrideWithValue(({
            required int orderId,
            required String recipientRole,
            required String changeType,
            int priceEventId = 0,
            bool requiresResponse = false,
            num? amount,
            num? oldTotalPrice,
            num? newTotalPrice,
            String? focus,
            int? pickupLocationId,
          }) async {
            notifications.add(<String, Object?>{
              'orderId': orderId,
              'recipientRole': recipientRole,
              'changeType': changeType,
              'requiresResponse': requiresResponse,
              'amount': amount,
            });
          }),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(hub.dispose);

      final subscription = container.listen<void>(
        orderPriceHeadsUpNotificationProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await hub.retainOrder(42);
      await Future<void>.delayed(Duration.zero);

      fakeRealtime.emitOrderContentUpdated(42, const <String, dynamic>{
        'change_type': 'CUSTOMER_FEE_COUNTERED',
        'pricing': <String, dynamic>{'counter_amount': 19000},
      });
      await Future<void>.delayed(Duration.zero);

      expect(notifications, hasLength(1));
      expect(notifications.single['recipientRole'], 'driver');
      expect(notifications.single['changeType'], 'CUSTOMER_FEE_COUNTERED');
      expect(notifications.single['requiresResponse'], isTrue);
      expect(notifications.single['amount'], 19000);
    },
  );

  test('non pricing content event does not show local notification', () async {
    final fakeRealtime = FakeOrderRealtimeClient();
    final hub = OrderRealtimeHub(fakeRealtime);
    final fakeAuth = _FakeAuthSessionNotifier(_customerSession(7));
    var notificationCount = 0;
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(() => fakeAuth),
        orderRealtimeHubProvider.overrideWithValue(hub),
        orderPriceChangedNotificationProvider.overrideWithValue(({
          required int orderId,
          required String recipientRole,
          required String changeType,
          int priceEventId = 0,
          bool requiresResponse = false,
          num? amount,
          num? oldTotalPrice,
          num? newTotalPrice,
          String? focus,
          int? pickupLocationId,
        }) async {
          notificationCount += 1;
        }),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(hub.dispose);

    final subscription = container.listen<void>(
      orderPriceHeadsUpNotificationProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await hub.retainOrder(42);
    await Future<void>.delayed(Duration.zero);

    fakeRealtime.emitOrderContentUpdated(42, const <String, dynamic>{
      'change_type': 'CUSTOMER_ADD_ITEM',
    });
    await Future<void>.delayed(Duration.zero);

    expect(notificationCount, 0);
  });

  test('cancelled with fee order does not show a price notification', () async {
    final fakeRealtime = FakeOrderRealtimeClient();
    final hub = OrderRealtimeHub(fakeRealtime);
    final fakeAuth = _FakeAuthSessionNotifier(_customerSession(7));
    var notificationCount = 0;
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(() => fakeAuth),
        orderRealtimeHubProvider.overrideWithValue(hub),
        orderPriceChangedNotificationProvider.overrideWithValue(({
          required int orderId,
          required String recipientRole,
          required String changeType,
          int priceEventId = 0,
          bool requiresResponse = false,
          num? amount,
          num? oldTotalPrice,
          num? newTotalPrice,
          String? focus,
          int? pickupLocationId,
        }) async {
          notificationCount += 1;
        }),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(hub.dispose);

    final subscription = container.listen<void>(
      orderPriceHeadsUpNotificationProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await hub.retainOrder(42);
    await Future<void>.delayed(Duration.zero);

    // DRIVER_CANCEL_WITH_FEE mengandung "FEE", sehingga dulu nominalnya
    // diambil dari delivery_fee yang sengaja dinolkan -> "Ongkir Rp 0".
    fakeRealtime.emitOrderContentUpdated(42, const <String, dynamic>{
      'change_type': 'DRIVER_CANCEL_WITH_FEE',
      'status_code': 'CANCELLED_WITH_FEE',
      'pricing': <String, dynamic>{
        'delivery_fee': 0,
        'service_fee': 15000,
        'new_total_price': 15000,
      },
    });
    await Future<void>.delayed(Duration.zero);

    expect(notificationCount, 0);
  });
}

class _FakeAuthSessionNotifier extends AuthSessionNotifier {
  _FakeAuthSessionNotifier(this._initialState);

  final AuthSessionState _initialState;

  @override
  AuthSessionState build() {
    return _initialState;
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
      driverProfile: const DriverProfileModel(
        registrationStatus: 'active',
        status: 'available',
        vehicleType: 'Motor Matic',
        vehicleBrand: 'Honda',
        vehicleModel: 'Beat',
        vehiclePlate: 'BG 1234 DL',
        totalDeliveries: 12,
      ),
      stats: const UserStatsModel(totalOrders: 0, totalPaid: 0),
      addresses: const <SavedAddressModel>[],
    ),
  );
}
