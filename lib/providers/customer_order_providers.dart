import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer_order_model.dart';
import '../utils/order_status.dart';
import 'api_providers.dart';
import 'auth_session_provider.dart';
import 'order_realtime_hub_provider.dart';

final customerOrdersProvider =
    AsyncNotifierProvider<
      CustomerOrdersNotifier,
      List<CustomerOrderSummaryModel>
    >(CustomerOrdersNotifier.new);

final customerOrdersAutoRefreshProvider = Provider.autoDispose<void>((ref) {
  final orders = ref.watch(customerOrdersProvider).asData?.value;
  final hasActiveOrder =
      orders?.any((order) => !order.isTerminalStatus) ?? false;
  if (!hasActiveOrder) {
    return;
  }

  final timer = Timer.periodic(const Duration(seconds: 8), (_) {
    if (!ref.mounted) {
      return;
    }
    unawaited(
      ref.read(customerOrdersProvider.notifier).refresh(showLoading: false),
    );
  });

  ref.onDispose(timer.cancel);
});

class CustomerOrdersNotifier
    extends AsyncNotifier<List<CustomerOrderSummaryModel>> {
  StreamSubscription<OrderRealtimeEvent>? _realtimeSub;
  final Set<int> _retainedOrderIds = <int>{};
  Timer? _reconcileDebounce;
  OrderRealtimeHub? _hub;
  bool _disposeRegistered = false;
  bool _disposed = false;
  bool _silentRefreshInFlight = false;

  bool get _isMounted => !_disposed && ref.mounted;

  @override
  Future<List<CustomerOrderSummaryModel>> build() async {
    _disposed = false;

    if (!_disposeRegistered) {
      ref.onDispose(_disposeRealtime);
      _disposeRegistered = true;
    }

    final session = ref.watch(authSessionProvider);
    if (!session.isAuthenticated ||
        session.role != SessionUserRole.customer ||
        session.profile == null) {
      _releaseAllOrders();
      return const <CustomerOrderSummaryModel>[];
    }

    _ensureRealtimeListener();

    final orders = await _fetchOrders();
    if (!_isMounted) {
      return orders;
    }

    _syncRealtimeSubscriptions(orders);
    return orders;
  }

  Future<void> refresh({bool showLoading = true}) async {
    if (!_isMounted) {
      return;
    }

    if (!showLoading && _silentRefreshInFlight) {
      return;
    }

    final session = ref.read(authSessionProvider);
    if (!session.isAuthenticated ||
        session.role != SessionUserRole.customer ||
        session.profile == null) {
      _releaseAllOrders();
      if (_isMounted) {
        state = const AsyncData(<CustomerOrderSummaryModel>[]);
      }
      return;
    }

    if (showLoading) {
      state = const AsyncLoading<List<CustomerOrderSummaryModel>>();
    }

    try {
      if (!showLoading) {
        _silentRefreshInFlight = true;
      }

      final orders = await _fetchOrders();
      if (!_isMounted) {
        return;
      }

      _syncRealtimeSubscriptions(orders);
      state = AsyncData(orders);
    } catch (error, stackTrace) {
      if (!_isMounted) {
        return;
      }

      if (!showLoading && state.asData != null) {
        return;
      }

      state = AsyncError<List<CustomerOrderSummaryModel>>(error, stackTrace);
    } finally {
      if (!showLoading) {
        _silentRefreshInFlight = false;
      }
    }
  }

  Future<List<CustomerOrderSummaryModel>> _fetchOrders() {
    final service = ref.read(customerOrderApiServiceProvider);
    return service.fetchOrders(page: 1, perPage: 50);
  }

  OrderRealtimeHub _readRealtimeHub() {
    final existingHub = _hub;
    if (existingHub != null) {
      return existingHub;
    }

    final hub = ref.read(orderRealtimeHubProvider);
    _hub = hub;
    return hub;
  }

  void _ensureRealtimeListener() {
    final hub = _readRealtimeHub();
    _realtimeSub ??= hub.events.listen(_handleRealtimeEvent);
  }

  void _handleRealtimeEvent(OrderRealtimeEvent event) {
    if (!_isMounted) {
      return;
    }

    if (event.type == OrderRealtimeEventType.content) {
      _scheduleListReconciliation();
      return;
    }

    if (event.type != OrderRealtimeEventType.status) {
      return;
    }

    final status = event.status;
    if (status == null) {
      return;
    }

    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final index = current.indexWhere((order) => order.id == event.orderId);
    if (index < 0) {
      _scheduleListReconciliation();
      return;
    }

    final statusCode = normalizeOrderStatusCode(status.statusCode);
    if (statusCode.isEmpty) {
      return;
    }

    final statusLabel = orderStatusDisplayLabel(
      statusCode,
      fallbackLabel: status.statusLabel,
    );
    final isTerminal = status.isTerminal ?? isTerminalOrderStatus(statusCode);

    final patchedOrder = current[index].copyWith(
      statusCode: statusCode,
      statusLabel: statusLabel,
      isTerminalStatus: isTerminal,
    );

    final mutable = current.toList(growable: true);
    mutable[index] = patchedOrder;
    state = AsyncData(mutable.toList(growable: false));

    _syncRealtimeSubscriptions(mutable);
    _scheduleListReconciliation();
  }

  void _scheduleListReconciliation() {
    if (!_isMounted) {
      return;
    }

    _reconcileDebounce?.cancel();
    _reconcileDebounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(_reconcileList());
    });
  }

  Future<void> _reconcileList() async {
    if (!_isMounted) {
      return;
    }

    try {
      final orders = await _fetchOrders();
      if (!_isMounted) {
        return;
      }

      _syncRealtimeSubscriptions(orders);
      state = AsyncData(orders);
    } catch (_) {
      // Realtime already patched the visible state. Keep it if reconciliation
      // fails because of a temporary network issue.
    }
  }

  void _syncRealtimeSubscriptions(List<CustomerOrderSummaryModel> orders) {
    final activeOrderIds = orders
        .where((order) => !order.isTerminalStatus)
        .map((order) => order.id)
        .where((id) => id > 0)
        .toSet();

    final hub = _readRealtimeHub();

    final orderIdsToRetain = activeOrderIds
        .difference(_retainedOrderIds)
        .toList(growable: false);
    final orderIdsToRelease = _retainedOrderIds
        .difference(activeOrderIds)
        .toList(growable: false);

    for (final orderId in orderIdsToRetain) {
      _retainedOrderIds.add(orderId);
      unawaited(hub.retainOrder(orderId));
    }

    for (final orderId in orderIdsToRelease) {
      hub.releaseOrder(orderId);
      _retainedOrderIds.remove(orderId);
    }
  }

  void _releaseAllOrders() {
    final hub = _hub;
    if (hub == null) {
      _retainedOrderIds.clear();
      return;
    }
    for (final orderId in _retainedOrderIds) {
      hub.releaseOrder(orderId);
    }
    _retainedOrderIds.clear();
  }

  void _disposeRealtime() {
    _disposed = true;
    _reconcileDebounce?.cancel();
    _realtimeSub?.cancel();
    _realtimeSub = null;
    _releaseAllOrders();
  }
}

final customerSortedOrdersProvider = Provider<List<CustomerOrderSummaryModel>>((
  ref,
) {
  final asyncOrders = ref.watch(customerOrdersProvider);

  return asyncOrders.maybeWhen(
    data: (orders) {
      final sorted = orders.toList(growable: false)
        ..sort((a, b) {
          final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });

      return sorted;
    },
    orElse: () => const <CustomerOrderSummaryModel>[],
  );
});

final customerCompletedOrdersProvider =
    Provider<List<CustomerOrderSummaryModel>>((ref) {
      final orders = ref.watch(customerSortedOrdersProvider);
      return orders.where((order) => order.isCompleted).toList(growable: false);
    });

final customerActivityOrdersProvider =
    Provider<List<CustomerOrderSummaryModel>>((ref) {
      final orders = ref.watch(customerSortedOrdersProvider);
      return orders
          .where((order) => !order.isCompleted)
          .toList(growable: false);
    });

final customerOngoingOrdersProvider = Provider<List<CustomerOrderSummaryModel>>(
  (ref) {
    final orders = ref.watch(customerActivityOrdersProvider);
    return orders
        .where((order) => !order.isTerminalStatus)
        .toList(growable: false);
  },
);

final customerCancelledOrdersProvider =
    Provider<List<CustomerOrderSummaryModel>>((ref) {
      final orders = ref.watch(customerActivityOrdersProvider);
      return orders.where((order) => order.isCancelled).toList(growable: false);
    });

final customerOrderDetailProvider =
    FutureProvider.family<CustomerOrderDetailModel, int>((ref, orderId) async {
      final session = ref.watch(authSessionProvider);
      if (!session.isAuthenticated ||
          session.role != SessionUserRole.customer ||
          session.profile == null) {
        throw StateError('Sesi customer tidak aktif.');
      }

      final service = ref.watch(customerOrderApiServiceProvider);
      return service.fetchOrderDetail(orderId);
    });

final customerActiveOrderProvider = Provider<CustomerOrderSummaryModel?>((ref) {
  final activeOrders = ref.watch(customerOngoingOrdersProvider);

  if (activeOrders.isEmpty) {
    return null;
  }

  return activeOrders.first;
});
