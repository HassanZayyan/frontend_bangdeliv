import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order_chat_model.dart';
import '../services/api_exception.dart';
import '../services/pusher_service.dart';
import 'api_providers.dart';
import 'auth_session_provider.dart';

final orderChatProvider = AsyncNotifierProvider.family
    .autoDispose<OrderChatNotifier, OrderChatState, int>(
  OrderChatNotifier.new,
);

class OrderChatState {
  const OrderChatState({
    required this.orderId,
    required this.messages,
    required this.canSend,
    required this.hasMore,
    required this.nextBeforeId,
    this.isLoadingOlder = false,
    this.sendingCount = 0,
    this.realtimeUnavailable = false,
    this.errorMessage,
  });

  final int orderId;
  final List<OrderChatMessageModel> messages;
  final bool canSend;
  final bool hasMore;
  final int? nextBeforeId;
  final bool isLoadingOlder;
  final int sendingCount;
  final bool realtimeUnavailable;
  final String? errorMessage;
  bool get isSending => sendingCount > 0;

  OrderChatState copyWith({
    List<OrderChatMessageModel>? messages,
    bool? canSend,
    bool? hasMore,
    int? nextBeforeId,
    bool clearNextBeforeId = false,
    bool? isLoadingOlder,
    int? sendingCount,
    bool? realtimeUnavailable,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return OrderChatState(
      orderId: orderId,
      messages: messages ?? this.messages,
      canSend: canSend ?? this.canSend,
      hasMore: hasMore ?? this.hasMore,
      nextBeforeId: clearNextBeforeId
          ? null
          : (nextBeforeId ?? this.nextBeforeId),
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      sendingCount: sendingCount ?? this.sendingCount,
      realtimeUnavailable:
          realtimeUnavailable ?? this.realtimeUnavailable,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

class OrderChatNotifier extends AsyncNotifier<OrderChatState> {
  OrderChatNotifier(this.orderId);

  final int orderId;

  StreamSubscription<Map<String, dynamic>>? _realtimeSub;
  Timer? _pollTimer;
  bool _disposed = false;

  bool get _isMounted => !_disposed && ref.mounted;

  @override
  Future<OrderChatState> build() async {
    _disposed = false;
    _cancelRealtime();
    _pollTimer?.cancel();
    _pollTimer = null;
    ref.onDispose(_dispose);

    final session = ref.watch(authSessionProvider);
    if (!session.isAuthenticated ||
        session.profile == null ||
        (session.role != SessionUserRole.customer &&
            session.role != SessionUserRole.driver)) {
      throw StateError('Sesi pengguna tidak aktif.');
    }

    final page = await ref
        .watch(orderChatApiServiceProvider)
        .fetchMessages(orderId: orderId, limit: 50);

    if (!_isMounted) {
      return OrderChatState(
        orderId: orderId,
        messages: page.messages,
        canSend: page.canSend,
        hasMore: page.hasMore,
        nextBeforeId: page.nextBeforeId,
      );
    }

    _subscribeRealtime();
    _startPolling();

    return OrderChatState(
      orderId: orderId,
      messages: page.messages,
      canSend: page.canSend,
      hasMore: page.hasMore,
      nextBeforeId: page.nextBeforeId,
    );
  }

  Future<void> loadOlder() async {
    if (!_isMounted) {
      return;
    }

    final current = state.asData?.value;
    if (current == null ||
        current.isLoadingOlder ||
        !current.hasMore ||
        current.nextBeforeId == null) {
      return;
    }

    state = AsyncData(
      current.copyWith(isLoadingOlder: true, clearErrorMessage: true),
    );

    try {
      if (!_isMounted) {
        return;
      }

      final page = await ref
          .read(orderChatApiServiceProvider)
          .fetchMessages(
            orderId: orderId,
            limit: 50,
            beforeId: current.nextBeforeId,
          );

      if (!_isMounted) {
        return;
      }

      final latest = state.asData?.value;
      if (latest == null) {
        return;
      }

      state = AsyncData(
        latest.copyWith(
          messages: _mergeMessages(latest.messages, page.messages),
          canSend: page.canSend,
          hasMore: page.hasMore,
          nextBeforeId: page.nextBeforeId,
          clearNextBeforeId: page.nextBeforeId == null,
          isLoadingOlder: false,
          clearErrorMessage: true,
        ),
      );
    } catch (_) {
      if (!_isMounted) {
        return;
      }

      final latest = state.asData?.value;
      if (latest == null) return;
      state = AsyncData(
        latest.copyWith(
          isLoadingOlder: false,
          errorMessage: 'Gagal memuat pesan lama.',
        ),
      );
    }
  }

  Future<String?> sendMessage(String rawBody) async {
    if (!_isMounted) {
      return null;
    }

    final current = state.asData?.value;
    final session = ref.read(authSessionProvider);
    final profile = session.profile;
    final body = rawBody.trim();

    if (current == null) {
      return 'Chat belum siap.';
    }
    if (!current.canSend) {
      return 'Chat hanya aktif saat order berlangsung.';
    }
    if (body.isEmpty || profile == null) {
      return null;
    }

    final clientMessageId = _clientMessageId();
    final optimistic = OrderChatMessageModel(
      id: -DateTime.now().microsecondsSinceEpoch,
      orderId: orderId,
      senderUserId: profile.id,
      senderRole: session.role == SessionUserRole.driver
          ? 'driver'
          : 'customer',
      senderName: profile.name,
      body: body,
      clientMessageId: clientMessageId,
      createdAt: DateTime.now().toUtc(),
      isPending: true,
    );

    state = AsyncData(
      current.copyWith(
        messages: _mergeMessages(current.messages, <OrderChatMessageModel>[
          optimistic,
        ]),
        sendingCount: current.sendingCount + 1,
        clearErrorMessage: true,
      ),
    );

    try {
      if (!_isMounted) {
        return null;
      }

      final result = await ref
          .read(orderChatApiServiceProvider)
          .sendMessage(
            orderId: orderId,
            body: body,
            clientMessageId: clientMessageId,
          );

      if (!_isMounted) {
        return null;
      }

      final latest = state.asData?.value;
      if (latest == null) {
        return null;
      }

      state = AsyncData(
        latest.copyWith(
          messages: _mergeMessages(latest.messages, <OrderChatMessageModel>[
            result.message,
          ]),
          canSend: result.canSend,
          sendingCount: _decrementSending(latest.sendingCount),
          realtimeUnavailable: !result.broadcasted,
          clearErrorMessage: true,
        ),
      );
      return null;
    } catch (error) {
      if (!_isMounted) {
        return null;
      }

      final recovered = await _recoverMessageAfterSendFailure(clientMessageId);
      if (recovered) {
        return null;
      }

      if (!_isMounted) {
        return null;
      }

      final latest = state.asData?.value;
      final friendlyError = _friendlySendError(error);
      if (latest == null) {
        return friendlyError;
      }

      state = AsyncData(
        latest.copyWith(
          messages: _markOptimisticFailed(
            latest.messages,
            clientMessageId,
          ),
          sendingCount: _decrementSending(latest.sendingCount),
          errorMessage: friendlyError,
        ),
      );

      return friendlyError;
    }
  }

  void _subscribeRealtime() {
    if (!_isMounted) {
      return;
    }

    _realtimeSub?.cancel();
    _realtimeSub = PusherService.instance.subscribeOrderTracking(
      orderId,
      onChatMessage: (message) {
        if (!_isMounted) {
          return;
        }

        final current = state.asData?.value;
        if (current == null || message.orderId != orderId) {
          return;
        }

        state = AsyncData(
          current.copyWith(
            messages: _mergeMessages(current.messages, <OrderChatMessageModel>[
              message,
            ]),
            realtimeUnavailable: false,
            clearErrorMessage: true,
          ),
        );
      },
    );
  }

  void _startPolling() {
    if (!_isMounted) {
      return;
    }

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_pollNewMessages());
    });
  }

  Future<void> _pollNewMessages() async {
    if (!_isMounted) {
      return;
    }

    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final afterId = _latestServerMessageId(current.messages);

    try {
      if (!_isMounted) {
        return;
      }

      final page = await ref
          .read(orderChatApiServiceProvider)
          .fetchMessages(
            orderId: orderId,
            limit: 100,
            afterId: afterId > 0 ? afterId : null,
          );

      if (!_isMounted) {
        return;
      }

      final latest = state.asData?.value;
      if (latest == null) {
        return;
      }

      state = AsyncData(
        latest.copyWith(
          messages: _mergeMessages(latest.messages, page.messages),
          canSend: page.canSend,
          realtimeUnavailable: false,
          clearErrorMessage: true,
        ),
      );
    } catch (_) {
      if (!_isMounted) {
        return;
      }

      final latest = state.asData?.value;
      if (latest == null) return;
      state = AsyncData(
        latest.copyWith(realtimeUnavailable: true),
      );
    }
  }

  Future<bool> _recoverMessageAfterSendFailure(String clientMessageId) async {
    if (!_isMounted) {
      return false;
    }

    final current = state.asData?.value;
    if (current == null) {
      return false;
    }

    final alreadyRecovered = current.messages.any(
      (message) =>
          message.clientMessageId == clientMessageId && message.hasServerId,
    );
    if (alreadyRecovered) {
      state = AsyncData(
        current.copyWith(
          sendingCount: _decrementSending(current.sendingCount),
          realtimeUnavailable: true,
          clearErrorMessage: true,
        ),
      );
      return true;
    }

    try {
      final afterId = _latestServerMessageId(current.messages);
      if (!_isMounted) {
        return false;
      }

      final page = await ref
          .read(orderChatApiServiceProvider)
          .fetchMessages(
            orderId: orderId,
            limit: 100,
            afterId: afterId > 0 ? afterId : null,
          );

      if (!_isMounted) {
        return false;
      }

      final latest = state.asData?.value;
      if (latest == null) {
        return false;
      }

      final recovered = page.messages.any(
        (message) => message.clientMessageId == clientMessageId,
      );
      if (!recovered) {
        return false;
      }

      state = AsyncData(
        latest.copyWith(
          messages: _mergeMessages(latest.messages, page.messages),
          canSend: page.canSend,
          sendingCount: _decrementSending(latest.sendingCount),
          realtimeUnavailable: true,
          clearErrorMessage: true,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  int _latestServerMessageId(List<OrderChatMessageModel> messages) {
    return messages
        .where((message) => message.hasServerId)
        .fold<int>(0, (maxId, message) => message.id > maxId ? message.id : maxId);
  }

  String _friendlySendError(Object error) {
    if (error is ApiException) {
      final message = error.message.trim();
      final normalized = message.toLowerCase();
      final isRealtimeBackendFailure =
          (error.statusCode != null && error.statusCode! >= 500) ||
          normalized.contains('pusher') ||
          normalized.contains('broadcast') ||
          normalized.contains('reverb');

      if (isRealtimeBackendFailure) {
        return 'Gagal mengirim pesan. Chat akan disinkronkan ulang.';
      }

      return message.isEmpty ? 'Gagal mengirim pesan.' : message;
    }

    return 'Gagal mengirim pesan.';
  }

  List<OrderChatMessageModel> _markOptimisticFailed(
    List<OrderChatMessageModel> messages,
    String clientMessageId,
  ) {
    return messages
        .map((message) {
          if (message.clientMessageId != clientMessageId) {
            return message;
          }

          return message.copyWith(isPending: false, isFailed: true);
        })
        .toList(growable: false);
  }

  List<OrderChatMessageModel> _mergeMessages(
    List<OrderChatMessageModel> current,
    List<OrderChatMessageModel> incoming,
  ) {
    final next = current.toList(growable: true);

    for (final message in incoming) {
      final clientMessageId = message.clientMessageId?.trim();
      var index = -1;

      if (clientMessageId != null && clientMessageId.isNotEmpty) {
        index = next.indexWhere(
          (item) => item.clientMessageId == clientMessageId,
        );
      }

      if (index < 0 && message.hasServerId) {
        index = next.indexWhere((item) => item.id == message.id);
      }

      if (index < 0) {
        next.add(message);
      } else if (!next[index].hasServerId || message.hasServerId) {
        next[index] = message;
      }
    }

    next.sort(_compareMessages);
    return next.toList(growable: false);
  }

  int _compareMessages(
    OrderChatMessageModel a,
    OrderChatMessageModel b,
  ) {
    final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
    final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
    final byTime = aTime.compareTo(bTime);
    if (byTime != 0) return byTime;
    return a.id.compareTo(b.id);
  }

  String _clientMessageId() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    return 'order-chat-$orderId-$micros-${identityHashCode(this)}';
  }

  int _decrementSending(int value) {
    return value > 0 ? value - 1 : 0;
  }

  void _cancelRealtime() {
    final subscription = _realtimeSub;
    _realtimeSub = null;
    unawaited(subscription?.cancel());
  }

  void _dispose() {
    _disposed = true;
    _cancelRealtime();
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}
