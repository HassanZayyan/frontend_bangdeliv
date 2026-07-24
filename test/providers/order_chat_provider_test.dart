import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/models/order_chat_model.dart';
import 'package:frontend_bangdeliv/models/customer_order_model.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';
import 'package:frontend_bangdeliv/core/di/app_providers.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/orders/application/order_chat_provider.dart';
import 'package:frontend_bangdeliv/features/orders/application/order_chat_unread_provider.dart';
import 'package:frontend_bangdeliv/features/orders/application/customer_order_providers.dart';
import 'package:frontend_bangdeliv/features/driver_orders/application/driver_order_providers.dart';
import 'package:frontend_bangdeliv/features/orders/presentation/screens/order_chat_screen.dart';
import 'package:frontend_bangdeliv/services/api_client.dart';
import 'package:frontend_bangdeliv/services/api_exception.dart';
import 'package:frontend_bangdeliv/services/order_chat_api_service.dart';
import 'package:frontend_bangdeliv/widgets/bang_chat_bubble.dart';
import 'package:frontend_bangdeliv/widgets/profile_avatar.dart';
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
    'sendMessage keeps own bubble visible when API result is invalid',
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
        sendResultMessage: const OrderChatMessageModel(
          id: 0,
          orderId: 99,
          senderUserId: 7,
          senderRole: 'customer',
          senderName: 'Customer 7',
          body: '',
          clientMessageId: null,
          createdAt: null,
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
          .sendMessage('Tetap tampil');

      final chat = container.read(orderChatProvider(99)).asData!.value;
      expect(error, 'Format respons pesan chat tidak valid.');
      expect(chat.messages, hasLength(1));
      expect(chat.messages.single.body, 'Tetap tampil');
      expect(chat.messages.single.isPending, isFalse);
      expect(chat.messages.single.isFailed, isTrue);
    },
  );

  test(
    'sendMessage reconciles invalid API result with persisted server message',
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
        sendResultMessage: const OrderChatMessageModel(
          id: 0,
          orderId: 99,
          senderUserId: 7,
          senderRole: 'customer',
          senderName: 'Customer 7',
          body: '',
          clientMessageId: null,
          createdAt: null,
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
          .sendMessage('Tersimpan di server');

      final chat = container.read(orderChatProvider(99)).asData!.value;
      expect(error, isNull);
      expect(chat.messages, hasLength(1));
      expect(chat.messages.single.id, 77);
      expect(chat.messages.single.body, 'Tersimpan di server');
      expect(chat.messages.single.isPending, isFalse);
      expect(chat.messages.single.isFailed, isFalse);
    },
  );

  test(
    'sendMessage dedupes own realtime message against optimistic item',
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

      final sendFuture = container
          .read(orderChatProvider(99).notifier)
          .sendMessage('Halo realtime');
      final clientMessageId = fakeService.lastClientMessageId!;

      fakeRealtime.emitOrderChatMessage(
        99,
        _message(
          id: 55,
          senderUserId: 7,
          body: 'Halo realtime',
          clientMessageId: clientMessageId,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      var chat = container.read(orderChatProvider(99)).asData!.value;
      expect(chat.messages, hasLength(1));
      expect(chat.messages.single.id, 55);
      expect(chat.messages.single.isPending, isFalse);

      sendCompleter.complete(
        OrderChatSendResult(
          message: _message(
            id: 55,
            senderUserId: 7,
            body: 'Halo realtime',
            clientMessageId: clientMessageId,
          ),
          canSend: true,
        ),
      );

      expect(await sendFuture, isNull);
      chat = container.read(orderChatProvider(99)).asData!.value;
      expect(chat.messages, hasLength(1));
      expect(chat.messages.single.id, 55);
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

    expect(
      find.textContaining('Order sudah saya ambil', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Sesi chat dengan driver berakhir'), findsOneWidget);
  });

  testWidgets('OrderChatScreen shows own message immediately after send', (
    tester,
  ) async {
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

    await tester.enterText(find.byType(TextField), 'Pesan sendiri');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(
      find.textContaining('Pesan sendiri', findRichText: true),
      findsOneWidget,
    );

    final clientMessageId = fakeService.lastClientMessageId!;
    sendCompleter.complete(
      OrderChatSendResult(
        message: _message(
          id: 88,
          senderUserId: 7,
          body: 'Pesan sendiri',
          clientMessageId: clientMessageId,
        ),
        canSend: true,
      ),
    );
    await tester.pump();
  });

  testWidgets('OrderChatScreen only shows tail on first bubble in a run', (
    tester,
  ) async {
    final fakeAuth = _FakeAuthSessionNotifier(_customerSession(7));
    final fakeService = _FakeOrderChatApiService(
      initialPage: OrderChatMessagesPage(
        messages: <OrderChatMessageModel>[
          _message(id: 10, senderUserId: 7, body: 'tes'),
          _message(id: 11, senderUserId: 7, body: 'p'),
          _message(id: 12, senderUserId: 8, body: 'siap'),
          _message(id: 13, senderUserId: 8, body: 'otw'),
          _message(id: 14, senderUserId: 7, body: 'oke'),
        ],
        canSend: true,
        hasMore: false,
        nextBeforeId: null,
        unreadCount: 0,
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

    final bubbles = tester.widgetList<BangChatBubble>(
      find.byType(BangChatBubble),
    );

    expect(bubbles.map((bubble) => bubble.showTail), [
      true,
      false,
      true,
      false,
      true,
    ]);
  });

  testWidgets(
    'driver chat opens customer WhatsApp and handles launch failure',
    (tester) async {
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
      final detail = DriverOrderModel.fromJson(const <String, dynamic>{
        'id': 99,
        'customer_name': 'Muhammad Zaky',
        'customer_phone': '081234567890',
        'pickup_address': 'Pickup',
        'dropoff_address': 'Dropoff',
      });
      Uri? launchedUri;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(() => fakeAuth),
            orderChatApiServiceProvider.overrideWithValue(fakeService),
            orderRealtimeClientProvider.overrideWithValue(
              FakeOrderRealtimeClient(),
            ),
            driverOrderDetailProvider.overrideWith(
              (ref, orderId) async => detail,
            ),
          ],
          child: MaterialApp(
            home: OrderChatScreen(
              orderId: 99,
              whatsAppLauncher: (uri) async {
                launchedUri = uri;
                return false;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byTooltip('Buka WhatsApp customer'));
      await tester.pump();

      expect(launchedUri?.path, '/6281234567890');
      expect(launchedUri?.queryParameters['text'], contains('#99'));
      expect(
        find.text('WhatsApp tidak dapat dibuka di perangkat ini.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('customer chat opens assigned driver WhatsApp', (tester) async {
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
    final detail = CustomerOrderDetailModel.fromJson(const <String, dynamic>{
      'id': 99,
      'order_number': 'BD-99',
      'service_type': {'code': 'SHOPPING', 'display_name': 'Nitip'},
      'status': 'DRIVER_ASSIGNED',
      'total_amount': 15000,
      'driver': {
        'user': {'name': 'Driver Satu', 'phone': '082345678901'},
      },
    });
    Uri? launchedUri;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
          orderRealtimeClientProvider.overrideWithValue(
            FakeOrderRealtimeClient(),
          ),
          customerOrderDetailProvider.overrideWith(
            (ref, orderId) async => detail,
          ),
        ],
        child: MaterialApp(
          home: OrderChatScreen(
            orderId: 99,
            whatsAppLauncher: (uri) async {
              launchedUri = uri;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byTooltip('Buka WhatsApp driver'));
    await tester.pump();

    expect(launchedUri?.path, '/6282345678901');
  });

  testWidgets('composer stays mounted while chat is still loading', (
    tester,
  ) async {
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

    // Frame pertama: data chat belum ada, hanya area pesan yang loading.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
  });

  testWidgets('session refresh keeps chat input focused and messages visible', (
    tester,
  ) async {
    final profile = _customerProfile(7);
    final fakeAuth = _FakeAuthSessionNotifier(
      AuthSessionState.fromProfile(profile),
    );
    final fakeService = _FakeOrderChatApiService(
      initialPage: OrderChatMessagesPage(
        messages: <OrderChatMessageModel>[
          _message(id: 10, senderUserId: 8, body: 'Saya menuju lokasi.'),
        ],
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OrderChatScreen(orderId: 99)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byType(TextField));
    await tester.pump();

    final focusNode = tester
        .widget<TextField>(find.byType(TextField))
        .focusNode;
    expect(focusNode?.hasFocus, isTrue);

    // Refresh sesi (mis. saat app resume) menghasilkan objek state baru untuk
    // user yang sama. Chat tidak boleh ikut reload dan keyboard tidak boleh
    // tertutup karena composer dilepas dari tree.
    final fetchCallsBeforeRefresh = fakeService.fetchCalls;
    container
        .read(authSessionProvider.notifier)
        .syncProfile(_customerProfile(7));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(focusNode?.hasFocus, isTrue);
    expect(
      find.textContaining('Saya menuju lokasi', findRichText: true),
      findsOneWidget,
    );
    expect(fakeService.fetchCalls, fetchCallsBeforeRefresh);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('chat header uses seeded participant before detail loads', (
    tester,
  ) async {
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
    final detailCompleter = Completer<CustomerOrderDetailModel>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
          orderRealtimeClientProvider.overrideWithValue(
            FakeOrderRealtimeClient(),
          ),
          customerOrderDetailProvider.overrideWith(
            (ref, orderId) => detailCompleter.future,
          ),
        ],
        child: const MaterialApp(
          home: OrderChatScreen(
            orderId: 99,
            initialParticipantName: 'Zazi',
            initialParticipantAvatarUrl: 'https://example.test/zazi.jpg',
            initialParticipantPhone: '082345678901',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Zazi'), findsOneWidget);
    expect(find.byTooltip('Buka WhatsApp driver'), findsOneWidget);
    expect(
      tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).avatarUrl,
      'https://example.test/zazi.jpg',
    );

    detailCompleter.complete(
      CustomerOrderDetailModel.fromJson(const <String, dynamic>{
        'id': 99,
        'order_number': 'BD-99',
        'service_type': {'code': 'SHOPPING', 'display_name': 'Nitip'},
        'status': 'DRIVER_ASSIGNED',
        'total_amount': 15000,
        'driver': {
          'user': {'name': 'Zazi', 'phone': '082345678901'},
        },
      }),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Zazi'), findsOneWidget);
    expect(find.byTooltip('Buka WhatsApp driver'), findsOneWidget);
  });
}

class _FakeOrderChatApiService extends OrderChatApiService {
  _FakeOrderChatApiService({
    required this.initialPage,
    List<OrderChatMessageModel>? serverMessages,
    this.sendCompleter,
    this.sendResultMessage,
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
  final OrderChatMessageModel? sendResultMessage;
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

    final resultMessage = sendResultMessage;
    if (resultMessage != null) {
      return OrderChatSendResult(message: resultMessage, canSend: true);
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

UserProfileModel _customerProfile(int userId) {
  return UserProfileModel(
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
  );
}

AuthSessionState _customerSession(int userId) {
  return AuthSessionState.fromProfile(_customerProfile(userId));
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
