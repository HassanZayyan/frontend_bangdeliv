import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order_chat_model.dart';
import '../services/pusher_service.dart';
import 'api_providers.dart';
import 'auth_session_provider.dart';

final orderChatUnreadCountProvider =
    AsyncNotifierProvider.family
        .autoDispose<OrderChatUnreadNotifier, int, int>(
          OrderChatUnreadNotifier.new,
        );

class OrderChatUnreadNotifier extends AsyncNotifier<int> {
  OrderChatUnreadNotifier(this.orderId);

  final int orderId;
  Timer? _pollTimer;
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;
  bool _disposed = false;

  bool get _isMounted => !_disposed && ref.mounted;

  @override
  Future<int> build() async {
    _disposed = false;
    ref.onDispose(_dispose);

    final session = ref.watch(authSessionProvider);
    if (!_isEligibleSession(session)) {
      return 0;
    }

    _subscribeRealtime();
    _startPolling();
    return _computeUnreadCount();
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
      final unreadCount = await _computeUnreadCount();
      if (_isMounted) {
        state = AsyncData(unreadCount);
      }
    } catch (_) {
      // Keep previous value when refresh fails.
    }
  }

  Future<void> markRead() async {
    if (!_isMounted) {
      return;
    }

    final session = ref.read(authSessionProvider);
    final profile = session.profile;
    if (!_isEligibleSession(session) || profile == null) {
      return;
    }

    try {
      final page = await ref
          .read(orderChatApiServiceProvider)
          .fetchMessages(orderId: orderId, limit: 100);
      final latestMessageId = _latestServerMessageId(page.messages);
      await _writeLastSeenMessageId(
        userId: profile.id,
        role: session.role,
        messageId: latestMessageId,
      );

      if (_isMounted) {
        state = const AsyncData(0);
      }
    } catch (_) {
      // Ignore mark-read failures to avoid disturbing chat flow.
    }
  }

  Future<int> _computeUnreadCount() async {
    final session = ref.read(authSessionProvider);
    final profile = session.profile;
    if (!_isEligibleSession(session) || profile == null) {
      return 0;
    }

    final lastSeenMessageId = await _readLastSeenMessageId(
      userId: profile.id,
      role: session.role,
    );
    final myRoleToken = _sessionRoleToken(session.role);
    final page = await ref
        .read(orderChatApiServiceProvider)
        .fetchMessages(
          orderId: orderId,
          limit: 100,
          afterId: lastSeenMessageId > 0 ? lastSeenMessageId : null,
        );

    return page.messages.where((message) {
      if (!message.hasServerId) return false;
      if (message.id <= lastSeenMessageId) return false;
      return message.senderRole.trim().toLowerCase() != myRoleToken;
    }).length;
  }

  int _latestServerMessageId(List<OrderChatMessageModel> messages) {
    return messages
        .where((message) => message.hasServerId)
        .fold<int>(0, (maxId, message) => message.id > maxId ? message.id : maxId);
  }

  bool _isEligibleSession(AuthSessionState session) {
    return session.isAuthenticated &&
        session.profile != null &&
        (session.role == SessionUserRole.customer ||
            session.role == SessionUserRole.driver);
  }

  String _sessionRoleToken(SessionUserRole role) {
    return role == SessionUserRole.driver ? 'driver' : 'customer';
  }

  String _lastSeenStorageKey({
    required int userId,
    required SessionUserRole role,
  }) {
    final roleToken = _sessionRoleToken(role);
    return 'order_chat_last_seen_${roleToken}_${userId}_$orderId';
  }

  Future<int> _readLastSeenMessageId({
    required int userId,
    required SessionUserRole role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastSeenStorageKey(userId: userId, role: role)) ?? 0;
  }

  Future<void> _writeLastSeenMessageId({
    required int userId,
    required SessionUserRole role,
    required int messageId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastSeenStorageKey(userId: userId, role: role),
      messageId,
    );
  }

  void _subscribeRealtime() {
    if (!_isMounted) {
      return;
    }

    _realtimeSub?.cancel();
    _realtimeSub = PusherService.instance.subscribeOrderTracking(
      orderId,
      onChatMessage: (_) {
        unawaited(refreshUnread());
      },
    );
  }

  void _startPolling() {
    if (!_isMounted) {
      return;
    }

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(refreshUnread());
    });
  }

  void _dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    unawaited(_realtimeSub?.cancel());
    _realtimeSub = null;
  }
}
