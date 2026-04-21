import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';
import 'package:frontend_bangdeliv/providers/auth_session_provider.dart';
import 'package:frontend_bangdeliv/providers/driver_order_providers.dart';
import 'package:frontend_bangdeliv/services/driver_order_service.dart';

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
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(() => fakeAuth),
        driverOrderServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);

    await container.read(driverOrdersProvider.future);

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
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(() => fakeAuth),
        driverOrderServiceProvider.overrideWithValue(fakeService),
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
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(() => fakeAuth),
        driverOrderServiceProvider.overrideWithValue(fakeService),
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

  test('acceptOrder in mock mode skips API call and keeps success', () async {
    final fakeService = _FakeDriverOrderService(
      payload: const DriverOrdersPayload(
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
        isMockData: true,
      ),
      failAccept: true,
    );
    final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(() => fakeAuth),
        driverOrderServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);

    await container.read(driverOrdersProvider.future);

    final error = await container
        .read(driverOrdersProvider.notifier)
        .acceptOrder('ORD-1');

    final state = container.read(driverOrdersProvider).asData!.value;

    expect(error, isNull);
    expect(state.incoming, isEmpty);
    expect(state.running.length, 1);
    expect(fakeService.acceptedOrderIds, isEmpty);
  });
}

class _FakeDriverOrderService extends DriverOrderService {
  final DriverOrdersPayload payload;
  final bool failAccept;
  final bool failReject;
  final List<String> acceptedOrderIds = <String>[];

  _FakeDriverOrderService({
    required this.payload,
    this.failAccept = false,
    this.failReject = false,
  });

  @override
  Future<DriverOrdersPayload> fetchOrders({bool fallbackToMock = true}) async {
    return payload;
  }

  @override
  Future<void> acceptOrder(String orderId) async {
    if (failAccept) {
      throw const DriverOrderApiException(
        'accept failed',
        statusCode: 500,
      );
    }
    acceptedOrderIds.add(orderId);
  }

  @override
  Future<void> rejectOrder(String orderId) async {
    if (failReject) {
      throw const DriverOrderApiException(
        'reject failed',
        statusCode: 500,
      );
    }
  }

  @override
  Future<List<DriverHistoryOrderModel>> fetchHistory({
    bool fallbackToMock = true,
  }) async {
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

AuthSessionState _driverSession(int userId) {
  return AuthSessionState.fromProfile(
    UserProfileModel(
      id: userId,
      name: 'Driver $userId',
      phone: '08234$userId',
      email: 'driver$userId@example.com',
      role: 'driver',
      driverProfile: const DriverProfileModel(
        registrationStatus: 'active',
        status: 'active',
      ),
      stats: const UserStatsModel(totalOrders: 0, totalPaid: 0, rating: 0),
      addresses: const <SavedAddressModel>[],
    ),
  );
}
