import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer_order_model.dart';
import '../services/pusher_service.dart';
import '../utils/order_status.dart';
import 'api_providers.dart';
import 'auth_session_provider.dart';
import 'customer_order_realtime_provider.dart';

final customerOrderTrackingProvider = AsyncNotifierProvider.family
    .autoDispose<CustomerOrderTrackingNotifier, CustomerOrderTrackingState, int>(
  CustomerOrderTrackingNotifier.new,
);

class CustomerOrderTrackingState {
  const CustomerOrderTrackingState({
    required this.detail,
    this.realtimeConnected = false,
    this.realtimeUnavailable = false,
    this.lastRealtimeEventAt,
    this.lastStatusEventAt,
    this.lastLocationEventAt,
    this.lastStatusHistoryId,
    this.realtimeMessage,
  });

  final CustomerOrderDetailModel detail;
  final bool realtimeConnected;
  final bool realtimeUnavailable;
  final DateTime? lastRealtimeEventAt;
  final DateTime? lastStatusEventAt;
  final DateTime? lastLocationEventAt;
  final int? lastStatusHistoryId;
  final String? realtimeMessage;

  bool get hasLiveDriverLocation => lastLocationEventAt != null;

  CustomerOrderTrackingState copyWith({
    CustomerOrderDetailModel? detail,
    bool? realtimeConnected,
    bool? realtimeUnavailable,
    DateTime? lastRealtimeEventAt,
    DateTime? lastStatusEventAt,
    DateTime? lastLocationEventAt,
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
      lastLocationEventAt: lastLocationEventAt ?? this.lastLocationEventAt,
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

  StreamSubscription<CustomerOrderRealtimeEvent>? _realtimeSub;
  Timer? _reconcileDebounce;
  CustomerOrderRealtimeHub? _hub;
  bool _disposed = false;
  bool _retainedOrder = false;

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

    final hub = ref.read(customerOrderRealtimeHubProvider);
    _hub = hub;
    _realtimeSub = hub.events
        .where((event) => event.orderId == orderId)
        .listen(_handleRealtimeEvent);
    _retainedOrder = true;
    unawaited(hub.retainOrder(orderId));

    final service = ref.watch(customerOrderApiServiceProvider);
    final detail = await service.fetchOrderDetail(orderId);

    if (detail.summary.isTerminalStatus) {
      _releaseRetainedOrder();
    }

    return CustomerOrderTrackingState(detail: detail);
  }

  void _handleRealtimeEvent(CustomerOrderRealtimeEvent event) {
    switch (event.type) {
      case CustomerOrderRealtimeEventType.status:
        final status = event.status;
        if (status != null) {
          _applyStatusEvent(status);
        }
        break;
      case CustomerOrderRealtimeEventType.location:
        _applyLocationEvent(event);
        break;
      case CustomerOrderRealtimeEventType.connectionIssue:
        _markRealtimeUnavailable(
          event.message ??
              'Realtime belum tersambung. Aplikasi akan mencoba ulang.',
        );
        break;
    }
  }

  void _applyLocationEvent(CustomerOrderRealtimeEvent event) {
    if (_disposed) {
      return;
    }

    final current = state.asData?.value;
    if (current == null ||
        !isDriverLocationTrackable(
          current.detail.summary.statusCode,
          statusLabel: current.detail.summary.statusLabel,
        )) {
      return;
    }

    final lat = event.latitude;
    final lng = event.longitude;
    final updatedAt = event.updatedAt;
    if (lat == null || lng == null || updatedAt == null) {
      return;
    }

    final patchedDetail = current.detail.copyWith(
      driverLatitude: lat,
      driverLongitude: lng,
      driverLocationUpdatedAt: updatedAt,
    );

    state = AsyncData(
      current.copyWith(
        detail: patchedDetail,
        realtimeConnected: true,
        realtimeUnavailable: false,
        lastRealtimeEventAt: updatedAt,
        lastLocationEventAt: updatedAt,
        clearRealtimeMessage: true,
      ),
    );
  }

  void _applyStatusEvent(OrderStatusRealtimeEvent event) {
    if (_disposed) {
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

    final statusLabel = (event.statusLabel ?? '').trim().isNotEmpty
        ? event.statusLabel!.trim()
        : orderStatusLabel(statusCode);
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

    _scheduleDetailReconciliation();

    if (isTerminal) {
      _releaseRetainedOrder();
    }
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
      final sameStatus = normalizeOrderStatusCode(item.code) ==
          normalizeOrderStatusCode(snapshot.code);
      final itemTime = item.changedAt?.millisecondsSinceEpoch;
      final snapshotTime = snapshot.changedAt?.millisecondsSinceEpoch;
      return sameStatus && itemTime != null && itemTime == snapshotTime;
    });
  }

  int _compareTimelineItems(
    OrderStatusSnapshot a,
    OrderStatusSnapshot b,
  ) {
    final aTime = a.changedAt?.millisecondsSinceEpoch ?? 0;
    final bTime = b.changedAt?.millisecondsSinceEpoch ?? 0;
    final byTime = aTime.compareTo(bTime);
    if (byTime != 0) {
      return byTime;
    }

    return a.historyId.compareTo(b.historyId);
  }

  void _scheduleDetailReconciliation() {
    _reconcileDebounce?.cancel();
    _reconcileDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_reconcileDetail());
    });
  }

  Future<void> _reconcileDetail() async {
    final current = state.asData?.value;
    if (_disposed || current == null) {
      return;
    }

    try {
      final service = ref.read(customerOrderApiServiceProvider);
      final fetched = await service.fetchOrderDetail(orderId);
      if (_disposed) {
        return;
      }

      final latest = state.asData?.value;
      if (latest == null) {
        return;
      }

      final merged = _mergeReconciledDetail(fetched, latest);
      state = AsyncData(latest.copyWith(detail: merged));

      if (merged.summary.isTerminalStatus) {
        _releaseRetainedOrder();
      }
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

    if (_shouldPreserveRealtimeLocation(fetched, current)) {
      merged = merged.copyWith(
        driverLatitude: current.detail.driverLatitude,
        driverLongitude: current.detail.driverLongitude,
        driverLocationUpdatedAt: current.detail.driverLocationUpdatedAt,
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

  bool _shouldPreserveRealtimeLocation(
    CustomerOrderDetailModel fetched,
    CustomerOrderTrackingState current,
  ) {
    final lastLocationEventAt = current.lastLocationEventAt;
    if (lastLocationEventAt == null ||
        current.detail.driverLatitude == null ||
        current.detail.driverLongitude == null) {
      return false;
    }

    final fetchedLocationUpdatedAt = fetched.driverLocationUpdatedAt;
    return fetchedLocationUpdatedAt == null ||
        fetchedLocationUpdatedAt.isBefore(lastLocationEventAt);
  }

  void _markRealtimeUnavailable(String message) {
    final current = state.asData?.value;
    if (_disposed || current == null) {
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
