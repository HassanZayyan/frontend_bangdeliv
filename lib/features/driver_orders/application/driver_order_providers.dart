import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/application/app_lifecycle_provider.dart';
import '../../../models/driver_order_model.dart';
import '../../../data/repositories/driver_order_repository.dart';
import '../../../services/customer_order_api_service.dart';
import '../../../services/driver_order_service.dart';
import '../../../services/firebase_notification_service.dart';
import '../../../utils/order_formatters.dart';
import '../../../utils/order_status.dart';
import '../../../core/di/app_providers.dart';
import '../../auth/application/auth_session_provider.dart';
import '../../realtime/application/order_realtime_hub_provider.dart';

Duration driverOrdersReconciliationInterval = const Duration(seconds: 8);
Duration driverOrderDetailReconciliationInterval = const Duration(seconds: 5);

typedef DriverOrderDetailRefresh = Future<DriverOrderModel> Function();

typedef DriverOrderAvailableNotification =
    Future<void> Function({
      required int orderId,
      required String title,
      required String body,
      required String orderNumber,
      required String serviceTypeCode,
    });

final driverOrderAvailableNotificationProvider =
    Provider<DriverOrderAvailableNotification>((ref) {
      return ({
        required int orderId,
        required String title,
        required String body,
        required String orderNumber,
        required String serviceTypeCode,
      }) {
        return FirebaseNotificationService.showLocalDriverOrderAvailableNotification(
          orderId: orderId,
          title: title,
          body: body,
          orderNumber: orderNumber,
          serviceTypeCode: serviceTypeCode,
        );
      };
    });

final driverActiveOrderSnackBarMessageProvider =
    NotifierProvider<DriverActiveOrderSnackBarMessageNotifier, String?>(
      DriverActiveOrderSnackBarMessageNotifier.new,
    );

class DriverActiveOrderSnackBarMessageNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String message) {
    state = message;
  }

  void clear() {
    state = null;
  }
}

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

  static String bypassQris(String orderId) => _build(orderId, 'bypassQris');

  static String rejectQris(String orderId) => _build(orderId, 'rejectQris');

  static String updateFee(String orderId) => _build(orderId, 'updateFee');

  static String acceptDeliveryFeeCounter(String orderId) {
    return _build(orderId, 'acceptDeliveryFeeCounter');
  }

  static String bypassDeliveryFee(String orderId) {
    return _build(orderId, 'bypassDeliveryFee');
  }

  static String uploadProof(String orderId, String proofType) {
    return _build(orderId, 'uploadProof:${_normalize(proofType)}');
  }

  static String shoppingCheckout(String orderId) {
    return _build(orderId, 'shoppingCheckout');
  }

  static String shoppingPriceQuote(String orderId, [int? pickupLocationId]) {
    final suffix = pickupLocationId != null && pickupLocationId > 0
        ? ':$pickupLocationId'
        : '';
    return _build(orderId, 'shoppingPriceQuote$suffix');
  }

  static String bypassShoppingPrice(String orderId, [int? pickupLocationId]) {
    final suffix = pickupLocationId != null && pickupLocationId > 0
        ? ':$pickupLocationId'
        : '';
    return _build(orderId, 'bypassShoppingPrice$suffix');
  }

  static String bypassUnavailableItems(
    String orderId, [
    int? pickupLocationId,
  ]) {
    final suffix = pickupLocationId != null && pickupLocationId > 0
        ? ':$pickupLocationId'
        : '';
    return _build(orderId, 'bypassUnavailableItems$suffix');
  }

  static String decideUnavailableItems(
    String orderId,
    int pickupLocationId,
    String action,
  ) {
    return _build(
      orderId,
      'decideUnavailableItems:$pickupLocationId:${_normalize(action)}',
    );
  }

  static String replaceUnavailableItems(
    String orderId, [
    int? pickupLocationId,
  ]) {
    final suffix = pickupLocationId != null && pickupLocationId > 0
        ? ':$pickupLocationId'
        : '';
    return _build(orderId, 'replaceUnavailableItems$suffix');
  }

  static String markShoppingMerchantOpen(
    String orderId, [
    int? pickupLocationId,
  ]) {
    final suffix = pickupLocationId != null && pickupLocationId > 0
        ? ':$pickupLocationId'
        : '';
    return _build(orderId, 'markShoppingMerchantOpen$suffix');
  }

  static String respondMerchantReplacementApproval(
    String orderId,
    int pickupLocationId,
    String action,
  ) {
    return _build(
      orderId,
      'merchantReplacementApproval:$pickupLocationId:$action',
    );
  }

  static String updateShoppingItems(String orderId, [int? pickupLocationId]) {
    final suffix = pickupLocationId != null && pickupLocationId > 0
        ? ':$pickupLocationId'
        : '';
    return _build(orderId, 'updateShoppingItems$suffix');
  }

  static String respondShoppingItemChange(String orderId, String action) {
    return _build(orderId, 'respondShoppingItemChange:${_normalize(action)}');
  }

  static String pickupFailed(String orderId, [int? pickupLocationId]) {
    final suffix = pickupLocationId != null && pickupLocationId > 0
        ? ':$pickupLocationId'
        : '';
    return _build(orderId, 'pickupFailed$suffix');
  }

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
  const DriverOrderAcceptResult({
    this.order,
    this.error,
    this.statusCode,
    this.isStaleOrder = false,
  });

  final DriverOrderModel? order;
  final String? error;
  final int? statusCode;
  final bool isStaleOrder;

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
  Future<DriverOrdersState?>? _pendingReadyState;

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

    final readyCompleter = Completer<DriverOrdersState?>();
    final pendingReadyState = readyCompleter.future;
    _pendingReadyState = pendingReadyState;
    try {
      final payload = await ref
          .read(driverOrderRepositoryProvider)
          .fetchOrders();
      _syncRealtimeSubscription(session);
      _startIncomingReconciliation();

      final next = DriverOrdersState(
        incoming: payload.incoming,
        running: payload.running,
        processingActionKeys: const <String>{},
      );
      _syncRunningOrderRealtime(next);
      readyCompleter.complete(next);
      return next;
    } catch (_) {
      readyCompleter.complete(null);
      rethrow;
    } finally {
      if (identical(_pendingReadyState, pendingReadyState)) {
        _pendingReadyState = null;
      }
    }
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
    Completer<DriverOrdersState?>? readyCompleter;
    Future<DriverOrdersState?>? pendingReadyState;

    if (showLoading) {
      readyCompleter = Completer<DriverOrdersState?>();
      pendingReadyState = readyCompleter.future;
      _pendingReadyState = pendingReadyState;
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
      readyCompleter?.complete(next);
    } catch (error, stackTrace) {
      if (!_isMounted) {
        return;
      }

      if (!showLoading && state.asData != null) {
        return;
      }

      state = AsyncError(error, stackTrace);
      readyCompleter?.complete(previous);
    } finally {
      if (readyCompleter != null && !readyCompleter.isCompleted) {
        readyCompleter.complete(previous);
      }
      if (identical(_pendingReadyState, pendingReadyState)) {
        _pendingReadyState = null;
      }
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

    final rawOrderId = order.id.trim();
    if (rawOrderId.isEmpty) {
      return;
    }

    final current = state.asData?.value;
    var shouldNotify = true;

    if (current != null) {
      if (current.suppressedIncomingOrderIds.contains(order.id)) {
        return;
      }

      if (current.running.any((item) => item.id == order.id)) {
        return;
      }

      shouldNotify = !current.incoming.any((item) => item.id == order.id);
      state = AsyncData(
        current.copyWith(
          incoming: _upsertIncomingOrder(current.incoming, order),
        ),
      );
    }
    _markRealtimeHealthy();

    if (shouldNotify) {
      final orderId = int.tryParse(rawOrderId);
      if (orderId == null || orderId <= 0) {
        return;
      }

      unawaited(
        ref.read(driverOrderAvailableNotificationProvider)(
          orderId: orderId,
          title: 'Order masuk',
          body: _incomingOrderNotificationBody(order),
          orderNumber: order.orderNumber,
          serviceTypeCode: order.serviceTypeCode,
        ),
      );
    }
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

  String _incomingOrderNotificationBody(DriverOrderModel order) {
    final serviceName = (order.serviceTypeName ?? '').trim();
    final feeText = formatCurrency(order.fee);
    if (serviceName.isNotEmpty) {
      return '$serviceName baru tersedia. Estimasi ongkir $feeText.';
    }

    return 'Order baru tersedia. Estimasi ongkir $feeText.';
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
      if (!isAppLifecycleResumed(ref.read(appLifecycleStateProvider))) {
        return;
      }
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

        if (!isAppLifecycleResumed(ref.read(appLifecycleStateProvider))) {
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

    state = AsyncData(_markActionProcessing(current, actionKey: actionKey));

    try {
      final syncedOrder = await ref
          .read(driverOrderRepositoryProvider)
          .acceptOrder(id);

      final latest = state.asData?.value;
      if (latest == null) {
        return DriverOrderAcceptResult(order: syncedOrder);
      }

      final incoming = latest.incoming
          .where((order) => order.id != id)
          .toList(growable: false);
      final syncedRunning = _upsertRunningOrder(latest.running, syncedOrder);
      state = AsyncData(
        _clearActionProcessing(
          latest.copyWith(incoming: incoming, running: syncedRunning),
          actionKey: actionKey,
        ),
      );
      _syncRunningOrderRealtime(state.asData!.value);

      ref.invalidate(driverOrderDetailProvider(id));
      ref.invalidate(driverAvailabilityProvider);

      return DriverOrderAcceptResult(order: syncedOrder);
    } on DriverOrderApiException catch (error) {
      final latest = state.asData?.value ?? current;
      final isStaleOrder = _isStaleAcceptFailure(error);
      final incoming = isStaleOrder
          ? latest.incoming
                .where((order) => order.id != id)
                .toList(growable: false)
          : latest.incoming;
      final suppressedIncomingOrderIds = isStaleOrder
          ? <String>{...latest.suppressedIncomingOrderIds, id}
          : latest.suppressedIncomingOrderIds;

      state = AsyncData(
        _clearActionProcessing(
          latest.copyWith(
            incoming: incoming,
            suppressedIncomingOrderIds: suppressedIncomingOrderIds,
          ),
          actionKey: actionKey,
        ),
      );
      _syncRunningOrderRealtime(state.asData!.value);
      return DriverOrderAcceptResult(
        error: error.message,
        statusCode: error.statusCode,
        isStaleOrder: isStaleOrder,
      );
    } catch (error) {
      final latest = state.asData?.value ?? current;
      state = AsyncData(_clearActionProcessing(latest, actionKey: actionKey));
      _syncRunningOrderRealtime(state.asData!.value);
      return DriverOrderAcceptResult(error: error.toString());
    }
  }

  bool _isStaleAcceptFailure(DriverOrderApiException error) {
    if (error.statusCode != 409 && error.statusCode != 404) {
      return false;
    }

    final message = error.message.toLowerCase();
    return message.contains('sudah diambil') ||
        message.contains('tidak dapat diterima pada status') ||
        message.contains('sudah ditolak') ||
        message.contains('tidak ditemukan');
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
    double? cancellationPenaltyBaseDeliveryFee,
  }) async {
    // Daftar order berjalan boleh belum termuat: transisi hanya butuh orderId.
    final current = state.asData?.value;

    if (current != null && current.isProcessing(orderId)) {
      return 'Aksi order sebelumnya masih diproses. Tunggu sebentar.';
    }

    final actionKey = DriverOrderActionKeys.transition(orderId, actionCode);

    if (current != null) {
      state = AsyncData(_markActionProcessing(current, actionKey: actionKey));
    }

    try {
      final updated = await ref
          .read(driverOrderRepositoryProvider)
          .transitionStatus(
            orderId: orderId,
            actionCode: actionCode,
            targetStatusCode: targetStatusCode,
            note: note,
            cancellationPenaltyBaseDeliveryFee:
                cancellationPenaltyBaseDeliveryFee,
          );

      final latest = state.asData?.value;
      if (latest == null) {
        ref.invalidate(driverOrderDetailProvider(orderId));
        ref.invalidate(driverAvailabilityProvider);
        return null;
      }

      final isDriverRunning = isDriverRunningOrder(
        statusCode: updated.statusCode,
        paymentStatus: updated.paymentStatus,
      );
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

  Future<String?> bypassRejectedTransferPayment({
    required String orderId,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.bypassQris(orderId),
      request: (service) =>
          service.bypassRejectedTransferPayment(orderId: orderId),
    );
  }

  Future<String?> rejectTransferPayment({
    required String orderId,
    required String reason,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.rejectQris(orderId),
      request: (service) =>
          service.rejectTransferPayment(orderId: orderId, reason: reason),
    );
  }

  Future<String?> updateDeliveryFeeOverride({
    required String orderId,
    required double amount,
    required String reason,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.updateFee(orderId),
      request: (service) => service.updateDeliveryFeeOverride(
        orderId: orderId,
        amount: amount,
        reason: reason,
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

  Future<String?> bypassDeliveryFeeOverride({
    required String orderId,
    String? note,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.bypassDeliveryFee(orderId),
      request: (repository) =>
          repository.bypassDeliveryFeeOverride(orderId: orderId, note: note),
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
    XFile? receiptPhoto,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.shoppingCheckout(orderId),
      request: (service) => service.updateShoppingCheckout(
        orderId: orderId,
        items: items,
        receiptPhoto: receiptPhoto,
      ),
    );
  }

  Future<String?> submitShoppingPriceQuote({
    required String orderId,
    required double amount,
    int? pickupLocationId,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.shoppingPriceQuote(
        orderId,
        pickupLocationId,
      ),
      request: (repository) => repository.submitShoppingPriceQuote(
        orderId: orderId,
        amount: amount,
        pickupLocationId: pickupLocationId,
      ),
    );
  }

  Future<String?> bypassShoppingPriceQuote({
    required String orderId,
    required int pickupLocationId,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.bypassShoppingPrice(
        orderId,
        pickupLocationId,
      ),
      request: (repository) => repository.bypassShoppingPriceQuote(
        orderId: orderId,
        pickupLocationId: pickupLocationId,
      ),
    );
  }

  Future<String?> bypassUnavailableShoppingItems({
    required String orderId,
    required int pickupLocationId,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.bypassUnavailableItems(
        orderId,
        pickupLocationId,
      ),
      request: (repository) => repository.bypassUnavailableShoppingItems(
        orderId: orderId,
        pickupLocationId: pickupLocationId,
      ),
    );
  }

  Future<String?> decideUnavailableShoppingItems({
    required String orderId,
    required int pickupLocationId,
    required String action,
    List<int> itemIds = const <int>[],
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.decideUnavailableItems(
        orderId,
        pickupLocationId,
        action,
      ),
      request: (repository) => repository.decideUnavailableShoppingItems(
        orderId: orderId,
        pickupLocationId: pickupLocationId,
        action: action,
        itemIds: itemIds,
      ),
    );
  }

  Future<String?> replaceUnavailableShoppingItems({
    required String orderId,
    required int pickupLocationId,
    required String idempotencyKey,
    required List<ShoppingItemDraftPayload> items,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.replaceUnavailableItems(
        orderId,
        pickupLocationId,
      ),
      request: (repository) => repository.replaceUnavailableShoppingItems(
        orderId: orderId,
        pickupLocationId: pickupLocationId,
        idempotencyKey: idempotencyKey,
        items: items,
      ),
    );
  }

  Future<String?> approveShoppingMerchantReplacement({
    required String orderId,
    required int pickupLocationId,
    required int approvalEventId,
    required String idempotencyKey,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.respondMerchantReplacementApproval(
        orderId,
        pickupLocationId,
        'approve',
      ),
      request: (repository) => repository.approveShoppingMerchantReplacement(
        orderId: orderId,
        pickupLocationId: pickupLocationId,
        approvalEventId: approvalEventId,
        idempotencyKey: idempotencyKey,
      ),
    );
  }

  Future<String?> rejectShoppingMerchantReplacement({
    required String orderId,
    required int pickupLocationId,
    required int approvalEventId,
    String? reason,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.respondMerchantReplacementApproval(
        orderId,
        pickupLocationId,
        'reject',
      ),
      request: (repository) => repository.rejectShoppingMerchantReplacement(
        orderId: orderId,
        pickupLocationId: pickupLocationId,
        approvalEventId: approvalEventId,
        reason: reason,
      ),
    );
  }

  Future<String?> markShoppingMerchantOpen({
    required String orderId,
    required int pickupLocationId,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.markShoppingMerchantOpen(
        orderId,
        pickupLocationId,
      ),
      request: (repository) => repository.markShoppingMerchantOpen(
        orderId: orderId,
        pickupLocationId: pickupLocationId,
      ),
    );
  }

  Future<String?> respondShoppingItemChange({
    required String orderId,
    required String action,
    String? note,
  }) async {
    return _mutateRunningOrder(
      orderId: orderId,
      actionKey: DriverOrderActionKeys.respondShoppingItemChange(
        orderId,
        action,
      ),
      request: (repository) => repository.respondShoppingItemChange(
        orderId: orderId,
        action: action,
        note: note,
      ),
    );
  }

  Future<String?> _mutateRunningOrder({
    required String orderId,
    required String actionKey,
    required Future<DriverOrderModel> Function(DriverOrderRepository repository)
    request,
  }) async {
    // Daftar order berjalan boleh belum termuat: aksi hanya butuh orderId,
    // jadi jangan gagalkan permintaan. Bookkeeping flag lokal saja yang dilewati.
    final current = state.asData?.value;

    if (current != null && current.isProcessing(orderId)) {
      return 'Aksi order sebelumnya masih diproses. Tunggu sebentar.';
    }

    if (current != null) {
      state = AsyncData(_markActionProcessing(current, actionKey: actionKey));
    }

    try {
      final updated = await request(ref.read(driverOrderRepositoryProvider));

      final latest = state.asData?.value;
      if (latest == null) {
        ref.invalidate(driverOrderDetailProvider(orderId));
        return null;
      }

      final isDriverRunning = isDriverRunningOrder(
        statusCode: updated.statusCode,
        paymentStatus: updated.paymentStatus,
      );
      final syncedRunning = isDriverRunning
          ? _upsertRunningOrder(latest.running, updated)
          : _removeRunningOrder(latest.running, orderId);

      state = AsyncData(
        _clearActionProcessing(
          latest.copyWith(running: syncedRunning),
          actionKey: actionKey,
        ),
      );
      _syncRunningOrderRealtime(state.asData!.value);

      ref.invalidate(driverOrderDetailProvider(orderId));
      if (!isDriverRunning && isTerminalOrderStatus(updated.statusCode)) {
        ref.invalidate(driverAvailabilityProvider);
        unawaited(
          ref.read(driverHistoryProvider.notifier).refresh(showLoading: false),
        );
        _refreshAvailabilityThenSyncRealtime();
      }
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
    int? pickupLocationId,
  }) async {
    final current = state.asData?.value;
    if (current == null) {
      return 'Data order belum siap.';
    }

    if (current.isProcessing(orderId)) {
      return null;
    }

    final actionKey = DriverOrderActionKeys.updateShoppingItems(
      orderId,
      pickupLocationId,
    );
    state = AsyncData(_markActionProcessing(current, actionKey: actionKey));

    try {
      final updated = await ref
          .read(driverOrderRepositoryProvider)
          .updateShoppingItems(
            orderId: orderId,
            items: items,
            pickupLocationId: pickupLocationId,
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
    final current = await _waitForReadyOrdersState();
    if (current == null) {
      return 'Data order belum siap.';
    }

    if (current.isProcessing(orderId)) {
      return null;
    }

    final actionKey = DriverOrderActionKeys.pickupFailed(
      orderId,
      pickupLocationId,
    );
    state = AsyncData(_markActionProcessing(current, actionKey: actionKey));

    try {
      final updated = await ref
          .read(driverOrderRepositoryProvider)
          .recordShoppingPickupFailed(
            orderId: orderId,
            pickupLocationId: pickupLocationId,
            reason: reason,
            merchantClosedPhoto: storeClosedPhoto,
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

  Future<DriverOrdersState?> _waitForReadyOrdersState() async {
    final current = state.asData?.value;
    if (current != null) {
      return current;
    }

    final pendingReadyState = _pendingReadyState;
    if (pendingReadyState == null) {
      return null;
    }

    final ready = await pendingReadyState;
    return _isMounted ? ready : null;
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

final driverOrderDetailRefreshProvider = Provider.autoDispose
    .family<DriverOrderDetailRefresh, String>((ref, orderId) {
      Future<DriverOrderModel>? inFlight;

      Future<DriverOrderModel> refresh() async {
        final pending = inFlight;
        if (pending != null) {
          return pending;
        }

        ref.invalidate(driverOrderDetailProvider(orderId));
        final request = ref.read(driverOrderDetailProvider(orderId).future);
        inFlight = request;
        try {
          return await request;
        } finally {
          if (identical(inFlight, request)) {
            inFlight = null;
          }
        }
      }

      return refresh;
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
      final refresh = ref.watch(driverOrderDetailRefreshProvider(orderId));
      Timer? pendingRefresh;
      unawaited(hub.retainOrder(parsedOrderId));

      final subscription = hub.events
          .where((event) => event.orderId == parsedOrderId)
          .listen((event) {
            if (event.type == OrderRealtimeEventType.connected ||
                event.type == OrderRealtimeEventType.content ||
                event.type == OrderRealtimeEventType.status) {
              final delay = event.type == OrderRealtimeEventType.content
                  ? const Duration(milliseconds: 400)
                  : Duration.zero;
              pendingRefresh?.cancel();
              pendingRefresh = Timer(delay, () {
                if (ref.mounted) {
                  unawaited(_refreshDriverOrderDetailSilently(refresh));
                }
              });
            }
          });

      ref.onDispose(() {
        pendingRefresh?.cancel();
        unawaited(subscription.cancel());
        hub.releaseOrder(parsedOrderId);
      });
    });

final driverOrderDetailReconciliationProvider = Provider.autoDispose
    .family<void, String>((ref, orderId) {
      final parsedOrderId = int.tryParse(orderId.trim());
      if (parsedOrderId == null || parsedOrderId <= 0) {
        return;
      }

      final refresh = ref.watch(driverOrderDetailRefreshProvider(orderId));
      Timer? timer;

      bool canRefresh() {
        if (!ref.mounted ||
            !isAppLifecycleResumed(ref.read(appLifecycleStateProvider))) {
          return false;
        }

        final order = ref
            .read(driverOrderDetailProvider(orderId))
            .asData
            ?.value;
        if (order != null && isTerminalOrderStatus(order.statusCode)) {
          timer?.cancel();
          timer = null;
          return false;
        }

        return true;
      }

      void reconcile() {
        if (canRefresh()) {
          unawaited(_refreshDriverOrderDetailSilently(refresh));
        }
      }

      void startTimer() {
        if (timer != null ||
            !isAppLifecycleResumed(ref.read(appLifecycleStateProvider))) {
          return;
        }
        timer = Timer.periodic(driverOrderDetailReconciliationInterval, (_) {
          reconcile();
        });
      }

      void stopTimer() {
        timer?.cancel();
        timer = null;
      }

      ref.listen(appLifecycleStateProvider, (previous, next) {
        if (isAppLifecycleResumed(next)) {
          startTimer();
          if (previous != next) {
            reconcile();
          }
        } else {
          stopTimer();
        }
      });

      startTimer();
      ref.onDispose(stopTimer);
    });

Future<void> _refreshDriverOrderDetailSilently(
  DriverOrderDetailRefresh refresh,
) async {
  try {
    await refresh();
  } catch (_) {
    // Pertahankan snapshot terakhir. Realtime/polling berikutnya akan mencoba lagi.
  }
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
