import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_provider.dart';
import 'driver_order_providers.dart';
import '../../orders/application/order_chat_unread_provider.dart';

class DriverRealtimeBootstrapState {
  const DriverRealtimeBootstrapState({
    required this.active,
    required this.retainedUnreadOrderIds,
  });

  final bool active;
  final Set<int> retainedUnreadOrderIds;
}

final driverRealtimeBootstrapProvider = Provider<DriverRealtimeBootstrapState>((
  ref,
) {
  final session = ref.watch(authSessionProvider);
  final isActiveDriver =
      session.isAuthenticated &&
      session.role == SessionUserRole.driver &&
      session.driverAccessState == DriverAccessState.active &&
      session.profile != null;

  if (!isActiveDriver) {
    return const DriverRealtimeBootstrapState(
      active: false,
      retainedUnreadOrderIds: <int>{},
    );
  }

  final orders = ref.watch(driverOrdersProvider);
  final runningOrderIds = orders.maybeWhen(
    data: (value) {
      return value.running
          .where((order) => !value.processingOrderIds.contains(order.id))
          .map((order) => int.tryParse(order.id.trim()))
          .whereType<int>()
          .where((orderId) => orderId > 0)
          .toSet();
    },
    orElse: () => <int>{},
  );

  for (final orderId in runningOrderIds) {
    ref.watch(orderChatUnreadCountProvider(orderId));
  }

  return DriverRealtimeBootstrapState(
    active: true,
    retainedUnreadOrderIds: runningOrderIds,
  );
});
