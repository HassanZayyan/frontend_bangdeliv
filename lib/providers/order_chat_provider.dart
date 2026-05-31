import 'dart:async';

import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order_chat_model.dart';
import '../services/api_exception.dart';
import 'api_providers.dart';
import 'auth_session_provider.dart';
import 'order_realtime_hub_provider.dart';

final orderChatProvider = AsyncNotifierProvider.family
    .autoDispose<OrderChatNotifier, OrderChatState, int>(OrderChatNotifier.new);

Duration orderChatReconciliationInterval = const Duration(seconds: 2);

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
    this.unreadCount = 0,
    this.lastReadMessageId = 0,
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
  final int unreadCount;
  final int lastReadMessageId;
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
    int? unreadCount,
    int? lastReadMessageId,
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
      realtimeUnavailable: realtimeUnavailable ?? this.realtimeUnavailable,
      unreadCount: unreadCount ?? this.unreadCount,
      lastReadMessageId: lastReadMessageId ?? this.lastReadMessageId,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

class OrderChatNotifier extends AsyncNotifier<OrderChatState> {
  OrderChatNotifier(this.orderId);

  static const _fallbackActivationDelay = Duration(seconds: 4);
  static const _fallbackPollInterval = Duration(seconds: 4);

  final int orderId;

  StreamSubscription<OrderRealtimeEvent>? _hubSub;
  Timer? _fallbackActivationTimer;
  Timer? _degradedSyncTimer;
  Timer? _reconciliationTimer;
  OrderRealtimeHub? _hub;
  bool _disposed = false;
  bool _retainedOrder = false;
  bool _pollInFlight = false;

  bool get _isMounted => !_disposed && ref.mounted;

  @override
  Future<OrderChatState> build() async {
    _disposed = false;
    _cancelRealtime();
    _stopDegradedSync();
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
        unreadCount: page.unreadCount,
        lastReadMessageId: page.lastReadMessageId,
      );
    }

    _subscribeRealtime();
    _startReconciliation();

    return OrderChatState(
      orderId: orderId,
      messages: page.messages,
      canSend: page.canSend,
      hasMore: page.hasMore,
      nextBeforeId: page.nextBeforeId,
      unreadCount: page.unreadCount,
      lastReadMessageId: page.lastReadMessageId,
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
          unreadCount: page.unreadCount,
          lastReadMessageId: page.lastReadMessageId,
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
          messages: _markOptimisticFailed(latest.messages, clientMessageId),
          sendingCount: _decrementSending(latest.sendingCount),
          errorMessage: friendlyError,
        ),
      );

      return friendlyError;
    }
  }

  Future<String?> sendAttachment(
    XFile file, {
    String? body,
    String attachmentType = 'image',
  }) async {
    if (!_isMounted) {
      return null;
    }

    final current = state.asData?.value;
    final session = ref.read(authSessionProvider);
    final profile = session.profile;
    final normalizedBody = (body ?? '').trim();

    if (current == null) {
      return 'Chat belum siap.';
    }
    if (!current.canSend) {
      return 'Chat hanya aktif saat order berlangsung.';
    }
    if (profile == null) {
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
      body: normalizedBody.isEmpty ? 'Mengirim foto...' : normalizedBody,
      clientMessageId: clientMessageId,
      createdAt: DateTime.now().toUtc(),
      attachmentType: attachmentType,
      attachmentUrl: file.path,
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
      final result = await ref
          .read(orderChatApiServiceProvider)
          .sendAttachment(
            orderId: orderId,
            file: file,
            body: normalizedBody,
            attachmentType: attachmentType,
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

      final latest = state.asData?.value;
      final friendlyError = _friendlySendError(error);
      if (latest == null) {
        return friendlyError;
      }

      state = AsyncData(
        latest.copyWith(
          messages: _markOptimisticFailed(latest.messages, clientMessageId),
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

    _cancelRealtime();
    final hub = ref.read(orderRealtimeHubProvider);
    _hub = hub;
    _hubSub = hub.events
        .where((event) => event.orderId == orderId)
        .listen(_handleRealtimeEvent);
    _retainedOrder = true;
    unawaited(hub.retainOrder(orderId));
  }

  void _handleRealtimeEvent(OrderRealtimeEvent event) {
    if (!_isMounted) {
      return;
    }

    switch (event.type) {
      case OrderRealtimeEventType.connected:
        _markRealtimeHealthy();
        unawaited(_pollNewMessages());
        break;
      case OrderRealtimeEventType.chat:
        final message = event.chatMessage;
        if (message != null) {
          _handleRealtimeMessage(message);
        }
        break;
      case OrderRealtimeEventType.connectionIssue:
        _markRealtimeDegraded();
        unawaited(_pollNewMessages());
        break;
      case OrderRealtimeEventType.status:
      case OrderRealtimeEventType.content:
      case OrderRealtimeEventType.location:
        break;
    }
  }

  void _handleRealtimeMessage(OrderChatMessageModel message) {
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
    _markRealtimeHealthy();
  }

  void _markRealtimeHealthy() {
    if (!_isMounted) {
      return;
    }

    _stopDegradedSync();
    final current = state.asData?.value;
    if (current == null || !current.realtimeUnavailable) {
      return;
    }

    state = AsyncData(current.copyWith(realtimeUnavailable: false));
  }

  void _markRealtimeDegraded() {
    if (!_isMounted) {
      return;
    }

    if (_fallbackActivationTimer != null || _degradedSyncTimer != null) {
      return;
    }

    _fallbackActivationTimer = Timer(_fallbackActivationDelay, () {
      _fallbackActivationTimer = null;
      if (!_isMounted) {
        return;
      }

      final current = state.asData?.value;
      if (current != null && !current.realtimeUnavailable) {
        state = AsyncData(current.copyWith(realtimeUnavailable: true));
      }

      unawaited(_pollNewMessages());
      _degradedSyncTimer = Timer.periodic(_fallbackPollInterval, (_) {
        unawaited(_pollNewMessages());
      });
    });
  }

  void _startReconciliation() {
    if (!_isMounted || _reconciliationTimer != null) {
      return;
    }

    _reconciliationTimer = Timer.periodic(
      orderChatReconciliationInterval,
      (_) => unawaited(_pollNewMessages()),
    );
  }

  Future<void> _pollNewMessages() async {
    if (!_isMounted || _pollInFlight) {
      return;
    }

    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final afterId = _latestServerMessageId(current.messages);

    try {
      _pollInFlight = true;
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
          unreadCount: page.unreadCount,
          lastReadMessageId: page.lastReadMessageId,
          clearErrorMessage: true,
        ),
      );
    } catch (_) {
      if (!_isMounted) {
        return;
      }

      final latest = state.asData?.value;
      if (latest == null) return;
      state = AsyncData(latest.copyWith(realtimeUnavailable: true));
    } finally {
      _pollInFlight = false;
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
          unreadCount: page.unreadCount,
          lastReadMessageId: page.lastReadMessageId,
          sendingCount: _decrementSending(latest.sendingCount),
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
        .fold<int>(
          0,
          (maxId, message) => message.id > maxId ? message.id : maxId,
        );
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

  int _compareMessages(OrderChatMessageModel a, OrderChatMessageModel b) {
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
    final hubSubscription = _hubSub;
    _hubSub = null;
    unawaited(hubSubscription?.cancel());
    _releaseRetainedOrder();
  }

  void _stopDegradedSync() {
    _fallbackActivationTimer?.cancel();
    _fallbackActivationTimer = null;
    _degradedSyncTimer?.cancel();
    _degradedSyncTimer = null;
  }

  void _stopReconciliation() {
    _reconciliationTimer?.cancel();
    _reconciliationTimer = null;
  }

  void _releaseRetainedOrder() {
    if (!_retainedOrder) {
      return;
    }

    _hub?.releaseOrder(orderId);
    _retainedOrder = false;
  }

  void _dispose() {
    _disposed = true;
    _cancelRealtime();
    _stopDegradedSync();
    _stopReconciliation();
  }
}
