import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/driver_order_model.dart';
import '../services/driver_order_service.dart';
import '../utils/order_formatters.dart';
import '../utils/order_status.dart';
import 'auth_session_provider.dart';

final driverOrderServiceProvider = Provider<DriverOrderService>((ref) {
  return DriverOrderService();
});

class DriverOrdersState {
  final List<DriverOrderModel> incoming;
  final List<DriverOrderModel> running;
  final Set<String> processingOrderIds;

  const DriverOrdersState({
    required this.incoming,
    required this.running,
    this.processingOrderIds = const <String>{},
  });

  DriverOrdersState copyWith({
    List<DriverOrderModel>? incoming,
    List<DriverOrderModel>? running,
    Set<String>? processingOrderIds,
  }) {
    return DriverOrdersState(
      incoming: incoming ?? this.incoming,
      running: running ?? this.running,
      processingOrderIds: processingOrderIds ?? this.processingOrderIds,
    );
  }

  bool isProcessing(String orderId) => processingOrderIds.contains(orderId);
}

class DriverOrdersNotifier extends AsyncNotifier<DriverOrdersState> {
  @override
  Future<DriverOrdersState> build() async {
    final session = ref.watch(authSessionProvider);
    if (!session.isAuthenticated ||
        session.role != SessionUserRole.driver ||
        session.profile == null) {
      return const DriverOrdersState(
        incoming: <DriverOrderModel>[],
        running: <DriverOrderModel>[],
      );
    }

    final payload = await ref.read(driverOrderServiceProvider).fetchOrders();

    return DriverOrdersState(
      incoming: payload.incoming,
      running: payload.running,
      processingOrderIds: const <String>{},
    );
  }

  Future<void> refresh() async {
    final session = ref.read(authSessionProvider);
    if (!session.isAuthenticated ||
        session.role != SessionUserRole.driver ||
        session.profile == null) {
      state = const AsyncData(
        DriverOrdersState(
          incoming: <DriverOrderModel>[],
          running: <DriverOrderModel>[],
        ),
      );
      return;
    }

    try {
      final payload = await ref.read(driverOrderServiceProvider).fetchOrders();
      state = AsyncData(
        DriverOrdersState(
          incoming: payload.incoming,
          running: payload.running,
          processingOrderIds: const <String>{},
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<String?> acceptOrder(String id) async {
    final current = state.asData?.value;
    if (current == null) {
      return 'Data order belum siap.';
    }

    if (current.isProcessing(id)) {
      return null;
    }

    final index = current.incoming.indexWhere((order) => order.id == id);
    if (index < 0) {
      return 'Order tidak ditemukan.';
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

    final processingOrderIds = <String>{...current.processingOrderIds, id};

    state = AsyncData(
      current.copyWith(
        incoming: incoming,
        running: running,
        processingOrderIds: processingOrderIds,
      ),
    );

    try {
      await ref.read(driverOrderServiceProvider).acceptOrder(id);
      DriverOrderModel? syncedOrder;
      try {
        syncedOrder = await ref
            .read(driverOrderServiceProvider)
            .fetchOrderDetail(id);
      } catch (_) {
        syncedOrder = null;
      }

      final latest = state.asData?.value;
      if (latest == null) {
        return null;
      }

      final cleanedProcessingIds = <String>{...latest.processingOrderIds}
        ..remove(id);
      final syncedRunning = syncedOrder == null
          ? latest.running
          : _upsertRunningOrder(latest.running, syncedOrder);
      state = AsyncData(
        latest.copyWith(
          running: syncedRunning,
          processingOrderIds: cleanedProcessingIds,
        ),
      );

      ref.invalidate(driverOrderDetailProvider(id));
      ref.invalidate(driverAvailabilityProvider);

      return null;
    } catch (error) {
      final rollbackProcessingIds = <String>{...current.processingOrderIds}
        ..remove(id);
      state = AsyncData(
        current.copyWith(processingOrderIds: rollbackProcessingIds),
      );
      return error.toString();
    }
  }

  Future<String?> rejectOrder(String id) async {
    final current = state.asData?.value;
    if (current == null) {
      return 'Data order belum siap.';
    }

    if (current.isProcessing(id)) {
      return null;
    }

    final incoming = current.incoming
        .where((order) => order.id != id)
        .toList(growable: false);

    if (incoming.length == current.incoming.length) {
      return 'Order tidak ditemukan.';
    }

    final processingOrderIds = <String>{...current.processingOrderIds, id};

    state = AsyncData(
      current.copyWith(
        incoming: incoming,
        processingOrderIds: processingOrderIds,
      ),
    );

    try {
      await ref.read(driverOrderServiceProvider).rejectOrder(id);

      final latest = state.asData?.value;
      if (latest == null) {
        return null;
      }

      final cleanedProcessingIds = <String>{...latest.processingOrderIds}
        ..remove(id);
      state = AsyncData(
        latest.copyWith(processingOrderIds: cleanedProcessingIds),
      );
      ref.invalidate(driverAvailabilityProvider);

      return null;
    } catch (error) {
      final rollbackProcessingIds = <String>{...current.processingOrderIds}
        ..remove(id);
      state = AsyncData(
        current.copyWith(processingOrderIds: rollbackProcessingIds),
      );
      return error.toString();
    }
  }

  Future<String?> transitionOrderStatus({
    required String orderId,
    required String actionCode,
    String? targetStatusCode,
    String? note,
    double? latitude,
    double? longitude,
  }) async {
    final current = state.asData?.value;
    if (current == null) {
      return 'Data order belum siap.';
    }

    if (current.isProcessing(orderId)) {
      return null;
    }

    final processingOrderIds = <String>{...current.processingOrderIds, orderId};

    state = AsyncData(current.copyWith(processingOrderIds: processingOrderIds));

    try {
      final updated = await ref
          .read(driverOrderServiceProvider)
          .transitionStatus(
            orderId: orderId,
            actionCode: actionCode,
            targetStatusCode: targetStatusCode,
            note: note,
            latitude: latitude,
            longitude: longitude,
          );

      final latest = state.asData?.value;
      if (latest == null) {
        return null;
      }

      final cleanedProcessingIds = <String>{...latest.processingOrderIds}
        ..remove(orderId);
      final syncedRunning = _isTerminalStatus(updated.statusCode)
          ? _removeRunningOrder(latest.running, orderId)
          : _upsertRunningOrder(latest.running, updated);

      state = AsyncData(
        latest.copyWith(
          running: syncedRunning,
          processingOrderIds: cleanedProcessingIds,
        ),
      );

      ref.invalidate(driverOrderDetailProvider(orderId));
      ref.invalidate(driverAvailabilityProvider);
      return null;
    } catch (error) {
      final latest = state.asData?.value;
      if (latest == null) {
        return error.toString();
      }

      final rollbackProcessingIds = <String>{...latest.processingOrderIds}
        ..remove(orderId);
      state = AsyncData(
        latest.copyWith(processingOrderIds: rollbackProcessingIds),
      );
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
      return null;
    }

    final processingOrderIds = <String>{...current.processingOrderIds, orderId};

    state = AsyncData(current.copyWith(processingOrderIds: processingOrderIds));

    try {
      await ref
          .read(driverOrderServiceProvider)
          .collectCod(orderId: orderId, amount: amount, note: note);

      final refreshed = await ref
          .read(driverOrderServiceProvider)
          .fetchOrderDetail(orderId);

      final latest = state.asData?.value;
      if (latest == null) {
        return null;
      }

      final cleanedProcessingIds = <String>{...latest.processingOrderIds}
        ..remove(orderId);
      state = AsyncData(
        latest.copyWith(
          running: _upsertRunningOrder(latest.running, refreshed),
          processingOrderIds: cleanedProcessingIds,
        ),
      );

      ref.invalidate(driverOrderDetailProvider(orderId));
      return null;
    } catch (error) {
      final latest = state.asData?.value;
      if (latest == null) {
        return error.toString();
      }

      final rollbackProcessingIds = <String>{...latest.processingOrderIds}
        ..remove(orderId);
      state = AsyncData(
        latest.copyWith(processingOrderIds: rollbackProcessingIds),
      );
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

  bool _isTerminalStatus(String code) {
    final normalized = code.toUpperCase();
    return normalized == 'COMPLETED' ||
        normalized == 'CANCELLED' ||
        normalized == 'CANCELLED_WITH_FEE';
  }

  String _currentHourMinute() {
    return currentWibHourMinute();
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
          .read(driverOrderServiceProvider)
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
          .read(driverOrderServiceProvider)
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
      return ref.read(driverOrderServiceProvider).fetchOrderDetail(orderId);
    });

final driverHistoryProvider = FutureProvider<List<DriverHistoryOrderModel>>((
  ref,
) async {
  final session = ref.watch(authSessionProvider);
  if (!session.isAuthenticated ||
      session.role != SessionUserRole.driver ||
      session.profile == null) {
    return const <DriverHistoryOrderModel>[];
  }

  return ref.read(driverOrderServiceProvider).fetchHistory();
});

final driverActiveOrderProvider = Provider<DriverOrderModel?>((ref) {
  final state = ref.watch(driverOrdersProvider);
  return state.maybeWhen(
    data: (value) => value.running.isEmpty ? null : value.running.first,
    orElse: () => null,
  );
});

final driverAvailabilityProvider =
    AsyncNotifierProvider<DriverAvailabilityNotifier, DriverAvailabilityState>(
      DriverAvailabilityNotifier.new,
    );
