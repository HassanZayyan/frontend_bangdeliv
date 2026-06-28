import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_colors.dart';
import '../../../auth/application/auth_session_provider.dart';
import '../../../auth/presentation/widgets/guest_login_prompt.dart';
import '../widgets/bang_floating_bottom_nav_bar.dart';

const SystemUiOverlayStyle _mainLayoutSystemUiOverlayStyle =
    SystemUiOverlayStyle(
      statusBarColor: AppColors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    );

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout>
    with WidgetsBindingObserver {
  DateTime? _lastBackPressedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (mounted) {
      setState(() {});
    }
  }

  bool _isKeyboardVisible(BuildContext context) {
    return View.of(context).viewInsets.bottom > 0;
  }

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
    final session = ref.read(authSessionProvider);

    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        if (isGuestSession(session)) {
          showGuestLoginPrompt(
            context,
            title: 'Masuk untuk melihat aktivitas',
            message:
                'Aktivitas berisi pesanan, status perjalanan, dan riwayat transaksi akun Anda.',
            returnTo: AppRoutes.activity,
          );
          return;
        }
        context.go(AppRoutes.activity);
        break;
      case 2:
        if (isGuestSession(session)) {
          showGuestLoginPrompt(
            context,
            title: 'Masuk untuk membuka profil',
            message:
                'Profil, alamat tersimpan, dan pengaturan akun hanya tersedia setelah masuk.',
            returnTo: AppRoutes.profile,
          );
          return;
        }
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
    final hideNavigationBar = _isKeyboardVisible(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _mainLayoutSystemUiOverlayStyle,
      child: PopScope<void>(
        canPop: canPopRoute,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            return;
          }

          _handleSystemBack(location);
        },
        child: BangFloatingBottomNavOverlayTheme(
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: BangFloatingBottomNavHost(
              hideNavigationBar: hideNavigationBar,
              navigationBar: BangFloatingBottomNavBar(
                currentIndex: _calculateSelectedIndex(context),
                onTap: (index) => _onItemTapped(index, context),
                items: const [
                  BangFloatingNavItem(
                    icon: Icons.home_filled,
                    label: 'Beranda',
                  ),
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
        ),
      ),
    );
  }
}
