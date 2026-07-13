import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/config/app_routes.dart';
import 'package:frontend_bangdeliv/core/di/app_providers.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/driver_orders/application/driver_location_reporter_provider.dart';
import 'package:frontend_bangdeliv/features/driver_orders/application/driver_order_providers.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/screens/driver_active_order_screen.dart';
import 'package:frontend_bangdeliv/features/orders/presentation/screens/order_chat_screen.dart';
import 'package:frontend_bangdeliv/features/profile/presentation/screens/notification_settings_screen.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/models/order_chat_model.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';
import 'package:frontend_bangdeliv/services/api_client.dart';
import 'package:frontend_bangdeliv/services/order_chat_api_service.dart';
import 'package:frontend_bangdeliv/widgets/order_chat_badge_icon.dart';
import 'package:go_router/go_router.dart';

import '../fakes/fake_order_realtime_client.dart';

void main() {
  group('driver active order back navigation', () {
    testWidgets('direct route back button falls back to driver home', (
      tester,
    ) async {
      final router = await _pumpNavigationApp(
        tester,
        initialLocation: AppRoutes.driverOrderActivePath('42'),
        session: _driverSession,
      );
      addTearDown(router.dispose);

      expect(find.byTooltip('Kembali'), findsOneWidget);

      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();

      expect(find.text('driver home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pushed route back button pops to previous screen', (
      tester,
    ) async {
      final router = await _pumpNavigationApp(
        tester,
        initialLocation: _sourceRoute,
        session: _driverSession,
      );
      addTearDown(router.dispose);

      await tester.tap(find.byKey(_openActiveOrderKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();

      expect(find.text('source screen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('direct route system back falls back to driver home', (
      tester,
    ) async {
      final router = await _pumpNavigationApp(
        tester,
        initialLocation: AppRoutes.driverOrderActivePath('42'),
        session: _driverSession,
      );
      addTearDown(router.dispose);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('driver home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('invalid order state system back still reaches driver home', (
      tester,
    ) async {
      final router = await _pumpNavigationApp(
        tester,
        initialLocation: AppRoutes.driverOrderActivePath('invalid'),
        session: _driverSession,
      );
      addTearDown(router.dispose);

      expect(
        find.text('Order ID tidak valid untuk data server.'),
        findsOneWidget,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('driver home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('system back from active order chat returns to active order', (
      tester,
    ) async {
      final router = await _pumpNavigationApp(
        tester,
        initialLocation: AppRoutes.driverOrderActivePath('42'),
        session: _driverSessionWithProfile(),
      );
      addTearDown(router.dispose);

      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.driverOrderActivePath('42'),
      );

      final chatButton = find.ancestor(
        of: find.byType(OrderChatBadgeIcon),
        matching: find.byType(IconButton),
      );
      final chatIconButton = tester
          .widgetList<IconButton>(chatButton)
          .singleWhere((button) => button.onPressed != null);
      chatIconButton.onPressed!();
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Halo driver', findRichText: true),
        findsOneWidget,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byTooltip('Hubungi customer'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.driverOrderActivePath('42'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('direct driver chat system back falls back to active order', (
      tester,
    ) async {
      final router = await _pumpNavigationApp(
        tester,
        initialLocation: AppRoutes.orderChatPath(42),
        session: _driverSessionWithProfile(),
      );
      addTearDown(router.dispose);

      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.orderChatPath(42),
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byTooltip('Hubungi customer'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.driverOrderActivePath('42'),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('notification settings back navigation', () {
    testWidgets('direct customer route falls back to customer profile', (
      tester,
    ) async {
      final router = await _pumpNavigationApp(
        tester,
        initialLocation: AppRoutes.notificationSettings,
        session: _customerSession,
      );
      addTearDown(router.dispose);

      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();

      expect(find.text('customer profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('direct driver system back falls back to driver profile', (
      tester,
    ) async {
      final router = await _pumpNavigationApp(
        tester,
        initialLocation: AppRoutes.notificationSettings,
        session: _driverSession,
      );
      addTearDown(router.dispose);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('driver profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('direct admin route falls back to customer profile route', (
      tester,
    ) async {
      final router = await _pumpNavigationApp(
        tester,
        initialLocation: AppRoutes.notificationSettings,
        session: _adminSession,
      );
      addTearDown(router.dispose);

      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();

      expect(find.text('customer profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pushed route back button pops to previous screen', (
      tester,
    ) async {
      final router = await _pumpNavigationApp(
        tester,
        initialLocation: _sourceRoute,
        session: _driverSession,
      );
      addTearDown(router.dispose);

      await tester.tap(find.byKey(_openNotificationSettingsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();

      expect(find.text('source screen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<GoRouter> _pumpNavigationApp(
  WidgetTester tester, {
  required String initialLocation,
  required AuthSessionState session,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.driverHome,
        builder: (context, state) => const _RouteMarker('driver home'),
      ),
      GoRoute(
        path: AppRoutes.driverProfile,
        builder: (context, state) => const _RouteMarker('driver profile'),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const _RouteMarker('customer profile'),
      ),
      GoRoute(
        path: AppRoutes.notificationSettings,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.driverOrderActive,
        builder: (context, state) => DriverActiveOrderScreen(
          orderId: state.pathParameters['orderId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.orderChat,
        builder: (context, state) {
          final orderId = int.tryParse(state.pathParameters['orderId'] ?? '');
          final extra = state.extra;
          final routeArgs = extra is OrderChatRouteArgs ? extra : null;

          return OrderChatScreen(
            orderId: orderId ?? 0,
            returnPath: routeArgs?.returnPath,
          );
        },
      ),
      GoRoute(
        path: _sourceRoute,
        builder: (context, state) => const _SourceScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          () => _TestAuthSessionNotifier(session),
        ),
        driverOrderDetailProvider.overrideWith(
          (ref, orderId) async => _driverOrder(orderId),
        ),
        driverLocationReporterProvider.overrideWith(
          _IdleDriverLocationReporter.new,
        ),
        orderChatApiServiceProvider.overrideWithValue(
          _FakeOrderChatApiService(),
        ),
        orderRealtimeClientProvider.overrideWithValue(
          FakeOrderRealtimeClient(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

const _sourceRoute = '/source';
const _openActiveOrderKey = ValueKey('open-active-order');
const _openNotificationSettingsKey = ValueKey('open-notification-settings');

const _driverSession = AuthSessionState(
  initialized: true,
  isAuthenticated: true,
  role: SessionUserRole.driver,
  driverAccessState: DriverAccessState.active,
  profile: null,
);

const _customerSession = AuthSessionState(
  initialized: true,
  isAuthenticated: true,
  role: SessionUserRole.customer,
  driverAccessState: DriverAccessState.none,
  profile: null,
);

const _adminSession = AuthSessionState(
  initialized: true,
  isAuthenticated: true,
  role: SessionUserRole.admin,
  driverAccessState: DriverAccessState.none,
  profile: null,
);

AuthSessionState _driverSessionWithProfile() {
  return AuthSessionState.fromProfile(
    UserProfileModel(
      id: 77,
      name: 'Driver Test',
      phone: '081277771111',
      email: 'driver.test@example.com',
      avatar: null,
      avatarUrl: null,
      role: 'driver',
      driverProfile: const DriverProfileModel(
        registrationStatus: 'active',
        status: 'available',
        vehicleType: 'motor',
        vehicleBrand: 'Honda',
        vehicleModel: 'Beat',
        vehiclePlate: 'H 1234 QA',
        totalDeliveries: 0,
      ),
      stats: const UserStatsModel(totalOrders: 0, totalPaid: 0),
      addresses: const <SavedAddressModel>[],
    ),
  );
}

class _TestAuthSessionNotifier extends AuthSessionNotifier {
  _TestAuthSessionNotifier(this.initialState);

  final AuthSessionState initialState;

  @override
  AuthSessionState build() => initialState;
}

class _IdleDriverLocationReporter extends DriverLocationReporterNotifier {
  @override
  DriverLocationReporterState build() {
    return const DriverLocationReporterState();
  }
}

class _RouteMarker extends StatelessWidget {
  const _RouteMarker(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}

class _SourceScreen extends StatelessWidget {
  const _SourceScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('source screen'),
          FilledButton(
            key: _openActiveOrderKey,
            onPressed: () =>
                context.push(AppRoutes.driverOrderActivePath(_testOrder.id)),
            child: const Text('open active order'),
          ),
          FilledButton(
            key: _openNotificationSettingsKey,
            onPressed: () => context.push(AppRoutes.notificationSettings),
            child: const Text('open notification settings'),
          ),
        ],
      ),
    );
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

final _testOrder = _driverOrder('42');

class _FakeOrderChatApiService extends OrderChatApiService {
  _FakeOrderChatApiService() : super(ApiClient());

  @override
  Future<OrderChatMessagesPage> fetchMessages({
    required int orderId,
    int limit = 50,
    int? beforeId,
    int? afterId,
  }) async {
    return OrderChatMessagesPage(
      messages: <OrderChatMessageModel>[
        OrderChatMessageModel(
          id: 1,
          orderId: orderId,
          senderUserId: 88,
          senderRole: 'customer',
          senderName: 'Customer $orderId',
          body: 'Halo driver',
          clientMessageId: null,
          createdAt: DateTime.utc(2026),
        ),
      ],
      canSend: true,
      hasMore: false,
      nextBeforeId: null,
      unreadCount: 0,
      lastReadMessageId: 0,
    );
  }

  @override
  Future<OrderChatUnreadSummary> fetchUnread({required int orderId}) async {
    return const OrderChatUnreadSummary(unreadCount: 0, lastReadMessageId: 0);
  }

  @override
  Future<OrderChatUnreadSummary> markRead({
    required int orderId,
    required int messageId,
  }) async {
    return OrderChatUnreadSummary(unreadCount: 0, lastReadMessageId: messageId);
  }
}
