import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/config/app_colors.dart';
import 'package:frontend_bangdeliv/config/app_routes.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/driver_orders/application/driver_location_reporter_provider.dart';
import 'package:frontend_bangdeliv/features/driver_orders/application/driver_order_providers.dart';
import 'package:frontend_bangdeliv/features/navigation/presentation/screens/driver_main_layout.dart';
import 'package:frontend_bangdeliv/features/navigation/presentation/screens/main_layout.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('customer shell resets system bars to the light app style', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainLayout(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const _ShellBody('home'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(_hasLightSystemUiRegion(tester), isTrue);
  });

  testWidgets('driver shell resets system bars to the light app style', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DriverMainLayout(child: _ShellBody('driver'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(_hasLightSystemUiRegion(tester), isTrue);
  });

  testWidgets('driver active order hides the shell bottom navigation', (
    tester,
  ) async {
    var activeRouteBuilds = 0;
    final router = GoRouter(
      initialLocation: AppRoutes.driverOrderActivePath('42'),
      routes: [
        ShellRoute(
          builder: (context, state, child) => DriverMainLayout(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.driverHome,
              builder: (context, state) => const _ShellBody('driver home'),
            ),
            GoRoute(
              path: AppRoutes.driverOrders,
              builder: (context, state) => const _ShellBody('driver orders'),
            ),
            GoRoute(
              path: AppRoutes.driverOrderActive,
              builder: (context, state) {
                activeRouteBuilds++;
                return const _ShellBody('driver active order');
              },
            ),
            GoRoute(
              path: AppRoutes.driverHistory,
              builder: (context, state) => const _ShellBody('driver history'),
            ),
            GoRoute(
              path: AppRoutes.driverProfile,
              builder: (context, state) => const _ShellBody('driver profile'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(_ActiveDriverAuthSession.new),
          driverActiveOrderProvider.overrideWith((ref) => _driverOrder('42')),
          driverIncomingOrderCountProvider.overrideWith((ref) => 0),
          driverLocationReporterProvider.overrideWith(
            _IdleDriverLocationReporter.new,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('driver active order'), findsOneWidget);
    expect(find.text('Orderan'), findsNothing);
    expect(activeRouteBuilds, 1);
  });
}

bool _hasLightSystemUiRegion(WidgetTester tester) {
  final regions = tester.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
    find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
  );

  return regions.any((region) {
    final style = region.value;
    return style.statusBarColor == AppColors.white &&
        style.statusBarIconBrightness == Brightness.dark &&
        style.statusBarBrightness == Brightness.light &&
        style.systemNavigationBarColor == AppColors.white &&
        style.systemNavigationBarIconBrightness == Brightness.dark;
  });
}

class _ShellBody extends StatelessWidget {
  const _ShellBody(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}

class _ActiveDriverAuthSession extends AuthSessionNotifier {
  @override
  AuthSessionState build() {
    return const AuthSessionState(
      initialized: true,
      isAuthenticated: true,
      role: SessionUserRole.driver,
      driverAccessState: DriverAccessState.active,
      profile: null,
    );
  }
}

class _IdleDriverLocationReporter extends DriverLocationReporterNotifier {
  @override
  DriverLocationReporterState build() {
    return const DriverLocationReporterState();
  }
}

DriverOrderModel _driverOrder(String id) {
  return DriverOrderModel(
    id: id,
    customerName: 'Customer $id',
    pickupAddress: 'Pickup',
    dropoffAddress: 'Dropoff',
    etaMinutes: 8,
    fee: 9000,
    itemCount: 1,
    statusCode: 'DRIVER_ASSIGNED',
  );
}
