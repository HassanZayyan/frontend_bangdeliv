import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/models/order_chat_model.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';
import 'package:frontend_bangdeliv/core/di/app_providers.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/orders/application/order_chat_provider.dart';
import 'package:frontend_bangdeliv/features/orders/application/order_chat_unread_provider.dart';
import 'package:frontend_bangdeliv/features/orders/presentation/screens/order_chat_screen.dart';
import 'package:frontend_bangdeliv/services/api_client.dart';
import 'package:frontend_bangdeliv/services/api_exception.dart';
import 'package:frontend_bangdeliv/services/order_chat_api_service.dart';
import '../fakes/fake_order_realtime_client.dart';

ProviderSubscription<AsyncValue<OrderChatState>> _keepChatProviderAlive(
  ProviderContainer container,
  int orderId,
) {
  return container.listen<AsyncValue<OrderChatState>>(
    orderChatProvider(orderId),
    (_, _) {},
    fireImmediately: true,
  );
}

ProviderSubscription<AsyncValue<int>> _keepUnreadProviderAlive(
  ProviderContainer container,
  int orderId,
) {
  return container.listen<AsyncValue<int>>(
    orderChatUnreadCountProvider(orderId),
    (_, _) {},
    fireImmediately: true,
  );
}

void main() {
  test('orderChatProvider loads messages from API', () async {
    final fakeAuth = _FakeAuthSessionNotifier(_customerSession(7));
    final fakeService = _FakeOrderChatApiService(
      initialPage: OrderChatMessagesPage(
        messages: <OrderChatMessageModel>[
          _message(id: 10, senderUserId: 8, body: 'Saya menuju lokasi.'),
        ],
        canSend: true,
        hasMore: false,
        nextBeforeId: null,
        unreadCount: 1,
        lastReadMessageId: 0,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(() => fakeAuth),
        orderChatApiServiceProvider.overrideWithValue(fakeService),
        orderRealtimeClientProvider.overrideWithValue(
          FakeOrderRealtimeClient(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(orderChatProvider(99).future);

    expect(state.messages.map((message) => message.body), [
      'Saya menuju lokasi.',
    ]);
    expect(state.canSend, isTrue);
    expect(fakeService.fetchCalls, 1);
  });

  test('orderChatProvider appends realtime chat messages', () async {
    final fakeAuth = _FakeAuthSessionNotifier(_customerSession(7));
    final fakeService = _FakeOrderChatApiService(
      initialPage: const OrderChatMessagesPage(
        messages: <OrderChatMessageModel>[],
        canSend: true,
        hasMore: false,
        nextBeforeId: null,
        unreadCount: 0,
        lastReadMessageId: 0,
      ),
    );
    final fakeRealtime = FakeOrderRealtimeClient();

    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(() => fakeAuth),
        orderChatApiServiceProvider.overrideWithValue(fakeService),
        orderRealtimeClientProvider.overrideWithValue(fakeRealtime),
      ],
    );
    addTearDown(container.dispose);
    final chatSubscription = _keepChatProviderAlive(container, 99);
    addTearDown(chatSubscription.close);

    await container.read(orderChatProvider(99).future);
    expect(fakeRealtime.orderTrackingSubscriptions, contains(99));

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    fakeRealtime.emitOrderChatMessage(
      99,
      _message(id: 24, senderUserId: 8, body: 'Pesan realtime.'),
    );
    await Future<void>.delayed(Duration.zero);

    final chat = container.read(orderChatProvider(99)).asData!.value;
    expect(chat.messages.map((message) => message.body), ['Pesan realtime.']);
  });

  test(
    'orderChatProvider appends customer realtime chat for driver session',
    () async {
      final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
      final fakeService = _FakeOrderChatApiService(
        initialPage: const OrderChatMessagesPage(
          messages: <OrderChatMessageModel>[],
          canSend: true,
          hasMore: false,
          nextBeforeId: null,
          unreadCount: 0,
          lastReadMessageId: 0,
        ),
      );
      final fakeRealtime = FakeOrderRealtimeClient();

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
          orderRealtimeClientProvider.overrideWithValue(fakeRealtime),
        ],
      );
      addTearDown(container.dispose);
      final chatSubscription = _keepChatProviderAlive(container, 99);
      addTearDown(chatSubscription.close);

      await container.read(orderChatProvider(99).future);
      expect(fakeRealtime.orderTrackingSubscriptions, contains(99));

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      fakeRealtime.emitOrderChatMessage(
        99,
        _message(id: 26, senderUserId: 7, body: 'Customer realtime.'),
      );
      await Future<void>.delayed(Duration.zero);

      final chat = container.read(orderChatProvider(99)).asData!.value;
      expect(chat.messages.map((message) => message.body), [
        'Customer realtime.',
      ]);
    },
  );

  test(
    'orderChatProvider retries tracking quickly then receives customer chat',
    () async {
      final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
      final fakeService = _FakeOrderChatApiService(
        initialPage: const OrderChatMessagesPage(
          messages: <OrderChatMessageModel>[],
          canSend: true,
          hasMore: false,
          nextBeforeId: null,
          unreadCount: 0,
          lastReadMessageId: 0,
        ),
      );
      final fakeRealtime = FakeOrderRealtimeClient()
        ..failOrderTrackingSubscribeAttempts = 1;

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
          orderRealtimeClientProvider.overrideWithValue(fakeRealtime),
        ],
      );
      addTearDown(container.dispose);
      final chatSubscription = _keepChatProviderAlive(container, 99);
      addTearDown(chatSubscription.close);

      await container.read(orderChatProvider(99).future);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeRealtime.orderTrackingSubscribeCalls, 1);
      expect(fakeRealtime.orderTrackingSubscriptions, isNot(contains(99)));

      await Future<void>.delayed(const Duration(milliseconds: 350));
      await Future<void>.delayed(Duration.zero);

      expect(fakeRealtime.orderTrackingSubscribeCalls, greaterThanOrEqualTo(2));
      expect(fakeRealtime.orderTrackingSubscriptions, contains(99));

      fakeRealtime.emitOrderChatMessage(
        99,
        _message(id: 28, senderUserId: 7, body: 'Customer after retry.'),
      );
      await Future<void>.delayed(Duration.zero);

      final chat = container.read(orderChatProvider(99)).asData!.value;
      expect(chat.messages.map((message) => message.body), [
        'Customer after retry.',
      ]);
    },
  );

  test(
    'orderChatProvider reconciles missed customer chat for driver session',
    () async {
      final previousInterval = orderChatReconciliationInterval;
      orderChatReconciliationInterval = const Duration(milliseconds: 20);
      addTearDown(() {
        orderChatReconciliationInterval = previousInterval;
      });

      final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
      final fakeService = _FakeOrderChatApiService(
        initialPage: const OrderChatMessagesPage(
          messages: <OrderChatMessageModel>[],
          canSend: true,
          hasMore: false,
          nextBeforeId: null,
          unreadCount: 0,
          lastReadMessageId: 0,
        ),
      );
      final fakeRealtime = FakeOrderRealtimeClient();

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
          orderRealtimeClientProvider.overrideWithValue(fakeRealtime),
        ],
      );
      addTearDown(container.dispose);
      final chatSubscription = _keepChatProviderAlive(container, 99);
      addTearDown(chatSubscription.close);

      await container.read(orderChatProvider(99).future);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      fakeService.serverMessages = <OrderChatMessageModel>[
        _message(id: 31, senderUserId: 7, body: 'Missed customer chat.'),
      ];

      await Future<void>.delayed(const Duration(milliseconds: 70));

      final chat = container.read(orderChatProvider(99)).asData!.value;
      expect(chat.messages.map((message) => message.body), [
        'Missed customer chat.',
      ]);
    },
  );

  test(
    'orderChatUnreadCountProvider ignores realtime messages from self',
    () async {
      final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
      final fakeService = _FakeOrderChatApiService(
        initialPage: const OrderChatMessagesPage(
          messages: <OrderChatMessageModel>[],
          canSend: true,
          hasMore: false,
          nextBeforeId: null,
          unreadCount: 0,
          lastReadMessageId: 0,
        ),
        unreadCount: 0,
        lastReadMessageId: 0,
      );
      final fakeRealtime = FakeOrderRealtimeClient();

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
          orderRealtimeClientProvider.overrideWithValue(fakeRealtime),
        ],
      );
      addTearDown(container.dispose);
      final unreadSubscription = _keepUnreadProviderAlive(container, 99);
      addTearDown(unreadSubscription.close);

      await container.read(orderChatUnreadCountProvider(99).future);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      fakeRealtime.emitOrderChatMessage(
        99,
        _message(id: 27, senderUserId: 77, body: 'Pesan sendiri.'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(container.read(orderChatUnreadCountProvider(99)).asData!.value, 0);
    },
  );

  test(
    'orderChatProvider polls once immediately when realtime subscribe fails',
    () async {
      final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
      final fakeService = _FakeOrderChatApiService(
        initialPage: const OrderChatMessagesPage(
          messages: <OrderChatMessageModel>[],
          canSend: true,
          hasMore: false,
          nextBeforeId: null,
          unreadCount: 0,
          lastReadMessageId: 0,
        ),
      );
      final fakeRealtime = FakeOrderRealtimeClient()
        ..failOrderTrackingSubscribeAttempts = 1;

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
          orderRealtimeClientProvider.overrideWithValue(fakeRealtime),
        ],
      );
      addTearDown(container.dispose);

      await container.read(orderChatProvider(99).future);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeService.fetchCalls, greaterThanOrEqualTo(2));
    },
  );

  test(
    'sendMessage shows optimistic item then replaces it with API result',
    () async {
      final fakeAuth = _FakeAuthSessionNotifier(_customerSession(7));
      final sendCompleter = Completer<OrderChatSendResult>();
      final fakeService = _FakeOrderChatApiService(
        initialPage: const OrderChatMessagesPage(
          messages: <OrderChatMessageModel>[],
          canSend: true,
          hasMore: false,
          nextBeforeId: null,
          unreadCount: 0,
          lastReadMessageId: 0,
        ),
        sendCompleter: sendCompleter,
      );

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
          orderRealtimeClientProvider.overrideWithValue(
            FakeOrderRealtimeClient(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(orderChatProvider(99).future);

      final sendFuture = container
          .read(orderChatProvider(99).notifier)
          .sendMessage('Halo driver');

      final optimistic = container.read(orderChatProvider(99)).asData!.value;
      expect(optimistic.isSending, isTrue);
      expect(optimistic.messages.single.isPending, isTrue);
      expect(optimistic.messages.single.body, 'Halo driver');

      final clientMessageId = fakeService.lastClientMessageId!;
      sendCompleter.complete(
        OrderChatSendResult(
          message: _message(
            id: 42,
            senderUserId: 7,
            body: 'Halo driver',
            clientMessageId: clientMessageId,
          ),
          canSend: true,
        ),
      );

      expect(await sendFuture, isNull);

      final sent = container.read(orderChatProvider(99)).asData!.value;
      expect(sent.isSending, isFalse);
      expect(sent.messages.single.id, 42);
      expect(sent.messages.single.isPending, isFalse);
    },
  );

  test(
    'sendMessage recovers persisted message after broadcast-only failure',
    () async {
      final fakeAuth = _FakeAuthSessionNotifier(_customerSession(7));
      final fakeService = _FakeOrderChatApiService(
        initialPage: const OrderChatMessagesPage(
          messages: <OrderChatMessageModel>[],
          canSend: true,
          hasMore: false,
          nextBeforeId: null,
          unreadCount: 0,
          lastReadMessageId: 0,
        ),
        sendError: const ApiException(
          'Pusher error: realtime offline',
          statusCode: 500,
        ),
        recoverFailedSend: true,
      );

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
          orderRealtimeClientProvider.overrideWithValue(
            FakeOrderRealtimeClient(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(orderChatProvider(99).future);

      final error = await container
          .read(orderChatProvider(99).notifier)
          .sendMessage('Tetap tersimpan');

      expect(error, isNull);

      final recovered = container.read(orderChatProvider(99)).asData!.value;
      expect(recovered.messages.single.id, 77);
      expect(recovered.messages.single.body, 'Tetap tersimpan');
      expect(recovered.messages.single.isPending, isFalse);
      expect(recovered.messages.single.isFailed, isFalse);
      expect(recovered.realtimeUnavailable, isFalse);
    },
  );

  test('sendMessage maps raw pusher failures to a friendly message', () async {
    final fakeAuth = _FakeAuthSessionNotifier(_customerSession(7));
    final fakeService = _FakeOrderChatApiService(
      initialPage: const OrderChatMessagesPage(
        messages: <OrderChatMessageModel>[],
        canSend: true,
        hasMore: false,
        nextBeforeId: null,
        unreadCount: 0,
        lastReadMessageId: 0,
      ),
      sendError: const ApiException(
        'Pusher error: cURL error 7',
        statusCode: 500,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(() => fakeAuth),
        orderChatApiServiceProvider.overrideWithValue(fakeService),
        orderRealtimeClientProvider.overrideWithValue(
          FakeOrderRealtimeClient(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(orderChatProvider(99).future);

    final error = await container
        .read(orderChatProvider(99).notifier)
        .sendMessage('Gagal realtime');

    expect(error, 'Gagal mengirim pesan. Chat akan disinkronkan ulang.');

    final failed = container.read(orderChatProvider(99)).asData!.value;
    expect(failed.messages.single.isFailed, isTrue);
  });

  test(
    'sendMessage does not show degraded notice during realtime grace period',
    () async {
      final fakeAuth = _FakeAuthSessionNotifier(_customerSession(7));
      final fakeService = _FakeOrderChatApiService(
        initialPage: const OrderChatMessagesPage(
          messages: <OrderChatMessageModel>[],
          canSend: true,
          hasMore: false,
          nextBeforeId: null,
          unreadCount: 0,
          lastReadMessageId: 0,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
          orderRealtimeClientProvider.overrideWithValue(
            FakeOrderRealtimeClient(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(orderChatProvider(99).future);

      final error = await container
          .read(orderChatProvider(99).notifier)
          .sendMessage('Realtime nonaktif');

      expect(error, isNull);
      expect(
        container.read(orderChatProvider(99)).asData!.value.realtimeUnavailable,
        isFalse,
      );
    },
  );

  test('orderChatUnreadCountProvider loads unread count from API', () async {
    final fakeAuth = _FakeAuthSessionNotifier(_customerSession(7));
    final fakeService = _FakeOrderChatApiService(
      initialPage: const OrderChatMessagesPage(
        messages: <OrderChatMessageModel>[],
        canSend: true,
        hasMore: false,
        nextBeforeId: null,
        unreadCount: 0,
        lastReadMessageId: 0,
      ),
      unreadCount: 3,
      lastReadMessageId: 11,
    );

    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(() => fakeAuth),
        orderChatApiServiceProvider.overrideWithValue(fakeService),
        orderRealtimeClientProvider.overrideWithValue(
          FakeOrderRealtimeClient(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final unread = await container.read(
      orderChatUnreadCountProvider(99).future,
    );

    expect(unread, 3);
    expect(fakeService.fetchUnreadCalls, 1);
  });

  test(
    'orderChatUnreadCountProvider increments from realtime message',
    () async {
      final fakeAuth = _FakeAuthSessionNotifier(_customerSession(7));
      final fakeService = _FakeOrderChatApiService(
        initialPage: const OrderChatMessagesPage(
          messages: <OrderChatMessageModel>[],
          canSend: true,
          hasMore: false,
          nextBeforeId: null,
          unreadCount: 0,
          lastReadMessageId: 0,
        ),
        unreadCount: 0,
        lastReadMessageId: 0,
      );
      final fakeRealtime = FakeOrderRealtimeClient();

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
          orderRealtimeClientProvider.overrideWithValue(fakeRealtime),
        ],
      );
      addTearDown(container.dispose);
      final unreadSubscription = _keepUnreadProviderAlive(container, 99);
      addTearDown(unreadSubscription.close);

      final initial = await container.read(
        orderChatUnreadCountProvider(99).future,
      );
      expect(initial, 0);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      fakeRealtime.emitOrderChatMessage(
        99,
        _message(id: 25, senderUserId: 8, body: 'Badge masuk.'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(container.read(orderChatUnreadCountProvider(99)).asData!.value, 1);

      await container
          .read(orderChatUnreadCountProvider(99).notifier)
          .markReadThrough(25);

      expect(fakeService.markedReadMessageId, 25);
      expect(container.read(orderChatUnreadCountProvider(99)).asData!.value, 0);
    },
  );

  test(
    'orderChatUnreadCountProvider reconciles missed customer chat for driver badge',
    () async {
      final previousInterval = orderChatUnreadReconciliationInterval;
      orderChatUnreadReconciliationInterval = const Duration(milliseconds: 20);
      addTearDown(() {
        orderChatUnreadReconciliationInterval = previousInterval;
      });

      final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
      final fakeService = _FakeOrderChatApiService(
        initialPage: const OrderChatMessagesPage(
          messages: <OrderChatMessageModel>[],
          canSend: true,
          hasMore: false,
          nextBeforeId: null,
          unreadCount: 0,
          lastReadMessageId: 0,
        ),
        unreadCount: 0,
        lastReadMessageId: 0,
      );
      final fakeRealtime = FakeOrderRealtimeClient();

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
          orderRealtimeClientProvider.overrideWithValue(fakeRealtime),
        ],
      );
      addTearDown(container.dispose);
      final unreadSubscription = _keepUnreadProviderAlive(container, 99);
      addTearDown(unreadSubscription.close);

      final initial = await container.read(
        orderChatUnreadCountProvider(99).future,
      );
      expect(initial, 0);

      fakeService.unreadCount = 1;

      await Future<void>.delayed(const Duration(milliseconds: 70));

      expect(container.read(orderChatUnreadCountProvider(99)).asData!.value, 1);
    },
  );

  test(
    'orderChatUnreadCountProvider refreshes immediately when realtime fails',
    () async {
      final fakeAuth = _FakeAuthSessionNotifier(_driverSession(77));
      final fakeService = _FakeOrderChatApiService(
        initialPage: const OrderChatMessagesPage(
          messages: <OrderChatMessageModel>[],
          canSend: true,
          hasMore: false,
          nextBeforeId: null,
          unreadCount: 0,
          lastReadMessageId: 0,
        ),
        unreadCount: 2,
        lastReadMessageId: 9,
      );
      final fakeRealtime = FakeOrderRealtimeClient()
        ..failOrderTrackingSubscribeAttempts = 1;

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
          orderRealtimeClientProvider.overrideWithValue(fakeRealtime),
        ],
      );
      addTearDown(container.dispose);

      final unread = await container.read(
        orderChatUnreadCountProvider(99).future,
      );
      expect(unread, 2);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeService.fetchUnreadCalls, greaterThanOrEqualTo(2));
    },
  );

  test('markReadThrough persists read state through API', () async {
    final fakeAuth = _FakeAuthSessionNotifier(_customerSession(7));
    final fakeService = _FakeOrderChatApiService(
      initialPage: const OrderChatMessagesPage(
        messages: <OrderChatMessageModel>[],
        canSend: true,
        hasMore: false,
        nextBeforeId: null,
        unreadCount: 0,
        lastReadMessageId: 0,
      ),
      unreadCount: 2,
      lastReadMessageId: 9,
    );

    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(() => fakeAuth),
        orderChatApiServiceProvider.overrideWithValue(fakeService),
        orderRealtimeClientProvider.overrideWithValue(
          FakeOrderRealtimeClient(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(orderChatUnreadCountProvider(99).future);
    await container
        .read(orderChatUnreadCountProvider(99).notifier)
        .markReadThrough(15);

    expect(fakeService.markedReadMessageId, 15);
    expect(container.read(orderChatUnreadCountProvider(99)).asData!.value, 0);
  });

  test(
    'sendMessage ignores late response after provider is disposed',
    () async {
      final fakeAuth = _FakeAuthSessionNotifier(_customerSession(7));
      final sendCompleter = Completer<OrderChatSendResult>();
      final fakeService = _FakeOrderChatApiService(
        initialPage: const OrderChatMessagesPage(
          messages: <OrderChatMessageModel>[],
          canSend: true,
          hasMore: false,
          nextBeforeId: null,
          unreadCount: 0,
          lastReadMessageId: 0,
        ),
        sendCompleter: sendCompleter,
      );

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
          orderRealtimeClientProvider.overrideWithValue(
            FakeOrderRealtimeClient(),
          ),
        ],
      );

      await container.read(orderChatProvider(99).future);

      final sendFuture = container
          .read(orderChatProvider(99).notifier)
          .sendMessage('Tutup screen cepat');

      container.dispose();
      sendCompleter.complete(
        OrderChatSendResult(
          message: _message(
            id: 100,
            senderUserId: 7,
            body: 'Tutup screen cepat',
            clientMessageId: fakeService.lastClientMessageId,
          ),
          canSend: true,
        ),
      );

      expect(await sendFuture, isNull);
    },
  );

  testWidgets('OrderChatScreen renders messages and disables composer', (
    tester,
  ) async {
    final fakeAuth = _FakeAuthSessionNotifier(_customerSession(7));
    final fakeService = _FakeOrderChatApiService(
      initialPage: OrderChatMessagesPage(
        messages: <OrderChatMessageModel>[
          _message(id: 10, senderUserId: 8, body: 'Order sudah saya ambil.'),
        ],
        canSend: false,
        hasMore: false,
        nextBeforeId: null,
        unreadCount: 1,
        lastReadMessageId: 0,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
          orderRealtimeClientProvider.overrideWithValue(
            FakeOrderRealtimeClient(),
          ),
        ],
        child: const MaterialApp(home: OrderChatScreen(orderId: 99)),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Order sudah saya ambil.'), findsOneWidget);
    expect(find.text('Sesi chat dengan driver berakhir'), findsOneWidget);
  });
}

class _FakeOrderChatApiService extends OrderChatApiService {
  _FakeOrderChatApiService({
    required this.initialPage,
    List<OrderChatMessageModel>? serverMessages,
    this.sendCompleter,
    this.sendError,
    this.recoverFailedSend = false,
    this.unreadCount = 0,
    this.lastReadMessageId = 0,
  }) : serverMessages = List<OrderChatMessageModel>.from(
         serverMessages ?? initialPage.messages,
       ),
       super(ApiClient());

  final OrderChatMessagesPage initialPage;
  List<OrderChatMessageModel> serverMessages;
  final Completer<OrderChatSendResult>? sendCompleter;
  final Object? sendError;
  final bool recoverFailedSend;
  int unreadCount;
  int lastReadMessageId;
  int fetchCalls = 0;
  int fetchUnreadCalls = 0;
  int? markedReadMessageId;
  String? lastClientMessageId;
  String? lastBody;

  @override
  Future<OrderChatMessagesPage> fetchMessages({
    required int orderId,
    int limit = 50,
    int? beforeId,
    int? afterId,
  }) async {
    fetchCalls += 1;
    if (recoverFailedSend && lastClientMessageId != null && fetchCalls > 1) {
      return OrderChatMessagesPage(
        messages: <OrderChatMessageModel>[
          _message(
            id: 77,
            senderUserId: 7,
            body: lastBody ?? '',
            clientMessageId: lastClientMessageId,
          ),
        ],
        canSend: true,
        hasMore: false,
        nextBeforeId: null,
        unreadCount: 0,
        lastReadMessageId: 0,
      );
    }

    if (afterId != null) {
      final messages = serverMessages
          .where((message) => message.id > afterId)
          .toList(growable: false);
      return OrderChatMessagesPage(
        messages: messages,
        canSend: initialPage.canSend,
        hasMore: initialPage.hasMore,
        nextBeforeId: null,
        unreadCount: unreadCount,
        lastReadMessageId: lastReadMessageId,
      );
    }
    return OrderChatMessagesPage(
      messages: serverMessages,
      canSend: initialPage.canSend,
      hasMore: initialPage.hasMore,
      nextBeforeId: initialPage.nextBeforeId,
      unreadCount: initialPage.unreadCount,
      lastReadMessageId: initialPage.lastReadMessageId,
    );
  }

  @override
  Future<OrderChatSendResult> sendMessage({
    required int orderId,
    required String body,
    required String clientMessageId,
  }) async {
    lastClientMessageId = clientMessageId;
    lastBody = body;
    final error = sendError;
    if (error != null) {
      throw error;
    }

    final completer = sendCompleter;
    if (completer != null) {
      return completer.future;
    }

    return OrderChatSendResult(
      message: _message(
        id: 99,
        senderUserId: 7,
        body: body,
        clientMessageId: clientMessageId,
      ),
      canSend: true,
    );
  }

  @override
  Future<OrderChatUnreadSummary> fetchUnread({required int orderId}) async {
    fetchUnreadCalls += 1;
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
    totalDeliveries: 12,
  );
}

OrderChatMessageModel _message({
  required int id,
  required int senderUserId,
  required String body,
  String? clientMessageId,
}) {
  return OrderChatMessageModel(
    id: id,
    orderId: 99,
    senderUserId: senderUserId,
    senderRole: senderUserId == 7 ? 'customer' : 'driver',
    senderName: senderUserId == 7 ? 'Customer 7' : 'Driver 8',
    body: body,
    clientMessageId: clientMessageId,
    createdAt: DateTime.utc(2026, 5, 2, 12),
  );
}
