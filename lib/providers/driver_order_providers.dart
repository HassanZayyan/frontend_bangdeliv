import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/driver_order_model.dart';
import '../services/driver_order_service.dart';

final driverOrderServiceProvider = Provider<DriverOrderService>((ref) {
  return DriverOrderService();
});

class DriverOrdersState {
  final List<DriverOrderModel> incoming;
  final List<DriverOrderModel> running;
  final Set<String> processingOrderIds;
  final bool isMockData;

  const DriverOrdersState({
    required this.incoming,
    required this.running,
    this.processingOrderIds = const <String>{},
    this.isMockData = false,
  });

  DriverOrdersState copyWith({
    List<DriverOrderModel>? incoming,
    List<DriverOrderModel>? running,
    Set<String>? processingOrderIds,
    bool? isMockData,
  }) {
    return DriverOrdersState(
      incoming: incoming ?? this.incoming,
      running: running ?? this.running,
      processingOrderIds: processingOrderIds ?? this.processingOrderIds,
      isMockData: isMockData ?? this.isMockData,
    );
  }

  bool isProcessing(String orderId) => processingOrderIds.contains(orderId);
}

class DriverOrdersNotifier extends AsyncNotifier<DriverOrdersState> {
  @override
  Future<DriverOrdersState> build() async {
    final payload = await ref.read(driverOrderServiceProvider).fetchOrders();

    return DriverOrdersState(
      incoming: payload.incoming,
      running: payload.running,
      processingOrderIds: const <String>{},
      isMockData: payload.isMockData,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final payload = await ref.read(driverOrderServiceProvider).fetchOrders();
      return DriverOrdersState(
        incoming: payload.incoming,
        running: payload.running,
        processingOrderIds: const <String>{},
        isMockData: payload.isMockData,
      );
    });
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
    final selected = incoming.removeAt(index).copyWith(
      acceptedAt: _currentHourMinute(),
    );
    final running = <DriverOrderModel>[selected, ...current.running];

    if (current.isMockData) {
      state = AsyncData(
        current.copyWith(
          incoming: incoming,
          running: running,
        ),
      );
      return null;
    }

    final processingOrderIds = <String>{
      ...current.processingOrderIds,
      id,
    };

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
        syncedOrder = await ref.read(driverOrderServiceProvider).fetchOrderDetail(
          id,
        );
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

    if (current.isMockData) {
      state = AsyncData(current.copyWith(incoming: incoming));
      return null;
    }

    final processingOrderIds = <String>{
      ...current.processingOrderIds,
      id,
    };

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

    final processingOrderIds = <String>{
      ...current.processingOrderIds,
      orderId,
    };

    state = AsyncData(current.copyWith(processingOrderIds: processingOrderIds));

    try {
      final updated = await ref.read(driverOrderServiceProvider).transitionStatus(
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

    final processingOrderIds = <String>{
      ...current.processingOrderIds,
      orderId,
    };

    state = AsyncData(current.copyWith(processingOrderIds: processingOrderIds));

    try {
      await ref.read(driverOrderServiceProvider).collectCod(
        orderId: orderId,
        amount: amount,
        note: note,
      );

      final refreshed = await ref.read(driverOrderServiceProvider).fetchOrderDetail(
        orderId,
      );

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
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
  return ref.read(driverOrderServiceProvider).fetchHistory();
});

final driverActiveOrderProvider = Provider<DriverOrderModel?>((ref) {
  final state = ref.watch(driverOrdersProvider);
  return state.maybeWhen(
    data: (value) => value.running.isEmpty ? null : value.running.first,
    orElse: () => null,
  );
});
