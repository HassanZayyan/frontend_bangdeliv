import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_colors.dart';
import '../widgets/bang_floating_bottom_nav_bar.dart';

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  DateTime? _lastBackPressedAt;

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith(AppRoutes.home)) return 0;
    if (location.startsWith(AppRoutes.nearbyMerchants)) return 0;
    if (location.startsWith(AppRoutes.activity)) return 1;
    if (location.startsWith(AppRoutes.history)) return 1;
    if (location.startsWith(AppRoutes.profile)) return 2;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.activity);
        break;
      case 2:
        context.go(AppRoutes.profile);
        break;
    }
  }

  bool _shouldReturnToHome(String location) {
    return location == AppRoutes.nearbyMerchants;
  }

  Future<void> _handleSystemBack(String location) async {
    if (_shouldReturnToHome(location)) {
      context.go(AppRoutes.home);
      _lastBackPressedAt = null;
      return;
    }

    final now = DateTime.now();
    final hasRecentBackPress =
        _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) <= const Duration(seconds: 2);

    if (hasRecentBackPress) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tekan sekali lagi untuk keluar aplikasi'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final canPopRoute =
        GoRouter.of(context).canPop() && !_shouldReturnToHome(location);

    return PopScope<void>(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _handleSystemBack(location);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: BangFloatingBottomNavHost(
          navigationBar: BangFloatingBottomNavBar(
            currentIndex: _calculateSelectedIndex(context),
            onTap: (index) => _onItemTapped(index, context),
            items: const [
              BangFloatingNavItem(icon: Icons.home_filled, label: 'Beranda'),
              BangFloatingNavItem(
                icon: Icons.assignment_rounded,
                label: 'Aktivitas',
              ),
              BangFloatingNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profil',
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
