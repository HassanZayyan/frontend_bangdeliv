import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order_chat_model.dart';
import 'api_providers.dart';
import 'auth_session_provider.dart';
import 'order_realtime_hub_provider.dart';

final orderChatUnreadCountProvider = AsyncNotifierProvider.family
    .autoDispose<OrderChatUnreadNotifier, int, int>(
      OrderChatUnreadNotifier.new,
    );

class OrderChatUnreadNotifier extends AsyncNotifier<int> {
  OrderChatUnreadNotifier(this.orderId);

  static const _fallbackActivationDelay = Duration(seconds: 15);
  static const _fallbackRefreshInterval = Duration(seconds: 30);

  final int orderId;
  Timer? _fallbackActivationTimer;
  Timer? _degradedRefreshTimer;
  StreamSubscription<OrderRealtimeEvent>? _realtimeSub;
  OrderRealtimeHub? _hub;
  bool _retainedOrder = false;
  int _lastReadMessageId = 0;
  final Set<int> _countedRealtimeMessageIds = <int>{};
  bool _disposed = false;

  bool get _isMounted => !_disposed && ref.mounted;

  @override
  Future<int> build() async {
    _disposed = false;
    _cancelRealtime();
    ref.onDispose(_dispose);

    final session = ref.watch(authSessionProvider);
    if (!_isEligibleSession(session)) {
      return 0;
    }

    _subscribeRealtime();
    final summary = await _fetchUnreadSummary();
    _applySummary(summary);
    final realtimeCount = _countedRealtimeMessageIds.length;
    return summary.unreadCount > realtimeCount
        ? summary.unreadCount
        : realtimeCount;
  }

  Future<void> refreshUnread() async {
    if (!_isMounted) {
      return;
    }

    final session = ref.read(authSessionProvider);
    if (!_isEligibleSession(session)) {
      if (_isMounted) {
        state = const AsyncData(0);
      }
      return;
    }

    try {
      final summary = await _fetchUnreadSummary();
      if (_isMounted) {
        _applySummary(summary);
        state = AsyncData(summary.unreadCount);
      }
    } catch (_) {
      // Keep previous value when refresh fails.
    }
  }

  Future<void> markReadThrough(int messageId) async {
    if (!_isMounted || messageId <= 0) {
      return;
    }

    final session = ref.read(authSessionProvider);
    if (!_isEligibleSession(session)) {
      return;
    }

    try {
      final summary = await ref
          .read(orderChatApiServiceProvider)
          .markRead(orderId: orderId, messageId: messageId);
      if (_isMounted) {
        _applySummary(summary);
        state = AsyncData(summary.unreadCount);
      }
    } catch (_) {
      if (_isMounted) {
        await refreshUnread();
      }
    }
  }

  Future<OrderChatUnreadSummary> _fetchUnreadSummary() async {
    final session = ref.read(authSessionProvider);
    if (!_isEligibleSession(session)) {
      return const OrderChatUnreadSummary(unreadCount: 0, lastReadMessageId: 0);
    }

    return ref.read(orderChatApiServiceProvider).fetchUnread(orderId: orderId);
  }

  bool _isEligibleSession(AuthSessionState session) {
    return session.isAuthenticated &&
        session.profile != null &&
        (session.role == SessionUserRole.customer ||
            session.role == SessionUserRole.driver);
  }

  void _subscribeRealtime() {
    if (!_isMounted) {
      return;
    }

    _cancelRealtime();
    final hub = ref.read(orderRealtimeHubProvider);
    _hub = hub;
    _realtimeSub = hub.events
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
        unawaited(refreshUnread());
        break;
      case OrderRealtimeEventType.chat:
        final message = event.chatMessage;
        if (message != null) {
          _handleRealtimeMessage(message);
        }
        break;
      case OrderRealtimeEventType.connectionIssue:
        _markRealtimeDegraded();
        unawaited(refreshUnread());
        break;
      case OrderRealtimeEventType.status:
      case OrderRealtimeEventType.location:
        break;
    }
  }

  void _handleRealtimeMessage(OrderChatMessageModel message) {
    if (!_isMounted) {
      return;
    }

    final session = ref.read(authSessionProvider);
    final profile = session.profile;
    if (!_isEligibleSession(session) || profile == null) {
      return;
    }

    _markRealtimeHealthy();

    if (!message.hasServerId ||
        message.id <= _lastReadMessageId ||
        message.senderUserId == profile.id ||
        _countedRealtimeMessageIds.contains(message.id)) {
      return;
    }

    _countedRealtimeMessageIds.add(message.id);
    final current = state.asData?.value ?? 0;
    state = AsyncData(current + 1);
  }

  void _markRealtimeHealthy() {
    _fallbackActivationTimer?.cancel();
    _fallbackActivationTimer = null;
    _degradedRefreshTimer?.cancel();
    _degradedRefreshTimer = null;
  }

  void _markRealtimeDegraded() {
    if (!_isMounted ||
        _fallbackActivationTimer != null ||
        _degradedRefreshTimer != null) {
      return;
    }

    _fallbackActivationTimer = Timer(_fallbackActivationDelay, () {
      _fallbackActivationTimer = null;
      if (!_isMounted || _degradedRefreshTimer != null) {
        return;
      }

      unawaited(refreshUnread());
      _degradedRefreshTimer = Timer.periodic(_fallbackRefreshInterval, (_) {
        unawaited(refreshUnread());
      });
    });
  }

  void _dispose() {
    _disposed = true;
    _fallbackActivationTimer?.cancel();
    _fallbackActivationTimer = null;
    _degradedRefreshTimer?.cancel();
    _degradedRefreshTimer = null;
    _cancelRealtime();
  }

  void _cancelRealtime() {
    final subscription = _realtimeSub;
    _realtimeSub = null;
    unawaited(subscription?.cancel());
    _releaseRetainedOrder();
  }

  void _applySummary(OrderChatUnreadSummary summary) {
    _lastReadMessageId = summary.lastReadMessageId;
    _countedRealtimeMessageIds.removeWhere((id) => id <= _lastReadMessageId);
  }

  void _releaseRetainedOrder() {
    if (!_retainedOrder) {
      return;
    }

    _hub?.releaseOrder(orderId);
    _retainedOrder = false;
  }
}
