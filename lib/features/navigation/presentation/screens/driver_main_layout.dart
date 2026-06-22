import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../auth/application/auth_session_provider.dart';
import '../../../driver_orders/application/driver_location_reporter_provider.dart';
import '../../../driver_orders/application/driver_order_providers.dart';
import '../widgets/bang_floating_bottom_nav_bar.dart';

class DriverMainLayout extends ConsumerStatefulWidget {
  final Widget child;

  const DriverMainLayout({super.key, required this.child});

  @override
  ConsumerState<DriverMainLayout> createState() => _DriverMainLayoutState();
}

class _DriverMainLayoutState extends ConsumerState<DriverMainLayout> {
  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    if (location.startsWith(AppRoutes.driverHome)) {
      return 0;
    }
    if (location.startsWith(AppRoutes.driverOrders)) {
      return 1;
    }
    if (location.startsWith(AppRoutes.driverHistory)) {
      return 2;
    }
    if (location.startsWith(AppRoutes.driverProfile)) {
      return 3;
    }

    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRoutes.driverHome);
        break;
      case 1:
        final activeOrder = ref.read(driverActiveOrderProvider);
        if (activeOrder == null) {
          context.go(AppRoutes.driverOrders);
        } else {
          context.go(AppRoutes.driverOrderActivePath(activeOrder.id));
        }
        break;
      case 2:
        context.go(AppRoutes.driverHistory);
        break;
      case 3:
        context.go(AppRoutes.driverProfile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final isActiveDriver =
        session.driverAccessState == DriverAccessState.active;
    if (isActiveDriver) {
      ref.watch(driverLocationReporterProvider);
    }
    final incomingOrderCount = isActiveDriver
        ? ref.watch(driverIncomingOrderCountProvider)
        : 0;

    final scaffold = Scaffold(
      backgroundColor: AppColors.background,
      body: isActiveDriver
          ? BangFloatingBottomNavHost(
              navigationBar: BangFloatingBottomNavBar(
                currentIndex: _calculateSelectedIndex(context),
                onTap: (index) => _onItemTapped(index, context),
                items: [
                  const BangFloatingNavItem(
                    icon: Icons.home_filled,
                    label: 'Beranda',
                  ),
                  BangFloatingNavItem(
                    icon: Icons.assignment_rounded,
                    label: 'Orderan',
                    badgeCount: incomingOrderCount,
                  ),
                  const BangFloatingNavItem(
                    icon: Icons.history,
                    label: 'Riwayat',
                  ),
                  const BangFloatingNavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Profil',
                  ),
                ],
              ),
              child: widget.child,
            )
          : widget.child,
    );

    return isActiveDriver
        ? BangFloatingBottomNavOverlayTheme(child: scaffold)
        : scaffold;
  }
}
