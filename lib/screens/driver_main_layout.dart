import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../providers/auth_session_provider.dart';
import '../providers/driver_location_tracking_provider.dart';
import '../providers/driver_order_providers.dart';

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
        context.go(AppRoutes.driverOrders);
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
    final ordersState = isActiveDriver ? ref.watch(driverOrdersProvider) : null;
    final activeOrder = ordersState?.maybeWhen(
      data: (value) => value.running.isEmpty ? null : value.running.first,
      orElse: () => null,
    );
    final incomingOrderCount = isActiveDriver
        ? ref.watch(driverIncomingOrderCountProvider)
        : 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(driverLocationTrackingProvider.notifier)
          .syncForOrder(
            orderId: activeOrder?.id,
            statusCode: activeOrder?.statusCode,
          );
    });

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: isActiveDriver
          ? BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: AppColors.white,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textSecondary,
              currentIndex: _calculateSelectedIndex(context),
              onTap: (index) => _onItemTapped(index, context),
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_filled),
                  label: 'Beranda',
                ),
                BottomNavigationBarItem(
                  icon: _NavIconWithBadge(
                    icon: Icons.assignment_rounded,
                    count: incomingOrderCount,
                  ),
                  label: 'Orderan',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'Riwayat',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ],
            )
          : null,
    );
  }
}

class _NavIconWithBadge extends StatelessWidget {
  const _NavIconWithBadge({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Icon(icon);
    }

    final label = count > 99 ? '99+' : count.toString();

    return SizedBox(
      width: 32,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(alignment: Alignment.center, child: Icon(icon)),
          Positioned(
            top: -2,
            right: 0,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.white, width: 1.5),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
