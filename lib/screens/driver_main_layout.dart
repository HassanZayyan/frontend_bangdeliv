import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
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
    final activeOrder = ref.watch(driverActiveOrderProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(driverLocationTrackingProvider.notifier).syncForOrder(
            orderId: activeOrder?.id,
            statusCode: activeOrder?.statusCode,
          );
    });

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_rounded),
            label: 'Orderan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
