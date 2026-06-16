import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/driver_order_model.dart';
import '../../../data/repositories/driver_order_repository.dart';
import '../../../services/driver_order_service.dart';
import '../../../utils/order_formatters.dart';
import '../../../utils/order_status.dart';
import '../../../utils/order_ui_helpers.dart';
import '../../../core/di/app_providers.dart';
import '../../auth/application/auth_session_provider.dart';
import '../../realtime/application/order_realtime_hub_provider.dart';

Duration driverOrdersReconciliationInterval = const Duration(seconds: 2);
Duration driverTransferProofReconciliationInterval = const Duration(seconds: 4);

class DriverOrdersState {
  final List<DriverOrderModel> incoming;
  final List<DriverOrderModel> running;
  final Set<String> processingActionKeys;
  final Set<String> suppressedIncomingOrderIds;

  const DriverOrdersState({
    required this.incoming,
    required this.running,
    this.processingActionKeys = const <String>{},
    this.suppressedIncomingOrderIds = const <String>{},
  });

  DriverOrdersState copyWith({
    List<DriverOrderModel>? incoming,
    List<DriverOrderModel>? running,
    Set<String>? processingActionKeys,
    Set<String>? suppressedIncomingOrderIds,
  }) {
    return DriverOrdersState(
      incoming: incoming ?? this.incoming,
      running: running ?? this.running,
      processingActionKeys: processingActionKeys ?? this.processingActionKeys,
      suppressedIncomingOrderIds:
          suppressedIncomingOrderIds ?? this.suppressedIncomingOrderIds,
    );
  }

  Set<String> get processingOrderIds {
    final orderIds = <String>{};
    for (final key in processingActionKeys) {
      final orderId = DriverOrderActionKeys.orderIdFromKey(key);
      if (orderId != null) {
        orderIds.add(orderId);
      }
    }
    return Set<String>.unmodifiable(orderIds);
  }

  bool isProcessing(String orderId) => processingActionKeys.any(
    (key) => DriverOrderActionKeys.belongsToOrder(key, orderId),
  );

  bool isProcessingAction(String actionKey) {
    return processingActionKeys.contains(actionKey);
  }
}

class DriverOrderActionKeys {
  const DriverOrderActionKeys._();

  static const _separator = '::';

  static String accept(String orderId) => _build(orderId, 'accept');

  static String reject(String orderId) => _build(orderId, 'reject');

  static String transition(String orderId, String actionCode) {
    return _build(orderId, 'transition:${_normalize(actionCode)}');
  }

  static String collectCod(String orderId) => _build(orderId, 'collectCod');

  static String confirmQris(String orderId) => _build(orderId, 'confirmQris');

  static String updateFee(String orderId) => _build(orderId, 'updateFee');

  static String acceptDeliveryFeeCounter(String orderId) {
    return _build(orderId, 'acceptDeliveryFeeCounter');
  }

  static String uploadProof(String orderId, String proofType) {
    return _build(orderId, 'uploadProof:${_normalize(proofType)}');
  }

  static String shoppingCheckout(String orderId) {
    return _build(orderId, 'shoppingCheckout');
  }

  static String shoppingPriceQuote(String orderId) {
    return _build(orderId, 'shoppingPriceQuote');
  }

  static String acceptShoppingCounter(String orderId) {
    return _build(orderId, 'acceptShoppingCounter');
  }

  static String updateShoppingItems(String orderId) {
    return _build(orderId, 'updateShoppingItems');
  }

  static String pickupFailed(String orderId) => _build(orderId, 'pickupFailed');

  static bool belongsToOrder(String actionKey, String orderId) {
    return actionKey.startsWith('$orderId$_separator');
  }

  static String? orderIdFromKey(String actionKey) {
    final separatorIndex = actionKey.indexOf(_separator);
    if (separatorIndex <= 0) {
      return null;
    }
    return actionKey.substring(0, separatorIndex);
  }

  static String _build(String orderId, String action) {
    return '$orderId$_separator$action';
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase();
  }
}

class DriverOrderAcceptResult {
  const DriverOrderAcceptResult({this.order, this.error});

  final DriverOrderModel? order;
  final String? error;

  bool get isSuccess => error == null;
}

class DriverOrdersNotifier extends AsyncNotifier<DriverOrdersState> {
  StreamSubscription<Map<String, dynamic>>? _driverRealtimeSub;
  StreamSubscription<OrderRealtimeEvent>? _runningOrderRealtimeSub;
  OrderRealtimeHub? _runningOrderRealtimeHub;
  Timer? _degradedRefreshTimer;
  Timer? _driverRealtimeRetryTimer;
  Timer? _incomingReconciliationTimer;
  final Set<int> _retainedRunningOrderIds = <int>{};
  int? _targetDriverUserId;
  int _driverRealtimeRetryAttempt = 0;
  bool _driverRealtimeSubscribed = false;
  bool _disposed = false;
  bool _silentRefreshInFlight = false;
  bool _refreshedAfterRealtimeSubscribe = false;

  bool get _isMounted => !_disposed && ref.mounted;

  @override
  Future<DriverOrdersState> build() async {
    _disposed = false;
    _cancelRealtime();
    _releaseRunningOrderRealtime();
    _stopDegradedRefresh();
    _stopIncomingReconciliation();
    ref.onDispose(_dispose);

    final session = ref.watch(authSessionProvider);
    if (!session.isAuthenticated ||
        session.role != SessionUserRole.driver ||
        session.profile == null) {
      _cancelRealtime();
      _releaseRunningOrderRealtime();
      _stopIncomingReconciliation();
      return const DriverOrdersState(
        incoming: <DriverOrderModel>[],
        running: <DriverOrderModel>[],
      );
    }

    final payload = await ref.read(driverOrderRepositoryProvider).fetchOrders();
    _syncRealtimeSubscription(session);
    _startIncomingReconciliation();

    final next = DriverOrdersState(
      incoming: payload.incoming,
      running: payload.running,
      processingActionKeys: const <String>{},
    );
    _syncRunningOrderRealtime(next);
    return next;
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
        session.role != SessionUserRole.driver ||
        session.profile == null) {
      _cancelRealtime();
      _releaseRunningOrderRealtime();
      _stopDegradedRefresh();
      _stopIncomingReconciliation();
      state = const AsyncData(
        DriverOrdersState(
          incoming: <DriverOrderModel>[],
          running: <DriverOrderModel>[],
        ),
      );
      return;
    }

    final previous = state.asData?.value;

    if (showLoading) {
      state = const AsyncLoading<DriverOrdersState>();
    }

    try {
      if (!showLoading) {
        _silentRefreshInFlight = true;
      }

      final suppressedIncomingOrderIds =
          previous?.suppressedIncomingOrderIds ?? const <String>{};
      final processingActionKeys =
          previous?.processingActionKeys ?? const <String>{};
      final payload = await ref
          .read(driverOrderRepositoryProvider)
          .fetchOrders();
      if (!_isMounted) {
        return;
      }

      _syncRealtimeSubscription(session);
      _startIncomingReconciliation();
      final latest = state.asData?.value;
      final effectiveSuppressedIncomingOrderIds = <String>{
        ...suppressedIncomingOrderIds,
        ...?latest?.suppressedIncomingOrderIds,
      };
      final effectiveProcessingActionKeys =
          latest?.processingActionKeys ?? processingActionKeys;
      final next = DriverOrdersState(
        incoming: _filterSuppressedIncomingOrders(
          payload.incoming,
          effectiveSuppressedIncomingOrderIds,
        ),
        running: payload.running,
        processingActionKeys: effectiveProcessingActionKeys,
        suppressedIncomingOrderIds: effectiveSuppressedIncomingOrderIds,
      );
      state = AsyncData(next);
      _syncRunningOrderRealtime(next);
    } catch (error, stackTrace) {
      if (!_isMounted) {
        return;
      }

      if (!showLoading && state.asData != null) {
        return;
      }

      state = AsyncError(error, stackTrace);
    } finally {
      if (!showLoading) {
        _silentRefreshInFlight = false;
      }
    }
  }

  void _syncRealtimeSubscription(AuthSessionState session) {
    final profile = session.profile;
    if (!_isMounted ||
        !session.isAuthenticated ||
        session.role != SessionUserRole.driver ||
        profile == null) {
      _cancelRealtime();
      return;
    }

    final driverUserId = profile.id;
    if (_driverRealtimeSub != null && _targetDriverUserId == driverUserId) {
      if (!_driverRealtimeSubscribed) {
        _scheduleRealtimeRetry(driverUserId);
      }
      return;
    }

    if (_driverRealtimeSub != null) {
      _cancelRealtimeSubscription(keepTarget: true);
    }

    _refreshedAfterRealtimeSubscribe = false;
    _targetDriverUserId = driverUserId;
    _driverRealtimeSubscribed = false;
    _driverRealtimeSub = ref
        .read(orderRealtimeClientProvider)
        .subscribeDriverOrders(
          driverUserId,
          onOrderAvailable: _handleRealtimeOrderAvailable,
          onOrderRemoved: (orderId, reason) =>
              _handleRealtimeOrderRemoved(orderId, reason: reason),
          onSubscribed: () => _handleRealtimeSubscribed(driverUserId),
          onConnectionIssue: _handleRealtimeConnectionIssue,
        );
  }

  void _handleRealtimeSubscribed(int driverUserId) {
    if (!_isMounted || _targetDriverUserId != driverUserId) {
      return;
    }

    _driverRealtimeSubscribed = true;
    _driverRealtimeRetryAttempt = 0;
    _markRealtimeHealthy();
    _refreshAfterRealtimeSubscribe();
  }

  void _handleRealtimeConnectionIssue(Object error) {
    if (!_isMounted) {
      return;
    }

    final retryUserId = _targetDriverUserId;
    _cancelRealtimeSubscription(keepTarget: true);
    _markRealtimeDegraded();

    if (retryUserId != null && retryUserId > 0) {
      _scheduleRealtimeRetry(retryUserId);
    }
  }

  void _handleRealtimeOrderAvailable(DriverOrderModel order) {
    if (!_isMounted) {
      return;
    }

    final current = state.asData?.value;
    if (current == null || order.id.trim().isEmpty) {
      return;
    }

    if (current.suppressedIncomingOrderIds.contains(order.id)) {
      return;
    }

    if (current.running.any((item) => item.id == order.id)) {
      return;
    }

    state = AsyncData(
      current.copyWith(incoming: _upsertIncomingOrder(current.incoming, order)),
    );
    _markRealtimeHealthy();
  }

  void _handleRealtimeOrderRemoved(String orderId, {String? reason}) {
    if (!_isMounted) {
      return;
    }

    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    final incoming = current.incoming
        .where((order) => order.id != orderId)
        .toList(growable: false);
    final shouldSuppress = _isRejectedByCurrentDriver(reason);
    if (incoming.length == current.incoming.length && !shouldSuppress) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        incoming: incoming,
        suppressedIncomingOrderIds: shouldSuppress
            ? <String>{...current.suppressedIncomingOrderIds, orderId}
            : current.suppressedIncomingOrderIds,
      ),
    );
    _markRealtimeHealthy();
  }

  List<DriverOrderModel> _upsertIncomingOrder(
    List<DriverOrderModel> incoming,
    DriverOrderModel order,
  ) {
    final next = List<DriverOrderModel>.from(incoming);
    final index = next.indexWhere((item) => item.id == order.id);
    if (index < 0) {
      next.insert(0, order);
    } else {
      next[index] = order;
    }

    return next.toList(growable: false);
  }

  void _markRealtimeHealthy() {
    _stopDegradedRefresh();
    _stopRealtimeRetry();
  }

  void _markRealtimeDegraded() {
    if (!_isMounted || _degradedRefreshTimer != null) {
      return;
    }

    _degradedRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(refresh(showLoading: false));
    });
  }

  void _startIncomingReconciliation() {
    if (!_isMounted || _incomingReconciliationTimer != null) {
      return;
    }

    _incomingReconciliationTimer = Timer.periodic(
      driverOrdersReconciliationInterval,
      (_) {
        if (!_isMounted) {
          _stopIncomingReconciliation();
          return;
        }

        final session = ref.read(authSessionProvider);
        if (!session.isAuthenticated ||
            session.role != SessionUserRole.driver ||
            session.profile == null) {
          _stopIncomingReconciliation();
          return;
        }

        unawaited(refresh(showLoading: false));
      },
    );
  }

  void _scheduleRealtimeRetry(int driverUserId) {
    if (!_isMounted || _driverRealtimeRetryTimer != null) {
      return;
    }

    _driverRealtimeRetryAttempt += 1;
    final delaySeconds = switch (_driverRealtimeRetryAttempt) {
      1 => 1,
      2 => 2,
      3 => 5,
      _ => 15,
    };

    _driverRealtimeRetryTimer = Timer(Duration(seconds: delaySeconds), () {
      _driverRealtimeRetryTimer = null;
      if (!_isMounted || _targetDriverUserId != driverUserId) {
        return;
      }

      _syncRealtimeSubscription(ref.read(authSessionProvider));
    });
  }

  void _refreshAfterRealtimeSubscribe() {
    if (!_isMounted || _refreshedAfterRealtimeSubscribe) {
      return;
    }

    _refreshedAfterRealtimeSubscribe = true;
    unawaited(refresh(showLoading: false));
  }

  void _refreshAvailabilityThenSyncRealtime() {
    final session = ref.read(authSessionProvider);
    unawaited(
      ref
          .read(driverAvailabilityProvider.future)
          .then((_) {
            if (_isMounted) {
              _syncRealtimeSubscription(session);
            }
          })
          .catchError((_) {
            if (_isMounted) {
              _syncRealtimeSubscription(session);
            }
          }),
    );
  }

  DriverOrdersState _markActionProcessing(
    DriverOrdersState current, {
    required String actionKey,
  }) {
    return current.copyWith(
      processingActionKeys: <String>{
        ...current.processingActionKeys,
        actionKey,
      },
    );
  }

  DriverOrdersState _clearActionProcessing(
    DriverOrdersState current, {
    required String actionKey,
  }) {
    final nextActionKeys = <String>{...current.processingActionKeys}
      ..remove(actionKey);

    return current.copyWith(processingActionKeys: nextActionKeys);
  }

  Future<DriverOrderAcceptResult> acceptOrder(String id) async {
    final current = state.asData?.value;
    if (current == null) {
      return const DriverOrderAcceptResult(error: 'Data order belum siap.');
    }

    final actionKey = DriverOrderActionKeys.accept(id);
    if (current.isProcessing(id)) {
      return const DriverOrderAcceptResult();
    }

    final index = current.incoming.indexWhere((order) => order.id == id);
    if (index < 0) {
      return const DriverOrderAcceptResult(error: 'Order tidak ditemukan.');
    }

    final incoming = List<DriverOrderModel>.from(current.incoming);
    final selected = incoming
        .removeAt(index)
        .copyWith(
          acceptedAt: _currentHourMinute(),
          statusCode: OrderStatusCodes.driverAssigned,
          statusDisplayName: orderStatusLabel(OrderStatusCodes.driverAssigned),
        );
    final running = <DriverOrderModel>[selected, ...current.running];

    state = AsyncData(
      _markActionProcessing(
        current.copyWith(incoming: incoming, running: running),
        actionKey: actionKey,
      ),
    );
    _syncRunningOrderRealtime(state.asData!.value);

    try {
      final syncedOrder = await ref
          .read(driverOrderRepositoryProvider)
          .acceptOrder(id);

      final latest = state.asData?.value;
      if (latest == null) {
        return DriverOrderAcceptResult(order: syncedOrder);
      }

      final syncedRunning = _upsertRunningOrder(latest.running, syncedOrder);
      state = AsyncData(
        _clearActionProcessing(
          latest.copyWith(running: syncedRunning),
          actionKey: actionKey,
        ),
      );
      _syncRunningOrderRealtime(state.asData!.value);

      ref.invalidate(driverOrderDetailProvider(id));
      ref.invalidate(driverAvailabilityProvider);

      return DriverOrderAcceptResult(order: syncedOrder);
    } catch (error) {
      state = AsyncData(_clearActionProcessing(current, actionKey: actionKey));
      _syncRunningOrderRealtime(state.asData!.value);
      return DriverOrderAcceptResult(error: error.toString());
    }
  }

  Future<String?> rejectOrder(String id) async {
    final current = state.asData?.value;
    if (current == null) {
      return 'Data order belum siap.';
    }

    final actionKey = DriverOrderActionKeys.reject(id);
    if (current.isProcessing(id)) {
      return null;
    }

    final incoming = current.incoming
        .where((order) => order.id != id)
        .toList(growable: false);

    if (incoming.length == current.incoming.length) {
      return 'Order tidak ditemukan.';
    }

    final suppressedIncomingOrderIds = <String>{
      ...current.suppressedIncomingOrderIds,
      id,
    };

    state = AsyncData(
      _markActionProcessing(
        current.copyWith(
          incoming: incoming,
          suppressedIncomingOrderIds: suppressedIncomingOrderIds,
        ),
        actionKey: actionKey,
      ),
    );

    try {
      await ref.read(driverOrderRepositoryProvider).rejectOrder(id);

      final latest = state.asData?.value;
      if (latest == null) {
        return null;
      }

      state = AsyncData(_clearActionProcessing(latest, actionKey: actionKey));
      ref.invalidate(driverAvailabilityProvider);
      _refreshAvailabilityThenSyncRealtime();

      return null;
    } catch (error) {
      state = AsyncData(_clearActionProcessing(current, actionKey: actionKey));
      return error.toString();
    }
  }

  Future<String?> transitionOrderStatus({
    required String orderId,
    required String actionCode,
    String? targetStatusCode,
    String? note,
  }) async {
    final current = state.asData?.value;
    if (current == null) {
      return 'Data order belum siap.';
    }

    if (current.isProcessing(orderId)) {
      return 'Aksi order sebelumnya masih diproses. Tunggu sebentar.';
    }

    final actionKey = DriverOrderActionKeys.transition(orderId, actionCode);

    state = AsyncData(_markActionProcessing(current, actionKey: actionKey));

    try {
      final updated = await ref
          .read(driverOrderRepositoryProvider)
          .transitionStatus(
            orderId: orderId,
            actionCode: actionCode,
            targetStatusCode: targetStatusCode,
            note: note,
          );

      final latest = state.asData?.value;
      if (latest == null) {
        return null;
      }

      final isDriverRunning = isDriverRunningOrderStatus(updated.statusCode);
      final syncedRunning = isDriverRunning
          ? _upsertRunningOrder(latest.running, updated)
          : _removeRunningOrder(latest.running, orderId);
      final shouldRefreshHistory =
          !isDriverRunning && isTerminalOrderStatus(updated.statusCode);

      state = AsyncData(
        _clearActionProcessing(
          latest.copyWith(running: syncedRunning),
          actionKey: actionKey,
        ),
      );
      _syncRunningOrderRealtime(state.asData!.value);

      ref.invalidate(driverOrderDetailProvider(orderId));
      ref.invalidate(driverAvailabilityProvider);
      if (shouldRefreshHistory) {
        unawaited(
          ref.read(driverHistoryProvider.notifier).refresh(showLoading: false),
        );
      }
      _refreshAvailabilityThenSyncRealtime();
      return null;
    } catch (error) {
      final latest = state.asData?.value;
      if (latest == null) {
        return error.toString();
      }

      state = AsyncData(_clearActionProcessing(latest, actionKey: actionKey));
      _syncRunningOrderRealtime(state.asData!.value);
      return error.toString();
    }
  }

  Future<String?> collectCod({
    required String orderId,
    required double amount,
    String? note,
  }) async {
    final current = state.asData?.value;
    if (current == null) {
      return 'Data order belum siap.';
    }

    if (current.isProcessing(orderId)) {
      return 'Aksi order sebelumnya masih diproses. Tunggu sebentar.';
    }

    final actionKey = DriverOrderActionKeys.collectCod(orderId);

    state = AsyncData(_markActionProcessing(current, actionKey: actionKey));

    try {
      await ref
          .read(driverOrderRepositoryProvider)
          .collectCod(orderId: orderId, amount: amount, note: note);

      final refreshed = await ref
          .read(driverOrderRepositoryProvider)
          .fetchOrderDetail(orderId);

      final latest = state.asData?.value;
      if (latest == null) {
        return null;
      }

      state = AsyncData(
        _clearActionProcessing(
          latest.copyWith(
            running: _upsertRunningOrder(latest.running, refreshed),
          ),
          actionKey: actionKey,
        ),
      );
      _syncRunningOrderRealtime(state.asData!.value);

      ref.invalidate(driverOrderDetailProvider(orderId));
      return null;
    } catch (error) {
      final latest = state.asData?.value;
      if (latest == null) {
        return error.toString();
      }

      state = AsyncData(_clearActionProcessing(latest, actionKey: actionKey));
      return error.toString();
    }
  }

  Future<String?> confirmTransferPayment({
    required String orderId,
    required double amount,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.confirmQris(orderId),
      request: (service) =>
          service.confirmTransferPayment(orderId: orderId, amount: amount),
    );
  }

  Future<String?> updateDeliveryFeeOverride({
    required String orderId,
    required double amount,
    required String reason,
    bool? carefulCarryRequired,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.updateFee(orderId),
      request: (service) => service.updateDeliveryFeeOverride(
        orderId: orderId,
        amount: amount,
        reason: reason,
        carefulCarryRequired: carefulCarryRequired,
      ),
    );
  }

  Future<String?> acceptDeliveryFeeCounterOffer({
    required String orderId,
    String? note,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.acceptDeliveryFeeCounter(orderId),
      request: (repository) => repository.acceptDeliveryFeeCounterOffer(
        orderId: orderId,
        note: note,
      ),
    );
  }

  Future<String?> uploadProof({
    required String orderId,
    required String type,
    required XFile photo,
    String? note,
    int? pickupLocationId,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.uploadProof(orderId, type),
      request: (service) => service.uploadProof(
        orderId: orderId,
        type: type,
        photo: photo,
        note: note,
        pickupLocationId: pickupLocationId,
      ),
    );
  }

  Future<String?> updateShoppingCheckout({
    required String orderId,
    required List<Map<String, dynamic>> items,
    required double shoppingTotalAmount,
    double? deliveryFeeOverride,
    String? receiptNote,
    XFile? receiptPhoto,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.shoppingCheckout(orderId),
      request: (service) => service.updateShoppingCheckout(
        orderId: orderId,
        items: items,
        shoppingTotalAmount: shoppingTotalAmount,
        deliveryFeeOverride: deliveryFeeOverride,
        receiptNote: receiptNote,
        receiptPhoto: receiptPhoto,
      ),
    );
  }

  Future<String?> submitShoppingPriceQuote({
    required String orderId,
    required double amount,
    int? pickupLocationId,
    String? note,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.shoppingPriceQuote(orderId),
      request: (repository) => repository.submitShoppingPriceQuote(
        orderId: orderId,
        amount: amount,
        pickupLocationId: pickupLocationId,
        note: note,
      ),
    );
  }

  Future<String?> acceptShoppingCounterOffer({
    required String orderId,
    String? note,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.acceptShoppingCounter(orderId),
      request: (repository) =>
          repository.acceptShoppingCounterOffer(orderId: orderId, note: note),
    );
  }

  Future<String?> _mutateRunningOrder({
    required String orderId,
    required String actionKey,
    required Future<DriverOrderModel> Function(DriverOrderRepository repository)
    request,
  }) async {
    final current = state.asData?.value;
    if (current == null) {
      return 'Data order belum siap.';
    }

    if (current.isProcessing(orderId)) {
      return 'Aksi order sebelumnya masih diproses. Tunggu sebentar.';
    }

    state = AsyncData(_markActionProcessing(current, actionKey: actionKey));

    try {
      final updated = await request(ref.read(driverOrderRepositoryProvider));

      final latest = state.asData?.value;
      if (latest == null) {
        return null;
      }

      state = AsyncData(
        _clearActionProcessing(
          latest.copyWith(
            running: _upsertRunningOrder(latest.running, updated),
          ),
          actionKey: actionKey,
        ),
      );
      _syncRunningOrderRealtime(state.asData!.value);

      ref.invalidate(driverOrderDetailProvider(orderId));
      return null;
    } catch (error) {
      final latest = state.asData?.value;
      if (latest == null) {
        return error.toString();
      }

      state = AsyncData(_clearActionProcessing(latest, actionKey: actionKey));
      return error.toString();
    }
  }

  Future<String?> updateShoppingItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
    String? receiptNote,
  }) async {
    final current = state.asData?.value;
    if (current == null) {
      return 'Data order belum siap.';
    }

    if (current.isProcessing(orderId)) {
      return null;
    }

    final actionKey = DriverOrderActionKeys.updateShoppingItems(orderId);
    state = AsyncData(_markActionProcessing(current, actionKey: actionKey));

    try {
      final updated = await ref
          .read(driverOrderRepositoryProvider)
          .updateShoppingItems(
            orderId: orderId,
            items: items,
            receiptNote: receiptNote,
          );

      final latest = state.asData?.value;
      if (latest == null) {
        return null;
      }

      state = AsyncData(
        _clearActionProcessing(
          latest.copyWith(
            running: _upsertRunningOrder(latest.running, updated),
          ),
          actionKey: actionKey,
        ),
      );
      _syncRunningOrderRealtime(state.asData!.value);

      ref.invalidate(driverOrderDetailProvider(orderId));
      return null;
    } catch (error) {
      final latest = state.asData?.value;
      if (latest == null) {
        return error.toString();
      }

      state = AsyncData(_clearActionProcessing(latest, actionKey: actionKey));
      return error.toString();
    }
  }

  Future<String?> recordShoppingPickupFailed({
    required String orderId,
    required int pickupLocationId,
    required String reason,
    XFile? storeClosedPhoto,
  }) async {
    final current = state.asData?.value;
    if (current == null) {
      return 'Data order belum siap.';
    }

    if (current.isProcessing(orderId)) {
      return null;
    }

    final actionKey = DriverOrderActionKeys.pickupFailed(orderId);
    state = AsyncData(_markActionProcessing(current, actionKey: actionKey));

    try {
      if (storeClosedPhoto != null) {
        await ref
            .read(driverOrderRepositoryProvider)
            .uploadProof(
              orderId: orderId,
              type: 'store_closed',
              photo: storeClosedPhoto,
              note: reason,
              pickupLocationId: pickupLocationId,
            );
      }

      final updated = await ref
          .read(driverOrderRepositoryProvider)
          .recordShoppingPickupFailed(
            orderId: orderId,
            pickupLocationId: pickupLocationId,
            reason: reason,
          );

      final latest = state.asData?.value;
      if (latest == null) {
        return null;
      }

      state = AsyncData(
        _clearActionProcessing(
          latest.copyWith(
            running: _upsertRunningOrder(latest.running, updated),
          ),
          actionKey: actionKey,
        ),
      );
      _syncRunningOrderRealtime(state.asData!.value);

      ref.invalidate(driverOrderDetailProvider(orderId));
      return null;
    } catch (error) {
      final latest = state.asData?.value;
      if (latest == null) {
        return error.toString();
      }

      state = AsyncData(_clearActionProcessing(latest, actionKey: actionKey));
      return error.toString();
    }
  }

  List<DriverOrderModel> _upsertRunningOrder(
    List<DriverOrderModel> running,
    DriverOrderModel updated,
  ) {
    final next = List<DriverOrderModel>.from(running);
    final index = next.indexWhere((order) => order.id == updated.id);

    if (index < 0) {
      next.insert(0, updated);
      return next;
    }

    next[index] = updated;
    return next;
  }

  List<DriverOrderModel> _removeRunningOrder(
    List<DriverOrderModel> running,
    String orderId,
  ) {
    return running
        .where((order) => order.id != orderId)
        .toList(growable: false);
  }

  List<DriverOrderModel> _filterSuppressedIncomingOrders(
    List<DriverOrderModel> incoming,
    Set<String> suppressedOrderIds,
  ) {
    if (suppressedOrderIds.isEmpty) {
      return incoming;
    }

    return incoming
        .where((order) => !suppressedOrderIds.contains(order.id))
        .toList(growable: false);
  }

  bool _isRejectedByCurrentDriver(String? reason) {
    final normalized = (reason ?? '').trim().toLowerCase();
    return normalized == 'rejected_by_driver' ||
        normalized == 'driver_rejected' ||
        normalized == 'rejected';
  }

  void _syncRunningOrderRealtime(DriverOrdersState current) {
    if (!_isMounted) {
      return;
    }

    final nextIds = current.running
        .where((order) => !current.processingOrderIds.contains(order.id))
        .map((order) => int.tryParse(order.id.trim()))
        .whereType<int>()
        .where((orderId) => orderId > 0)
        .toSet();

    final hub = ref.read(orderRealtimeHubProvider);
    _runningOrderRealtimeHub = hub;

    for (final orderId in _retainedRunningOrderIds.difference(nextIds)) {
      hub.releaseOrder(orderId);
    }

    for (final orderId in nextIds.difference(_retainedRunningOrderIds)) {
      unawaited(hub.retainOrder(orderId));
    }

    _retainedRunningOrderIds
      ..clear()
      ..addAll(nextIds);

    if (_retainedRunningOrderIds.isEmpty) {
      final subscription = _runningOrderRealtimeSub;
      _runningOrderRealtimeSub = null;
      unawaited(subscription?.cancel());
      return;
    }

    _runningOrderRealtimeSub ??= hub.events
        .where((event) => _retainedRunningOrderIds.contains(event.orderId))
        .listen(_handleRunningOrderRealtimeEvent);
  }

  void _handleRunningOrderRealtimeEvent(OrderRealtimeEvent event) {
    if (!_isMounted) {
      return;
    }

    if (event.type == OrderRealtimeEventType.content) {
      unawaited(_refreshRunningOrderFromServer(event.orderId.toString()));
      return;
    }

    if (event.type != OrderRealtimeEventType.status) {
      return;
    }

    final statusEvent = event.status;
    if (statusEvent == null) {
      return;
    }

    final orderId = event.orderId.toString();
    final current = state.asData?.value;
    if (current == null ||
        !current.running.any((order) => order.id == orderId)) {
      return;
    }

    final statusCode = normalizeOrderStatusCode(statusEvent.statusCode);
    if (statusCode.isEmpty) {
      return;
    }

    final statusLabel = (statusEvent.statusLabel ?? '').trim().isEmpty
        ? orderStatusLabel(statusCode)
        : statusEvent.statusLabel!.trim();
    final isDriverRunning = isDriverRunningOrderStatus(statusCode);
    final isTerminal =
        !isDriverRunning &&
        (statusEvent.isTerminal ?? isTerminalOrderStatus(statusCode));
    final running = isTerminal
        ? _removeRunningOrder(current.running, orderId)
        : _upsertRunningOrder(
            current.running,
            current.running
                .firstWhere((order) => order.id == orderId)
                .copyWith(
                  statusCode: statusCode,
                  statusDisplayName: statusLabel,
                ),
          );

    final next = current.copyWith(running: running);
    state = AsyncData(next);
    _syncRunningOrderRealtime(next);

    ref.invalidate(driverOrderDetailProvider(orderId));
    if (isTerminal) {
      ref.invalidate(driverAvailabilityProvider);
      unawaited(
        ref.read(driverHistoryProvider.notifier).refresh(showLoading: false),
      );
      _refreshAvailabilityThenSyncRealtime();
    }
  }

  Future<void> _refreshRunningOrderFromServer(String orderId) async {
    final current = state.asData?.value;
    if (current == null ||
        !current.running.any((order) => order.id == orderId)) {
      return;
    }

    try {
      final updated = await ref
          .read(driverOrderRepositoryProvider)
          .fetchOrderDetail(orderId);
      final latest = state.asData?.value;
      if (latest == null) {
        return;
      }

      final next = latest.copyWith(
        running: _upsertRunningOrder(latest.running, updated),
      );
      state = AsyncData(next);
      _syncRunningOrderRealtime(next);
      ref.invalidate(driverOrderDetailProvider(orderId));
    } catch (_) {
      // Periodic reconciliation will catch up after transient failures.
    }
  }

  String _currentHourMinute() {
    return currentWibHourMinute();
  }

  void _cancelRealtime() {
    _cancelRealtimeSubscription();
    _stopRealtimeRetry();
  }

  void _releaseRunningOrderRealtime() {
    final subscription = _runningOrderRealtimeSub;
    _runningOrderRealtimeSub = null;
    unawaited(subscription?.cancel());

    final hub = _runningOrderRealtimeHub;
    if (hub != null) {
      for (final orderId in _retainedRunningOrderIds) {
        hub.releaseOrder(orderId);
      }
    }
    _retainedRunningOrderIds.clear();
    _runningOrderRealtimeHub = null;
  }

  void _cancelRealtimeSubscription({bool keepTarget = false}) {
    final subscription = _driverRealtimeSub;
    _driverRealtimeSub = null;
    _driverRealtimeSubscribed = false;
    if (!keepTarget) {
      _targetDriverUserId = null;
      _driverRealtimeRetryAttempt = 0;
    }
    _refreshedAfterRealtimeSubscribe = false;
    unawaited(subscription?.cancel());
  }

  void _stopDegradedRefresh() {
    _degradedRefreshTimer?.cancel();
    _degradedRefreshTimer = null;
  }

  void _stopRealtimeRetry() {
    _driverRealtimeRetryTimer?.cancel();
    _driverRealtimeRetryTimer = null;
  }

  void _stopIncomingReconciliation() {
    _incomingReconciliationTimer?.cancel();
    _incomingReconciliationTimer = null;
  }

  void _dispose() {
    _disposed = true;
    _cancelRealtime();
    _releaseRunningOrderRealtime();
    _stopDegradedRefresh();
    _stopIncomingReconciliation();
  }
}

class DriverAvailabilityState {
  final String status;
  final bool isUpdating;
  final bool hasSyncIssue;
  final String? syncIssueMessage;

  const DriverAvailabilityState({
    required this.status,
    this.isUpdating = false,
    this.hasSyncIssue = false,
    this.syncIssueMessage,
  });

  bool get isOnline =>
      status == 'available' || status == 'online' || status == 'busy';

  DriverAvailabilityState copyWith({
    String? status,
    bool? isUpdating,
    bool? hasSyncIssue,
    String? syncIssueMessage,
    bool clearSyncIssueMessage = false,
  }) {
    return DriverAvailabilityState(
      status: status ?? this.status,
      isUpdating: isUpdating ?? this.isUpdating,
      hasSyncIssue: hasSyncIssue ?? this.hasSyncIssue,
      syncIssueMessage: clearSyncIssueMessage
          ? null
          : (syncIssueMessage ?? this.syncIssueMessage),
    );
  }
}

class DriverAvailabilityNotifier
    extends AsyncNotifier<DriverAvailabilityState> {
  @override
  Future<DriverAvailabilityState> build() async {
    try {
      final status = await ref
          .read(driverOrderRepositoryProvider)
          .fetchAvailabilityStatus();
      return DriverAvailabilityState(status: _normalizeStatus(status));
    } on DriverOrderApiException catch (error) {
      return DriverAvailabilityState(
        status: _fallbackStatusFromSession(),
        hasSyncIssue: true,
        syncIssueMessage: error.message,
      );
    } catch (_) {
      return DriverAvailabilityState(
        status: _fallbackStatusFromSession(),
        hasSyncIssue: true,
        syncIssueMessage: 'Gagal sinkronkan status kerja driver.',
      );
    }
  }

  Future<String?> setOnline(bool value) async {
    final current =
        state.asData?.value ??
        DriverAvailabilityState(status: _fallbackStatusFromSession());

    if (current.isUpdating) {
      return null;
    }

    state = AsyncData(
      current.copyWith(
        isUpdating: true,
        hasSyncIssue: false,
        clearSyncIssueMessage: true,
      ),
    );

    try {
      final status = await ref
          .read(driverOrderRepositoryProvider)
          .updateAvailability(isOnline: value);

      await ref.read(authSessionProvider.notifier).refreshSession();

      state = AsyncData(
        DriverAvailabilityState(
          status: _normalizeStatus(status),
          isUpdating: false,
          hasSyncIssue: false,
          syncIssueMessage: null,
        ),
      );
      ref.invalidate(driverOrdersProvider);

      return null;
    } on DriverOrderApiException catch (error) {
      state = AsyncData(
        current.copyWith(
          isUpdating: false,
          hasSyncIssue: true,
          syncIssueMessage: error.message,
        ),
      );
      return error.message;
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isUpdating: false,
          hasSyncIssue: true,
          syncIssueMessage: 'Gagal memperbarui status kerja driver.',
        ),
      );
      return error.toString();
    }
  }

  String _fallbackStatusFromSession() {
    final profile = ref.read(authSessionProvider).profile;
    final rawStatus = profile?.driverProfile?.status ?? 'offline';
    return _normalizeStatus(rawStatus);
  }

  String _normalizeStatus(String rawStatus) {
    final normalized = rawStatus.trim().toLowerCase();
    if (normalized == 'available' ||
        normalized == 'busy' ||
        normalized == 'offline') {
      return normalized;
    }

    if (normalized == 'online') {
      return 'available';
    }

    return 'offline';
  }
}

final driverOrdersProvider =
    AsyncNotifierProvider<DriverOrdersNotifier, DriverOrdersState>(
      DriverOrdersNotifier.new,
    );

final driverOrderDetailProvider =
    FutureProvider.family<DriverOrderModel, String>((ref, orderId) async {
      return ref.read(driverOrderRepositoryProvider).fetchOrderDetail(orderId);
    });

final driverOrderDetailRealtimeProvider = Provider.autoDispose
    .family<void, String>((ref, orderId) {
      final parsedOrderId = int.tryParse(orderId.trim());
      final session = ref.watch(authSessionProvider);
      if (parsedOrderId == null ||
          parsedOrderId <= 0 ||
          !session.isAuthenticated ||
          session.role != SessionUserRole.driver ||
          session.profile == null) {
        return;
      }

      final hub = ref.watch(orderRealtimeHubProvider);
      unawaited(hub.retainOrder(parsedOrderId));

      final subscription = hub.events
          .where((event) => event.orderId == parsedOrderId)
          .listen((event) {
            if (event.type == OrderRealtimeEventType.content ||
                event.type == OrderRealtimeEventType.status) {
              final delay = event.type == OrderRealtimeEventType.content
                  ? const Duration(milliseconds: 400)
                  : Duration.zero;
              Timer(delay, () {
                if (ref.mounted) {
                  ref.invalidate(driverOrderDetailProvider(orderId));
                }
              });
            }
          });

      ref.onDispose(() {
        unawaited(subscription.cancel());
        hub.releaseOrder(parsedOrderId);
      });
    });

final driverOrderTransferProofReconciliationProvider = Provider.autoDispose
    .family<void, String>((ref, orderId) {
      final detailState = ref.watch(driverOrderDetailProvider(orderId));
      final order = detailState.asData?.value;
      if (order == null || !_needsTransferProofReconciliation(order)) {
        return;
      }

      final timer = Timer.periodic(driverTransferProofReconciliationInterval, (
        _,
      ) {
        if (ref.mounted) {
          ref.invalidate(driverOrderDetailProvider(orderId));
        }
      });

      ref.onDispose(timer.cancel);
    });

bool _needsTransferProofReconciliation(DriverOrderModel order) {
  final paymentMethod = order.paymentMethod.trim().toUpperCase();
  if (paymentMethod != 'TRANSFER' || isPaymentPaid(order.paymentStatus)) {
    return false;
  }

  return !order.proofs.any(
    (proof) =>
        proof.type == 'payment_transfer' &&
        (proof.photoUrl ?? '').trim().isNotEmpty,
  );
}

class DriverHistoryNotifier
    extends AsyncNotifier<List<DriverHistoryOrderModel>> {
  bool _disposed = false;
  bool _silentRefreshInFlight = false;

  bool get _isMounted => !_disposed && ref.mounted;

  @override
  Future<List<DriverHistoryOrderModel>> build() async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);

    final session = ref.watch(authSessionProvider);
    if (!_isEligibleSession(session)) {
      return const <DriverHistoryOrderModel>[];
    }

    return ref.read(driverOrderRepositoryProvider).fetchHistory();
  }

  Future<void> refresh({bool showLoading = true}) async {
    if (!_isMounted) {
      return;
    }

    final session = ref.read(authSessionProvider);
    if (!_isEligibleSession(session)) {
      state = const AsyncData(<DriverHistoryOrderModel>[]);
      return;
    }

    if (!showLoading && _silentRefreshInFlight) {
      return;
    }

    if (showLoading) {
      state = const AsyncLoading<List<DriverHistoryOrderModel>>();
    }

    try {
      if (!showLoading) {
        _silentRefreshInFlight = true;
      }

      final history = await ref
          .read(driverOrderRepositoryProvider)
          .fetchHistory();
      if (_isMounted) {
        state = AsyncData(history);
      }
    } catch (error, stackTrace) {
      if (!showLoading && state.asData != null) {
        return;
      }

      if (_isMounted) {
        state = AsyncError(error, stackTrace);
      }
    } finally {
      if (!showLoading) {
        _silentRefreshInFlight = false;
      }
    }
  }

  bool _isEligibleSession(AuthSessionState session) {
    return session.isAuthenticated &&
        session.role == SessionUserRole.driver &&
        session.profile != null;
  }
}

final driverHistoryProvider =
    AsyncNotifierProvider<DriverHistoryNotifier, List<DriverHistoryOrderModel>>(
      DriverHistoryNotifier.new,
    );

final driverActiveOrderProvider = Provider<DriverOrderModel?>((ref) {
  final state = ref.watch(driverOrdersProvider);
  return state.maybeWhen(
    data: (value) => value.running.isEmpty ? null : value.running.first,
    orElse: () => null,
  );
});

final driverIncomingOrderCountProvider = Provider<int>((ref) {
  final state = ref.watch(driverOrdersProvider);
  return state.maybeWhen(
    data: (value) => value.incoming.length,
    orElse: () => 0,
  );
});

final driverAvailabilityProvider =
    AsyncNotifierProvider<DriverAvailabilityNotifier, DriverAvailabilityState>(
      DriverAvailabilityNotifier.new,
    );
