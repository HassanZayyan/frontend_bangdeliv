import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/models/order_chat_model.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';
import 'package:frontend_bangdeliv/providers/api_providers.dart';
import 'package:frontend_bangdeliv/providers/app_realtime_bootstrap_provider.dart';
import 'package:frontend_bangdeliv/providers/auth_session_provider.dart';
import 'package:frontend_bangdeliv/providers/driver_order_providers.dart';
import 'package:frontend_bangdeliv/providers/driver_realtime_bootstrap_provider.dart';
import 'package:frontend_bangdeliv/providers/order_chat_unread_provider.dart';
import 'package:frontend_bangdeliv/services/api_client.dart';
import 'package:frontend_bangdeliv/services/driver_order_service.dart';
import 'package:frontend_bangdeliv/services/order_chat_api_service.dart';
import '../fakes/fake_order_realtime_client.dart';

void main() {
  DriverOrdersPayload seededPayload() {
    return const DriverOrdersPayload(
      incoming: [
        DriverOrderModel(
          id: 'ORD-1',
          customerName: 'Rina',
          pickupAddress: 'A',
          dropoffAddress: 'B',
          etaMinutes: 10,
          fee: 10000,
          itemCount: 1,
        ),
      ],
      running: [],
    );
  }

  test('acceptOrder success moves incoming to running', () async {
    final fakeService = _FakeDriverOrderService(payload: seededPayload());
    final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
    final fakeRealtime = FakeOrderRealtimeClient();
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(() => fakeAuth),
        driverOrderServiceProvider.overrideWithValue(fakeService),
        orderRealtimeClientProvider.overrideWithValue(fakeRealtime),
      ],
    );
    addTearDown(container.dispose);

    await container.read(driverOrdersProvider.future);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final error = await container
        .read(driverOrdersProvider.notifier)
        .acceptOrder('ORD-1');

    final state = container.read(driverOrdersProvider).asData!.value;

    expect(error, isNull);
    expect(state.incoming.length, 0);
    expect(state.running.length, 1);
    expect(state.running.first.id, 'ORD-1');
    expect(fakeService.acceptedOrderIds, ['ORD-1']);
  });

  test('acceptOrder failure rolls back optimistic change', () async {
    final fakeService = _FakeDriverOrderService(
      payload: seededPayload(),
      failAccept: true,
    );
    final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
    final fakeRealtime = FakeOrderRealtimeClient();
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(() => fakeAuth),
        driverOrderServiceProvider.overrideWithValue(fakeService),
        orderRealtimeClientProvider.overrideWithValue(fakeRealtime),
      ],
    );
    addTearDown(container.dispose);

    await container.read(driverOrdersProvider.future);

    final error = await container
        .read(driverOrdersProvider.notifier)
        .acceptOrder('ORD-1');

    final state = container.read(driverOrdersProvider).asData!.value;

    expect(error, isNotNull);
    expect(state.incoming.length, 1);
    expect(state.running, isEmpty);
  });

  test('rejectOrder failure rolls back optimistic removal', () async {
    final fakeService = _FakeDriverOrderService(
      payload: seededPayload(),
      failReject: true,
    );
    final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
    final fakeRealtime = FakeOrderRealtimeClient();
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(() => fakeAuth),
        driverOrderServiceProvider.overrideWithValue(fakeService),
        orderRealtimeClientProvider.overrideWithValue(fakeRealtime),
      ],
    );
    addTearDown(container.dispose);

    await container.read(driverOrdersProvider.future);

    final error = await container
        .read(driverOrdersProvider.notifier)
        .rejectOrder('ORD-1');

    final state = container.read(driverOrdersProvider).asData!.value;

    expect(error, isNotNull);
    expect(state.incoming.length, 1);
    expect(state.incoming.first.id, 'ORD-1');
    expect(state.running, isEmpty);
  });

  test('driverOrdersProvider applies realtime incoming order without refresh', () async {
    final fakeService = _FakeDriverOrderService(
      payload: const DriverOrdersPayload(incoming: [], running: []),
    );
    final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
    final fakeRealtime = FakeOrderRealtimeClient();
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(() => fakeAuth),
        driverOrderServiceProvider.overrideWithValue(fakeService),
        orderRealtimeClientProvider.overrideWithValue(fakeRealtime),
      ],
    );
    addTearDown(container.dispose);

    final initial = await container.read(driverOrdersProvider.future);
    expect(initial.incoming, isEmpty);
    expect(fakeRealtime.driverOrderSubscriptions, contains(77));

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final realtimeOrder = const DriverOrderModel(
      id: 'RT-1',
      customerName: 'Customer Realtime',
      pickupAddress: 'Pickup',
      dropoffAddress: 'Dropoff',
      etaMinutes: 8,
      fee: 9000,
      itemCount: 1,
    );
    fakeRealtime.emitDriverOrderAvailable(77, realtimeOrder);

    final state = container.read(driverOrdersProvider).asData!.value;
    expect(state.incoming.map((order) => order.id), ['RT-1']);
  });

  test(
    'appRealtimeBootstrapProvider keeps driver realtime alive outside driver shell',
    () async {
      final fakeService = _FakeDriverOrderService(
        payload: DriverOrdersPayload(
          incoming: const <DriverOrderModel>[],
          running: <DriverOrderModel>[_runningOrder('99')],
        ),
      );
      final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
      final fakeRealtime = FakeOrderRealtimeClient();
      final fakeChatService = _FakeOrderChatApiService();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          driverOrderServiceProvider.overrideWithValue(fakeService),
          orderChatApiServiceProvider.overrideWithValue(fakeChatService),
          orderRealtimeClientProvider.overrideWithValue(fakeRealtime),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen<AppRealtimeBootstrapState>(
        appRealtimeBootstrapProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container.read(driverOrdersProvider.future);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final bootstrap = container.read(appRealtimeBootstrapProvider);
      expect(bootstrap.driverBootstrapActive, isTrue);
      expect(bootstrap.retainedDriverUnreadOrderIds, contains(99));
      expect(fakeRealtime.driverOrderSubscriptions, contains(77));
      expect(fakeRealtime.orderTrackingSubscriptions, contains(99));
    },
  );

  test(
    'driverOrdersProvider retries realtime subscription after initial failure',
    () async {
      final fakeService = _FakeDriverOrderService(
        payload: const DriverOrdersPayload(incoming: [], running: []),
      );
      final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
      final fakeRealtime = FakeOrderRealtimeClient()
        ..failDriverOrderSubscribeAttempts = 1;
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          driverOrderServiceProvider.overrideWithValue(fakeService),
          orderRealtimeClientProvider.overrideWithValue(fakeRealtime),
        ],
      );
      addTearDown(container.dispose);

      await container.read(driverOrdersProvider.future);
      expect(fakeRealtime.driverOrderSubscribeCalls, 1);

      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await Future<void>.delayed(Duration.zero);

      expect(fakeRealtime.driverOrderSubscribeCalls, greaterThanOrEqualTo(2));
      expect(fakeRealtime.driverOrderSubscriptions, contains(77));

      fakeRealtime.emitDriverOrderAvailable(
        77,
        const DriverOrderModel(
          id: 'RT-RETRY-1',
          customerName: 'Customer Realtime',
          pickupAddress: 'Pickup',
          dropoffAddress: 'Dropoff',
          etaMinutes: 8,
          fee: 9000,
          itemCount: 1,
        ),
      );

      final state = container.read(driverOrdersProvider).asData!.value;
      expect(state.incoming.map((order) => order.id), ['RT-RETRY-1']);
    },
  );

  test(
    'driverRealtimeBootstrapProvider retains driver orders and running chat unread',
    () async {
      final fakeService = _FakeDriverOrderService(
        payload: DriverOrdersPayload(
          incoming: const <DriverOrderModel>[],
          running: <DriverOrderModel>[_runningOrder('99')],
        ),
      );
      final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
      final fakeRealtime = FakeOrderRealtimeClient();
      final fakeChatService = _FakeOrderChatApiService();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          driverOrderServiceProvider.overrideWithValue(fakeService),
          orderChatApiServiceProvider.overrideWithValue(fakeChatService),
          orderRealtimeClientProvider.overrideWithValue(fakeRealtime),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen<DriverRealtimeBootstrapState>(
        driverRealtimeBootstrapProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container.read(driverOrdersProvider.future);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final bootstrap = container.read(driverRealtimeBootstrapProvider);
      expect(bootstrap.active, isTrue);
      expect(bootstrap.retainedUnreadOrderIds, contains(99));
      expect(fakeRealtime.driverOrderSubscriptions, contains(77));
      expect(fakeRealtime.orderTrackingSubscriptions, contains(99));
    },
  );

  test(
    'driver realtime bootstrap increments unread for customer chat without opening chat screen',
    () async {
      final fakeService = _FakeDriverOrderService(
        payload: DriverOrdersPayload(
          incoming: const <DriverOrderModel>[],
          running: <DriverOrderModel>[_runningOrder('99')],
        ),
      );
      final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
      final fakeRealtime = FakeOrderRealtimeClient();
      final fakeChatService = _FakeOrderChatApiService();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          driverOrderServiceProvider.overrideWithValue(fakeService),
          orderChatApiServiceProvider.overrideWithValue(fakeChatService),
          orderRealtimeClientProvider.overrideWithValue(fakeRealtime),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen<DriverRealtimeBootstrapState>(
        driverRealtimeBootstrapProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container.read(driverOrdersProvider.future);
      final initialUnread = await container.read(
        orderChatUnreadCountProvider(99).future,
      );
      expect(initialUnread, 0);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      fakeRealtime.emitOrderChatMessage(
        99,
        _chatMessage(id: 20, orderId: 99, senderUserId: 77),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(orderChatUnreadCountProvider(99)).asData!.value, 0);

      fakeRealtime.emitOrderChatMessage(
        99,
        _chatMessage(id: 21, orderId: 99, senderUserId: 7),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(orderChatUnreadCountProvider(99)).asData!.value, 1);

      await container
          .read(orderChatUnreadCountProvider(99).notifier)
          .markReadThrough(21);

      expect(fakeChatService.markedReadMessageId, 21);
      expect(container.read(orderChatUnreadCountProvider(99)).asData!.value, 0);
    },
  );
}

class _FakeDriverOrderService extends DriverOrderService {
  DriverOrdersPayload payload;
  final bool failAccept;
  final bool failReject;
  final List<String> acceptedOrderIds = <String>[];
  int fetchCalls = 0;

  _FakeDriverOrderService({
    required this.payload,
    this.failAccept = false,
    this.failReject = false,
  });

  @override
  Future<DriverOrdersPayload> fetchOrders() async {
    fetchCalls += 1;
    return payload;
  }

  @override
  Future<DriverOrderModel> fetchOrderDetail(String orderId) async {
    return payload.incoming
        .followedBy(payload.running)
        .firstWhere((order) => order.id == orderId);
  }

  @override
  Future<void> acceptOrder(String orderId) async {
    if (failAccept) {
      throw const DriverOrderApiException('accept failed', statusCode: 500);
    }
    acceptedOrderIds.add(orderId);
    DriverOrderModel? acceptedOrder;
    for (final order in payload.incoming) {
      if (order.id == orderId) {
        acceptedOrder = order;
        break;
      }
    }
    if (acceptedOrder == null) {
      return;
    }

    payload = DriverOrdersPayload(
      incoming: payload.incoming
          .where((order) => order.id != orderId)
          .toList(growable: false),
      running: <DriverOrderModel>[
        ...payload.running.where((order) => order.id != orderId),
        acceptedOrder,
      ],
    );
  }

  @override
  Future<void> rejectOrder(String orderId) async {
    if (failReject) {
      throw const DriverOrderApiException('reject failed', statusCode: 500);
    }
    payload = DriverOrdersPayload(
      incoming: payload.incoming
          .where((order) => order.id != orderId)
          .toList(growable: false),
      running: payload.running,
    );
  }

  @override
  Future<List<DriverHistoryOrderModel>> fetchHistory() async {
    return const <DriverHistoryOrderModel>[];
  }
}

class _FakeAuthSessionNotifier extends AuthSessionNotifier {
  _FakeAuthSessionNotifier(this._initialState);

  final AuthSessionState _initialState;

  @override
  AuthSessionState build() {
    return _initialState;
  }
}

class _FakeOrderChatApiService extends OrderChatApiService {
  _FakeOrderChatApiService() : super(ApiClient());

  int unreadCount = 0;
  int lastReadMessageId = 0;
  int? markedReadMessageId;

  @override
  Future<OrderChatUnreadSummary> fetchUnread({required int orderId}) async {
    return OrderChatUnreadSummary(
      unreadCount: unreadCount,
      lastReadMessageId: lastReadMessageId,
    );
  }

  @override
  Future<OrderChatUnreadSummary> markRead({
    required int orderId,
    required int messageId,
  }) async {
    markedReadMessageId = messageId;
    unreadCount = 0;
    lastReadMessageId = messageId;
    return OrderChatUnreadSummary(
      unreadCount: unreadCount,
      lastReadMessageId: lastReadMessageId,
    );
  }
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
      stats: const UserStatsModel(totalOrders: 0, totalPaid: 0, rating: 0),
      addresses: const <SavedAddressModel>[],
    ),
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
    licenseNumber: 'SIM-DRIVER-001',
    avgRating: 5,
    totalDeliveries: 12,
  );
}

DriverOrderModel _runningOrder(String id) {
  return DriverOrderModel(
    id: id,
    customerName: 'Customer $id',
    pickupAddress: 'Pickup',
    dropoffAddress: 'Dropoff',
    etaMinutes: 8,
    fee: 9000,
    itemCount: 1,
    statusCode: 'DRIVER_ASSIGNED',
  );
}

OrderChatMessageModel _chatMessage({
  required int id,
  required int orderId,
  required int senderUserId,
}) {
  final isDriver = senderUserId == 77;
  return OrderChatMessageModel(
    id: id,
    orderId: orderId,
    senderUserId: senderUserId,
    senderRole: isDriver ? 'driver' : 'customer',
    senderName: isDriver ? 'Driver 77' : 'Customer 7',
    body: isDriver ? 'Pesan driver' : 'Pesan customer',
    clientMessageId: null,
    createdAt: DateTime.utc(2026, 5, 10, 12),
  );
}
