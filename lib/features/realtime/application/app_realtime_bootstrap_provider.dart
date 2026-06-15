import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_provider.dart';
import '../../driver_orders/application/driver_realtime_bootstrap_provider.dart';

class AppRealtimeBootstrapState {
  const AppRealtimeBootstrapState({
    required this.driverBootstrapActive,
    required this.retainedDriverUnreadOrderIds,
  });

  final bool driverBootstrapActive;
  final Set<int> retainedDriverUnreadOrderIds;
}

final appRealtimeBootstrapProvider = Provider<AppRealtimeBootstrapState>((ref) {
  final session = ref.watch(authSessionProvider);
  final isActiveDriver =
      session.isAuthenticated &&
      session.role == SessionUserRole.driver &&
      session.driverAccessState == DriverAccessState.active &&
      session.profile != null;

  if (!isActiveDriver) {
    return const AppRealtimeBootstrapState(
      driverBootstrapActive: false,
      retainedDriverUnreadOrderIds: <int>{},
    );
  }

  final driverBootstrap = ref.watch(driverRealtimeBootstrapProvider);
  return AppRealtimeBootstrapState(
    driverBootstrapActive: driverBootstrap.active,
    retainedDriverUnreadOrderIds: driverBootstrap.retainedUnreadOrderIds,
  );
});
