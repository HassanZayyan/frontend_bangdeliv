import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:frontend_bangdeliv/data/repositories/realtime_order_client.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/models/order_chat_model.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';
import 'package:frontend_bangdeliv/core/di/app_providers.dart';
import 'package:frontend_bangdeliv/features/realtime/application/app_realtime_bootstrap_provider.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/driver_orders/application/driver_location_reporter_provider.dart';
import 'package:frontend_bangdeliv/features/driver_orders/application/driver_order_providers.dart';
import 'package:frontend_bangdeliv/features/driver_orders/application/driver_realtime_bootstrap_provider.dart';
import 'package:frontend_bangdeliv/features/orders/application/order_chat_unread_provider.dart';
import 'package:frontend_bangdeliv/services/api_client.dart';
import 'package:frontend_bangdeliv/services/driver_order_service.dart';
import 'package:frontend_bangdeliv/services/order_chat_api_service.dart';
import 'package:frontend_bangdeliv/utils/order_status.dart';
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

    final result = await container
        .read(driverOrdersProvider.notifier)
        .acceptOrder('ORD-1');

    final state = container.read(driverOrdersProvider).asData!.value;

    expect(result.error, isNull);
    expect(result.order?.id, 'ORD-1');
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

    final result = await container
        .read(driverOrdersProvider.notifier)
        .acceptOrder('ORD-1');

    final state = container.read(driverOrdersProvider).asData!.value;

    expect(result.error, isNotNull);
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

  test(
    'rejectOrder success suppresses stale fetch and realtime reinsert',
    () async {
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

      final error = await container
          .read(driverOrdersProvider.notifier)
          .rejectOrder('ORD-1');
      expect(error, isNull);
      expect(
        container.read(driverOrdersProvider).asData!.value.incoming,
        isEmpty,
      );

      fakeService.payload = seededPayload();
      await container
          .read(driverOrdersProvider.notifier)
          .refresh(showLoading: false);
      expect(
        container.read(driverOrdersProvider).asData!.value.incoming,
        isEmpty,
      );

      fakeRealtime.emitDriverOrderAvailable(
        77,
        seededPayload().incoming.single,
      );
      expect(
        container.read(driverOrdersProvider).asData!.value.incoming,
        isEmpty,
      );
    },
  );

  test(
    'terminal transition removes running order and refreshes history',
    () async {
      final fakeService = _FakeDriverOrderService(
        payload: DriverOrdersPayload(
          incoming: const <DriverOrderModel>[],
          running: <DriverOrderModel>[_runningOrder('99')],
        ),
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
          .transitionOrderStatus(
            orderId: '99',
            actionCode: 'COMPLETE',
            targetStatusCode: OrderStatusCodes.completed,
          );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(driverOrdersProvider).asData!.value;
      expect(error, isNull);
      expect(state.running, isEmpty);
      expect(fakeService.transitionedOrderIds, ['99']);
      expect(fakeService.fetchHistoryCalls, greaterThanOrEqualTo(1));
    },
  );

  test('cancelled with fee transition stays in running order', () async {
    final fakeService = _FakeDriverOrderService(
      payload: DriverOrdersPayload(
        incoming: const <DriverOrderModel>[],
        running: <DriverOrderModel>[_runningOrder('99')],
      ),
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
        .transitionOrderStatus(
          orderId: '99',
          actionCode: 'CANCEL_WITH_FEE',
          targetStatusCode: OrderStatusCodes.cancelledWithFee,
        );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(driverOrdersProvider).asData!.value;
    expect(error, isNull);
    expect(state.running, hasLength(1));
    expect(state.running.single.id, '99');
    expect(state.running.single.statusCode, OrderStatusCodes.cancelledWithFee);
    expect(fakeService.fetchHistoryCalls, 0);
  });

  test(
    'terminal realtime status removes running order and refreshes history',
    () async {
      final fakeService = _FakeDriverOrderService(
        payload: DriverOrdersPayload(
          incoming: const <DriverOrderModel>[],
          running: <DriverOrderModel>[_runningOrder('99')],
        ),
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
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(fakeRealtime.orderTrackingSubscriptions, contains(99));

      fakeRealtime.emitOrderStatus(
        99,
        OrderStatusRealtimeEvent(
          statusCode: OrderStatusCodes.completed,
          statusLabel: 'Selesai',
          changedAt: DateTime.utc(2026, 5, 10, 12),
          isTerminal: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(driverOrdersProvider).asData!.value;
      expect(state.running, isEmpty);
      expect(fakeService.fetchHistoryCalls, greaterThanOrEqualTo(1));
    },
  );

  test('cancelled with fee realtime status stays in running order', () async {
    final fakeService = _FakeDriverOrderService(
      payload: DriverOrdersPayload(
        incoming: const <DriverOrderModel>[],
        running: <DriverOrderModel>[_runningOrder('99')],
      ),
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
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    fakeRealtime.emitOrderStatus(
      99,
      OrderStatusRealtimeEvent(
        statusCode: OrderStatusCodes.cancelledWithFee,
        statusLabel: 'Dibatalkan Dengan Biaya',
        changedAt: DateTime.utc(2026, 5, 10, 12),
        isTerminal: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(driverOrdersProvider).asData!.value;
    expect(state.running, hasLength(1));
    expect(state.running.single.statusCode, OrderStatusCodes.cancelledWithFee);
    expect(fakeService.fetchHistoryCalls, 0);
  });

  test(
    'driver location reporter sends updates for trackable running order',
    () async {
      final previousInterval = driverLocationReportInterval;
      driverLocationReportInterval = const Duration(milliseconds: 10);
      addTearDown(() => driverLocationReportInterval = previousInterval);

      final runningOrder = DriverOrderModel(
        id: '99',
        customerName: 'Rina',
        pickupAddress: 'A',
        dropoffAddress: 'B',
        etaMinutes: 10,
        fee: 10000,
        itemCount: 1,
        statusCode: OrderStatusCodes.driverAssigned,
      );
      final fakeService = _FakeDriverOrderService(
        payload: DriverOrdersPayload(
          incoming: const <DriverOrderModel>[],
          running: <DriverOrderModel>[runningOrder],
        ),
      );
      final fakeSource = _FakeDriverLocationSource(
        initial: DriverLocationSnapshot(
          latitude: -7.055,
          longitude: 110.435,
          updatedAt: DateTime.parse('2026-06-08T14:00:00Z'),
        ),
      );
      final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
      final fakeRealtime = FakeOrderRealtimeClient();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          driverOrderServiceProvider.overrideWithValue(fakeService),
          driverLocationSourceProvider.overrideWithValue(fakeSource),
          orderRealtimeClientProvider.overrideWithValue(fakeRealtime),
        ],
      );
      final reporterSub = container.listen(
        driverLocationReporterProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(() {
        reporterSub.close();
        fakeSource.dispose();
        container.dispose();
      });

      await container.read(driverOrdersProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 35));

      expect(fakeService.locationUpdates.length, greaterThanOrEqualTo(2));
      expect(fakeService.locationUpdates.first.orderId, '99');
      expect(fakeService.locationUpdates.first.latitude, -7.055);

      fakeSource.add(
        DriverLocationSnapshot(
          latitude: -7.056,
          longitude: 110.436,
          updatedAt: DateTime.parse('2026-06-08T14:00:10Z'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(fakeService.locationUpdates.last.latitude, -7.056);

      final sentBeforeStop = fakeService.locationUpdates.length;
      fakeService.payload = DriverOrdersPayload(
        incoming: const <DriverOrderModel>[],
        running: <DriverOrderModel>[
          runningOrder.copyWith(statusCode: OrderStatusCodes.delivered),
        ],
      );
      container.invalidate(driverOrdersProvider);
      await container.read(driverOrdersProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(fakeService.locationUpdates.length, sentBeforeStop);
    },
  );

  test(
    'running content event refreshes shopping items without status change',
    () async {
      final initialOrder = _runningOrder(
        '99',
      ).copyWith(statusCode: OrderStatusCodes.driverAssigned);
      final fakeService = _FakeDriverOrderService(
        payload: DriverOrdersPayload(
          incoming: const <DriverOrderModel>[],
          running: <DriverOrderModel>[
            DriverOrderModel(
              id: initialOrder.id,
              customerName: initialOrder.customerName,
              pickupAddress: initialOrder.pickupAddress,
              dropoffAddress: initialOrder.dropoffAddress,
              etaMinutes: initialOrder.etaMinutes,
              fee: initialOrder.fee,
              itemCount: 1,
              statusCode: initialOrder.statusCode,
              shoppingItems: const <DriverShoppingItemModel>[
                DriverShoppingItemModel(
                  id: 1,
                  itemSource: 'MANUAL',
                  name: 'Telur',
                  quantity: 1,
                  unitPrice: 0,
                  subtotal: 0,
                  isAvailable: true,
                  isHeavy: false,
                ),
              ],
            ),
          ],
        ),
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
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(fakeRealtime.orderTrackingSubscriptions, contains(99));

      fakeService.payload = DriverOrdersPayload(
        incoming: const <DriverOrderModel>[],
        running: <DriverOrderModel>[
          DriverOrderModel(
            id: '99',
            customerName: 'Customer 99',
            pickupAddress: 'Pickup',
            dropoffAddress: 'Dropoff',
            etaMinutes: 8,
            fee: 9000,
            itemCount: 2,
            statusCode: OrderStatusCodes.driverAssigned,
            shoppingItems: const <DriverShoppingItemModel>[
              DriverShoppingItemModel(
                id: 1,
                itemSource: 'MANUAL',
                name: 'Telur',
                quantity: 1,
                unitPrice: 0,
                subtotal: 0,
                isAvailable: true,
                isHeavy: false,
              ),
              DriverShoppingItemModel(
                id: 2,
                itemSource: 'MANUAL',
                name: 'Gula',
                quantity: 1,
                unitPrice: 0,
                subtotal: 0,
                isAvailable: true,
                isHeavy: false,
              ),
            ],
          ),
        ],
      );

      fakeRealtime.emitOrderContentUpdated(99, {
        'change_type': 'CUSTOMER_ADD_ITEM',
      });
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(driverOrdersProvider).asData!.value;
      expect(state.running.single.statusCode, OrderStatusCodes.driverAssigned);
      expect(state.running.single.shoppingItems.map((item) => item.name), [
        'Telur',
        'Gula',
      ]);
    },
  );

  test(
    'driverOrdersProvider applies realtime incoming order without refresh',
    () async {
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
    },
  );

  test(
    'driverOrdersProvider reconciles missed incoming order when realtime broadcast fails',
    () async {
      final previousInterval = driverOrdersReconciliationInterval;
      driverOrdersReconciliationInterval = const Duration(milliseconds: 20);
      addTearDown(() {
        driverOrdersReconciliationInterval = previousInterval;
      });

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
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      fakeService.payload = const DriverOrdersPayload(
        incoming: [
          DriverOrderModel(
            id: 'MISSED-1',
            customerName: 'Customer Missed',
            pickupAddress: 'Pickup',
            dropoffAddress: 'Dropoff',
            etaMinutes: 8,
            fee: 9000,
            itemCount: 1,
          ),
        ],
        running: [],
      );

      await Future<void>.delayed(const Duration(milliseconds: 70));

      final state = container.read(driverOrdersProvider).asData!.value;
      expect(state.incoming.map((order) => order.id), ['MISSED-1']);
      expect(fakeService.fetchCalls, greaterThanOrEqualTo(2));
    },
  );

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
    'driver realtime bootstrap waits until accept completes before retaining chat',
    () async {
      final acceptCompleter = Completer<void>();
      final fakeService = _FakeDriverOrderService(
        payload: const DriverOrdersPayload(
          incoming: [
            DriverOrderModel(
              id: '99',
              customerName: 'Customer Courier',
              pickupAddress: 'Pickup',
              dropoffAddress: 'Dropoff',
              etaMinutes: 8,
              fee: 9000,
              itemCount: 1,
            ),
          ],
          running: [],
        ),
        acceptCompleter: acceptCompleter,
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

      final bootstrapSubscription = container.listen<AppRealtimeBootstrapState>(
        appRealtimeBootstrapProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(bootstrapSubscription.close);

      await container.read(driverOrdersProvider.future);
      final acceptFuture = container
          .read(driverOrdersProvider.notifier)
          .acceptOrder('99');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeRealtime.orderTrackingSubscriptions, isNot(contains(99)));

      acceptCompleter.complete();
      expect((await acceptFuture).error, isNull);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeRealtime.orderTrackingSubscriptions, contains(99));
    },
  );

  test(
    'running order tracking retries quickly after transient auth failure',
    () async {
      final fakeService = _FakeDriverOrderService(
        payload: DriverOrdersPayload(
          incoming: const <DriverOrderModel>[],
          running: <DriverOrderModel>[_runningOrder('99')],
        ),
      );
      final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
      final fakeRealtime = FakeOrderRealtimeClient()
        ..failOrderTrackingSubscribeAttempts = 1;
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

      expect(fakeRealtime.orderTrackingSubscribeCalls, 1);
      expect(fakeRealtime.orderTrackingSubscriptions, isNot(contains(99)));

      await Future<void>.delayed(const Duration(milliseconds: 350));
      await Future<void>.delayed(Duration.zero);

      expect(fakeRealtime.orderTrackingSubscribeCalls, greaterThanOrEqualTo(2));
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
    'driver detail reconciliation refetches transfer proof when realtime is missed',
    () async {
      final oldInterval = driverTransferProofReconciliationInterval;
      driverTransferProofReconciliationInterval = const Duration(
        milliseconds: 20,
      );
      addTearDown(() {
        driverTransferProofReconciliationInterval = oldInterval;
      });

      final staleOrder = _transferOrder('99');
      final proofedOrder = _transferOrder(
        '99',
        proofs: [
          DriverOrderProofModel(
            id: 19,
            type: 'payment_transfer',
            label: 'Bukti QRIS',
            photoUrl: 'https://example.com/transfer.jpg',
            status: 'pending',
            createdAt: DateTime.utc(2026, 6, 6, 15, 38),
          ),
        ],
      );
      final fakeService = _FakeDriverOrderService(
        payload: DriverOrdersPayload(
          incoming: const <DriverOrderModel>[],
          running: <DriverOrderModel>[staleOrder],
        ),
        detailResponses: <DriverOrderModel>[staleOrder, proofedOrder],
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

      final subscription = container.listen<void>(
        driverOrderTransferProofReconciliationProvider('99'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final initial = await container.read(
        driverOrderDetailProvider('99').future,
      );
      expect(initial.proofs, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      await Future<void>.delayed(Duration.zero);

      final refreshed = await container.read(
        driverOrderDetailProvider('99').future,
      );
      expect(refreshed.hasProof('payment_transfer'), isTrue);
      expect(refreshed.proofs.single.photoUrl, contains('transfer.jpg'));
      expect(fakeService.fetchDetailCalls, greaterThanOrEqualTo(2));
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
  final Completer<void>? acceptCompleter;
  final List<String> acceptedOrderIds = <String>[];
  final List<DriverOrderModel> detailResponses;
  int fetchCalls = 0;
  int fetchDetailCalls = 0;
  int fetchHistoryCalls = 0;
  final List<String> transitionedOrderIds = <String>[];
  final List<_DriverLocationUpdate> locationUpdates = <_DriverLocationUpdate>[];
  List<DriverHistoryOrderModel> history = const <DriverHistoryOrderModel>[];

  _FakeDriverOrderService({
    required this.payload,
    this.failAccept = false,
    this.failReject = false,
    this.acceptCompleter,
    List<DriverOrderModel>? detailResponses,
  }) : detailResponses = List<DriverOrderModel>.from(
         detailResponses ?? const <DriverOrderModel>[],
       );

  @override
  Future<DriverOrdersPayload> fetchOrders() async {
    fetchCalls += 1;
    return payload;
  }

  @override
  Future<DriverOrderModel> fetchOrderDetail(String orderId) async {
    fetchDetailCalls += 1;
    if (detailResponses.isNotEmpty) {
      final next = detailResponses.removeAt(0);
      _upsertPayloadOrder(next);
      return next;
    }

    return payload.incoming
        .followedBy(payload.running)
        .firstWhere((order) => order.id == orderId);
  }

  void _upsertPayloadOrder(DriverOrderModel order) {
    final incomingIndex = payload.incoming.indexWhere(
      (item) => item.id == order.id,
    );
    if (incomingIndex >= 0) {
      final incoming = List<DriverOrderModel>.from(payload.incoming);
      incoming[incomingIndex] = order;
      payload = DriverOrdersPayload(
        incoming: incoming,
        running: payload.running,
      );
      return;
    }

    final runningIndex = payload.running.indexWhere(
      (item) => item.id == order.id,
    );
    if (runningIndex >= 0) {
      final running = List<DriverOrderModel>.from(payload.running);
      running[runningIndex] = order;
      payload = DriverOrdersPayload(
        incoming: payload.incoming,
        running: running,
      );
    }
  }

  @override
  Future<DriverOrderModel> acceptOrder(String orderId) async {
    if (failAccept) {
      throw const DriverOrderApiException('accept failed', statusCode: 500);
    }
    final completer = acceptCompleter;
    if (completer != null) {
      await completer.future;
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
      return fetchOrderDetail(orderId);
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

    return acceptedOrder.copyWith(
      statusCode: OrderStatusCodes.driverAssigned,
      statusDisplayName: orderStatusLabel(OrderStatusCodes.driverAssigned),
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
  Future<void> updateDriverLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    DateTime? updatedAt,
  }) async {
    locationUpdates.add(
      _DriverLocationUpdate(
        orderId: orderId,
        latitude: latitude,
        longitude: longitude,
        updatedAt: updatedAt,
      ),
    );
  }

  @override
  Future<DriverOrderModel> transitionStatus({
    required String orderId,
    required String actionCode,
    String? targetStatusCode,
    String? note,
    double? latitude,
    double? longitude,
  }) async {
    transitionedOrderIds.add(orderId);
    final updated = payload.running
        .firstWhere((order) => order.id == orderId)
        .copyWith(
          statusCode: targetStatusCode ?? OrderStatusCodes.completed,
          statusDisplayName: 'Selesai',
        );
    payload = DriverOrdersPayload(
      incoming: payload.incoming,
      running: payload.running
          .where((order) => order.id != orderId)
          .toList(growable: false),
    );
    return updated;
  }

  @override
  Future<List<DriverHistoryOrderModel>> fetchHistory() async {
    fetchHistoryCalls += 1;
    return history;
  }
}

class _DriverLocationUpdate {
  const _DriverLocationUpdate({
    required this.orderId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });

  final String orderId;
  final double latitude;
  final double longitude;
  final DateTime? updatedAt;
}

class _FakeDriverLocationSource implements DriverLocationSource {
  _FakeDriverLocationSource({required DriverLocationSnapshot initial})
    : _current = initial;

  LocationPermission permission = LocationPermission.always;
  DriverLocationSnapshot _current;
  final StreamController<DriverLocationSnapshot> _controller =
      StreamController<DriverLocationSnapshot>.broadcast();

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permission = LocationPermission.always;
    return permission;
  }

  @override
  Future<DriverLocationSnapshot> getCurrentPosition() async => _current;

  @override
  Stream<DriverLocationSnapshot> getPositionStream() => _controller.stream;

  void add(DriverLocationSnapshot position) {
    _current = position;
    _controller.add(position);
  }

  void dispose() {
    _controller.close();
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
      stats: const UserStatsModel(totalOrders: 0, totalPaid: 0),
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

DriverOrderModel _transferOrder(
  String id, {
  List<DriverOrderProofModel> proofs = const <DriverOrderProofModel>[],
}) {
  return DriverOrderModel(
    id: id,
    customerName: 'Customer $id',
    pickupAddress: 'Pickup',
    dropoffAddress: 'Dropoff',
    etaMinutes: 8,
    fee: 5000,
    totalPrice: 5000,
    itemCount: 1,
    statusCode: 'DRIVER_ASSIGNED',
    paymentMethod: 'TRANSFER',
    paymentStatus: 'unpaid',
    proofs: proofs,
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
