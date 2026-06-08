import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer_order_model.dart';
import '../services/pusher_service.dart';
import '../utils/order_status.dart';
import 'api_providers.dart';
import 'auth_session_provider.dart';
import 'order_realtime_hub_provider.dart';

final customerOrderTrackingProvider = AsyncNotifierProvider.family
    .autoDispose<
      CustomerOrderTrackingNotifier,
      CustomerOrderTrackingState,
      int
    >(CustomerOrderTrackingNotifier.new);

class CustomerOrderTrackingState {
  const CustomerOrderTrackingState({
    required this.detail,
    this.realtimeConnected = false,
    this.realtimeUnavailable = false,
    this.lastRealtimeEventAt,
    this.lastStatusEventAt,
    this.lastStatusHistoryId,
    this.realtimeMessage,
  });

  final CustomerOrderDetailModel detail;
  final bool realtimeConnected;
  final bool realtimeUnavailable;
  final DateTime? lastRealtimeEventAt;
  final DateTime? lastStatusEventAt;
  final int? lastStatusHistoryId;
  final String? realtimeMessage;

  bool get hasLiveDriverLocation =>
      detail.driverLatitude != null && detail.driverLongitude != null;

  CustomerOrderTrackingState copyWith({
    CustomerOrderDetailModel? detail,
    bool? realtimeConnected,
    bool? realtimeUnavailable,
    DateTime? lastRealtimeEventAt,
    DateTime? lastStatusEventAt,
    int? lastStatusHistoryId,
    String? realtimeMessage,
    bool clearRealtimeMessage = false,
    bool clearLastStatusHistoryId = false,
  }) {
    return CustomerOrderTrackingState(
      detail: detail ?? this.detail,
      realtimeConnected: realtimeConnected ?? this.realtimeConnected,
      realtimeUnavailable: realtimeUnavailable ?? this.realtimeUnavailable,
      lastRealtimeEventAt: lastRealtimeEventAt ?? this.lastRealtimeEventAt,
      lastStatusEventAt: lastStatusEventAt ?? this.lastStatusEventAt,
      lastStatusHistoryId: clearLastStatusHistoryId
          ? null
          : (lastStatusHistoryId ?? this.lastStatusHistoryId),
      realtimeMessage: clearRealtimeMessage
          ? null
          : (realtimeMessage ?? this.realtimeMessage),
    );
  }
}

class CustomerOrderTrackingNotifier
    extends AsyncNotifier<CustomerOrderTrackingState> {
  CustomerOrderTrackingNotifier(this.orderId);

  final int orderId;

  StreamSubscription<OrderRealtimeEvent>? _realtimeSub;
  Timer? _reconcileDebounce;
  Timer? _autoRefreshTimer;
  OrderRealtimeHub? _hub;
  bool _disposed = false;
  bool _retainedOrder = false;
  bool _autoRefreshInFlight = false;

  bool get _isMounted => !_disposed && ref.mounted;

  @override
  Future<CustomerOrderTrackingState> build() async {
    _disposed = false;
    _cancelRealtimeListener();
    _cancelTimers();
    _releaseRetainedOrder();

    ref.onDispose(_disposeRealtime);

    final session = ref.watch(authSessionProvider);
    if (!session.isAuthenticated ||
        session.role != SessionUserRole.customer ||
        session.profile == null) {
      throw StateError('Sesi customer tidak aktif.');
    }

    final hub = ref.read(orderRealtimeHubProvider);
    _hub = hub;
    _realtimeSub = hub.events
        .where((event) => event.orderId == orderId)
        .listen(_handleRealtimeEvent);
    _retainedOrder = true;
    unawaited(hub.retainOrder(orderId));

    final service = ref.watch(customerOrderApiServiceProvider);
    final detail = await service.fetchOrderDetail(orderId);
    if (!_isMounted) {
      return CustomerOrderTrackingState(detail: detail);
    }

    _syncAutoRefresh(detail);

    return CustomerOrderTrackingState(detail: detail);
  }

  void _handleRealtimeEvent(OrderRealtimeEvent event) {
    if (!_isMounted) {
      return;
    }

    switch (event.type) {
      case OrderRealtimeEventType.connected:
        _markRealtimeConnected();
        break;
      case OrderRealtimeEventType.status:
        final status = event.status;
        if (status != null) {
          _applyStatusEvent(status);
        }
        break;
      case OrderRealtimeEventType.content:
        _applyContentEvent(event);
        _scheduleDetailReconciliation();
        break;
      case OrderRealtimeEventType.location:
        _applyLocationEvent(event);
        break;
      case OrderRealtimeEventType.chat:
        break;
      case OrderRealtimeEventType.connectionIssue:
        _markRealtimeUnavailable(
          event.message ??
              'Realtime belum tersambung. Aplikasi akan mencoba ulang.',
        );
        break;
    }
  }

  void _markRealtimeConnected() {
    if (!_isMounted) {
      return;
    }

    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        realtimeConnected: true,
        realtimeUnavailable: false,
        clearRealtimeMessage: true,
      ),
    );
    unawaited(_reconcileDetail());
  }

  void _applyStatusEvent(OrderStatusRealtimeEvent event) {
    if (!_isMounted) {
      return;
    }

    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final statusCode = normalizeOrderStatusCode(event.statusCode);
    if (statusCode.isEmpty) {
      return;
    }

    final statusLabel = orderStatusDisplayLabel(
      statusCode,
      fallbackLabel: event.statusLabel,
    );
    final isTerminal = event.isTerminal ?? isTerminalOrderStatus(statusCode);
    final patchedSummary = current.detail.summary.copyWith(
      statusCode: statusCode,
      statusLabel: statusLabel,
      isTerminalStatus: isTerminal,
    );
    final patchedDetail = current.detail.copyWith(
      summary: patchedSummary,
      timeline: _upsertTimeline(current.detail.timeline, event, statusLabel),
    );

    state = AsyncData(
      current.copyWith(
        detail: patchedDetail,
        realtimeConnected: true,
        realtimeUnavailable: false,
        lastRealtimeEventAt: event.changedAt,
        lastStatusEventAt: event.changedAt,
        lastStatusHistoryId: event.historyId,
        clearLastStatusHistoryId: event.historyId == null,
        clearRealtimeMessage: true,
      ),
    );

    _syncAutoRefresh(patchedDetail);
    _scheduleDetailReconciliation();
  }

  void _applyContentEvent(OrderRealtimeEvent event) {
    if (!_isMounted) {
      return;
    }

    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final pricing = event.payload?['pricing'];
    if (pricing is! Map) {
      return;
    }

    final deliveryFee = _asNullableDouble(pricing['delivery_fee']);
    final totalPrice = _asNullableDouble(pricing['total_price']);
    final deliveryFeeSource = pricing['delivery_fee_source']?.toString();
    final deliveryFeeChangeNote = _firstNonEmptyString([
      pricing['delivery_fee_change_note'],
      pricing['deliveryFeeChangeNote'],
      pricing['delivery_fee_change_reason'],
      pricing['deliveryFeeChangeReason'],
    ]);
    final paymentMethod = pricing['payment_method']?.toString();
    final paymentStatus = pricing['payment_status']?.toString();
    final carefulCarryRequired = _asNullableBool(
      pricing['careful_carry_required'],
    );

    final patchedSummary = current.detail.summary.copyWith(
      totalAmount: totalPrice,
      deliveryFee: deliveryFee,
      deliveryFeeSource: deliveryFeeSource,
      deliveryFeeChangeNote: deliveryFeeChangeNote,
      carefulCarryRequired: carefulCarryRequired,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
    );
    final patchedDetail = current.detail.copyWith(
      summary: patchedSummary,
      deliveryFeeSource: deliveryFeeSource,
      deliveryFeeChangeNote: deliveryFeeChangeNote,
      carefulCarryRequired: carefulCarryRequired,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
    );

    state = AsyncData(
      current.copyWith(
        detail: patchedDetail,
        realtimeConnected: true,
        realtimeUnavailable: false,
        lastRealtimeEventAt: DateTime.now(),
        clearRealtimeMessage: true,
      ),
    );
  }

  void _applyLocationEvent(OrderRealtimeEvent event) {
    if (!_isMounted || event.latitude == null || event.longitude == null) {
      return;
    }

    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final patchedDetail = current.detail.copyWith(
      driverLatitude: event.latitude,
      driverLongitude: event.longitude,
      driverLocationUpdatedAt: event.updatedAt ?? DateTime.now(),
    );

    state = AsyncData(
      current.copyWith(
        detail: patchedDetail,
        realtimeConnected: true,
        realtimeUnavailable: false,
        lastRealtimeEventAt: event.updatedAt ?? DateTime.now(),
        clearRealtimeMessage: true,
      ),
    );
  }

  List<OrderStatusSnapshot> _upsertTimeline(
    List<OrderStatusSnapshot> timeline,
    OrderStatusRealtimeEvent event,
    String statusLabel,
  ) {
    final statusCode = normalizeOrderStatusCode(event.statusCode);
    final historyId = event.historyId ?? 0;
    final snapshot = OrderStatusSnapshot(
      code: statusCode,
      label: statusLabel,
      changedAt: event.changedAt,
      historyId: historyId,
    );

    final next = timeline.toList(growable: true);
    final historyIndex = historyId > 0
        ? next.indexWhere((item) => item.historyId == historyId)
        : -1;

    if (historyIndex >= 0) {
      next[historyIndex] = snapshot;
    } else if (!_hasEquivalentTimelineItem(next, snapshot)) {
      next.add(snapshot);
    }

    next.sort(_compareTimelineItems);
    return next;
  }

  bool _hasEquivalentTimelineItem(
    List<OrderStatusSnapshot> items,
    OrderStatusSnapshot snapshot,
  ) {
    return items.any((item) {
      final sameStatus =
          normalizeOrderStatusCode(item.code) ==
          normalizeOrderStatusCode(snapshot.code);
      final itemTime = item.changedAt?.millisecondsSinceEpoch;
      final snapshotTime = snapshot.changedAt?.millisecondsSinceEpoch;
      return sameStatus && itemTime != null && itemTime == snapshotTime;
    });
  }

  int _compareTimelineItems(OrderStatusSnapshot a, OrderStatusSnapshot b) {
    final aTime = a.changedAt?.millisecondsSinceEpoch ?? 0;
    final bTime = b.changedAt?.millisecondsSinceEpoch ?? 0;
    final byTime = aTime.compareTo(bTime);
    if (byTime != 0) {
      return byTime;
    }

    return a.historyId.compareTo(b.historyId);
  }

  void _scheduleDetailReconciliation() {
    if (!_isMounted) {
      return;
    }

    _reconcileDebounce?.cancel();
    _reconcileDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_reconcileDetail());
    });
  }

  Future<void> _reconcileDetail() async {
    if (!_isMounted) {
      return;
    }

    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    try {
      final service = ref.read(customerOrderApiServiceProvider);
      final fetched = await service.fetchOrderDetail(orderId);
      if (!_isMounted) {
        return;
      }

      final latest = state.asData?.value;
      if (latest == null) {
        return;
      }

      final merged = _mergeReconciledDetail(fetched, latest);
      state = AsyncData(latest.copyWith(detail: merged));
      _syncAutoRefresh(merged);
    } catch (_) {
      // Reconciliation is a safety sync after realtime events. The realtime
      // snapshot remains the source shown to the customer if this fetch fails.
    }
  }

  CustomerOrderDetailModel _mergeReconciledDetail(
    CustomerOrderDetailModel fetched,
    CustomerOrderTrackingState current,
  ) {
    var merged = fetched;

    if (!_fetchedContainsLastStatusEvent(fetched, current)) {
      merged = merged.copyWith(
        summary: fetched.summary.copyWith(
          statusCode: current.detail.summary.statusCode,
          statusLabel: current.detail.summary.statusLabel,
          isTerminalStatus: current.detail.summary.isTerminalStatus,
        ),
        timeline: current.detail.timeline,
      );
    }

    return merged;
  }

  bool _fetchedContainsLastStatusEvent(
    CustomerOrderDetailModel fetched,
    CustomerOrderTrackingState current,
  ) {
    final lastHistoryId = current.lastStatusHistoryId;
    if (lastHistoryId != null && lastHistoryId > 0) {
      return fetched.timeline.any((item) => item.historyId == lastHistoryId);
    }

    final lastStatusEventAt = current.lastStatusEventAt;
    if (lastStatusEventAt == null) {
      return true;
    }

    final currentStatusCode = normalizeOrderStatusCode(
      current.detail.summary.statusCode,
    );
    return fetched.timeline.any((item) {
      final sameStatus =
          normalizeOrderStatusCode(item.code) == currentStatusCode;
      final changedAt = item.changedAt;
      return sameStatus &&
          changedAt != null &&
          !changedAt.isBefore(lastStatusEventAt);
    });
  }

  double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  bool? _asNullableBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }

    return null;
  }

  String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != '-') {
        return text;
      }
    }

    return null;
  }

  void _markRealtimeUnavailable(String message) {
    if (!_isMounted) {
      return;
    }

    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        realtimeConnected: false,
        realtimeUnavailable: true,
        realtimeMessage: message,
      ),
    );
  }

  void _cancelRealtimeListener() {
    _realtimeSub?.cancel();
    _realtimeSub = null;
  }

  void _cancelTimers() {
    _reconcileDebounce?.cancel();
    _reconcileDebounce = null;
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    _autoRefreshInFlight = false;
  }

  void _syncAutoRefresh(CustomerOrderDetailModel detail) {
    if (detail.summary.isTerminalStatus) {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
      _releaseRetainedOrder();
      return;
    }

    if (_autoRefreshTimer != null || !_isMounted) {
      return;
    }

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isMounted || _autoRefreshInFlight) {
        return;
      }

      _autoRefreshInFlight = true;
      unawaited(
        _reconcileDetail().whenComplete(() {
          _autoRefreshInFlight = false;
        }),
      );
    });
  }

  void _releaseRetainedOrder() {
    if (!_retainedOrder) {
      return;
    }

    _hub?.releaseOrder(orderId);
    _retainedOrder = false;
  }

  void _disposeRealtime() {
    _disposed = true;
    _cancelRealtimeListener();
    _cancelTimers();
    _releaseRetainedOrder();
  }
}
