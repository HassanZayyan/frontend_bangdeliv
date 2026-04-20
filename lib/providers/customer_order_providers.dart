import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer_order_model.dart';
import 'api_providers.dart';

final customerOrdersProvider = FutureProvider<List<CustomerOrderSummaryModel>>((
  ref,
) async {
  final service = ref.watch(customerOrderApiServiceProvider);
  return service.fetchOrders(page: 1, perPage: 50);
});

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
