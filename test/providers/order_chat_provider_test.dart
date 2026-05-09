import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/models/order_chat_model.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';
import 'package:frontend_bangdeliv/providers/api_providers.dart';
import 'package:frontend_bangdeliv/providers/auth_session_provider.dart';
import 'package:frontend_bangdeliv/providers/order_chat_provider.dart';
import 'package:frontend_bangdeliv/screens/order_chat_screen.dart';
import 'package:frontend_bangdeliv/services/api_client.dart';
import 'package:frontend_bangdeliv/services/api_exception.dart';
import 'package:frontend_bangdeliv/services/order_chat_api_service.dart';

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
      ),
    );

    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(() => fakeAuth),
        orderChatApiServiceProvider.overrideWithValue(fakeService),
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
        ),
        sendCompleter: sendCompleter,
      );

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
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
      expect(recovered.realtimeUnavailable, isTrue);
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
    'sendMessage marks realtime unavailable when API saved without broadcast',
    () async {
      final fakeAuth = _FakeAuthSessionNotifier(_customerSession(7));
      final fakeService = _FakeOrderChatApiService(
        initialPage: const OrderChatMessagesPage(
          messages: <OrderChatMessageModel>[],
          canSend: true,
          hasMore: false,
          nextBeforeId: null,
        ),
        broadcastedOnSend: false,
      );

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
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
        isTrue,
      );
    },
  );

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
        ),
        sendCompleter: sendCompleter,
      );

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
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
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(() => fakeAuth),
          orderChatApiServiceProvider.overrideWithValue(fakeService),
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
    this.sendCompleter,
    this.sendError,
    this.recoverFailedSend = false,
    this.broadcastedOnSend = true,
  }) : super(ApiClient());

  final OrderChatMessagesPage initialPage;
  final Completer<OrderChatSendResult>? sendCompleter;
  final Object? sendError;
  final bool recoverFailedSend;
  final bool broadcastedOnSend;
  int fetchCalls = 0;
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
      );
    }

    if (afterId != null) {
      return const OrderChatMessagesPage(
        messages: <OrderChatMessageModel>[],
        canSend: true,
        hasMore: false,
        nextBeforeId: null,
      );
    }
    return initialPage;
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
      broadcasted: broadcastedOnSend,
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
      stats: const UserStatsModel(totalOrders: 0, totalPaid: 0, rating: 0),
      addresses: const <SavedAddressModel>[],
    ),
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
