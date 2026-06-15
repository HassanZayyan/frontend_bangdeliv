import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend_bangdeliv/config/app_routes.dart';
import 'package:frontend_bangdeliv/core/di/app_providers.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/screens/driver_history_screen.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/screens/driver_order_history_detail_screen.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';
import 'package:frontend_bangdeliv/services/driver_order_service.dart';
import 'package:frontend_bangdeliv/utils/order_status.dart';

void main() {
  testWidgets('driver history card opens history detail route', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.driverHistory,
      routes: [
        GoRoute(
          path: AppRoutes.driverHistory,
          builder: (context, state) => const DriverHistoryScreen(),
        ),
        GoRoute(
          path: AppRoutes.driverHistoryDetail,
          builder: (context, state) => Scaffold(
            body: Text('history-detail:${state.pathParameters['orderId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            () => _FakeAuthSessionNotifier(_driverSession()),
          ),
          driverOrderServiceProvider.overrideWithValue(
            _FakeDriverHistoryService(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('BDR-HIST-42'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('driver-history-order-42')));
    await tester.pumpAndSettle();

    expect(find.text('history-detail:42'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/driver/history/42',
    );
  });

  testWidgets('driver history detail is read only', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverOrderServiceProvider.overrideWithValue(
            _FakeDriverHistoryService(),
          ),
        ],
        child: const MaterialApp(
          home: DriverOrderHistoryDetailScreen(orderId: '42'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Detail Pesanan'), findsOneWidget);
    expect(find.text('Order ID: BDR-HIST-42'), findsOneWidget);
    expect(find.text('Jemput'), findsOneWidget);
    expect(find.text('Tujuan'), findsOneWidget);
    expect(find.text('Jarak'), findsOneWidget);
    expect(
      find.text('Koordinat map belum tersedia untuk order ini.'),
      findsNothing,
    );
    await tester.scrollUntilVisible(
      find.text('Riwayat Status'),
      280,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Riwayat Status'), findsOneWidget);
    expect(find.text('Aksi Driver'), findsNothing);
    expect(find.textContaining('Upload'), findsNothing);
  });

  testWidgets('driver history detail back returns to history screen', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.driverHistoryDetailPath(42),
      routes: [
        GoRoute(
          path: AppRoutes.driverHistory,
          builder: (context, state) => const DriverHistoryScreen(),
        ),
        GoRoute(
          path: AppRoutes.driverHistoryDetail,
          builder: (context, state) => DriverOrderHistoryDetailScreen(
            orderId: state.pathParameters['orderId'] ?? '',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            () => _FakeAuthSessionNotifier(_driverSession()),
          ),
          driverOrderServiceProvider.overrideWithValue(
            _FakeDriverHistoryService(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Detail Pesanan'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Riwayat Driver'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.driverHistory,
    );
  });
}

class _FakeDriverHistoryService extends DriverOrderService {
  @override
  Future<List<DriverHistoryOrderModel>> fetchHistory() async {
    return [
      DriverHistoryOrderModel(
        id: 'BDR-HIST-42',
        orderId: 42,
        orderNumber: 'BDR-HIST-42',
        customerName: 'Mhn Zayyan',
        date: DateTime.now().toUtc(),
        fee: 9000,
        status: 'Selesai',
      ),
    ];
  }

  @override
  Future<DriverOrderModel> fetchOrderDetail(String orderId) async {
    return DriverOrderModel(
      id: orderId,
      orderNumber: 'BDR-HIST-42',
      customerName: 'Mhn Zayyan',
      pickupAddress: 'baskoro raya, Bejalen',
      dropoffAddress: 'Erha Skin Setiabudi',
      etaMinutes: 0,
      fee: 9000,
      deliveryDistanceText: '2.27 km',
      totalPrice: 9000,
      itemCount: 1,
      statusCode: OrderStatusCodes.completed,
      statusDisplayName: 'Selesai',
      paymentMethod: 'TRANSFER',
      paymentStatus: 'paid',
      statusTimeline: [
        DriverOrderTimelineItemModel(
          statusCode: OrderStatusCodes.completed,
          statusDisplayName: 'Selesai',
          eventType: 'STATUS_CHANGE',
          note: null,
          createdAt: DateTime.now().toUtc(),
        ),
      ],
    );
  }
}

class _FakeAuthSessionNotifier extends AuthSessionNotifier {
  _FakeAuthSessionNotifier(this._initialState);

  final AuthSessionState _initialState;

  @override
  AuthSessionState build() => _initialState;
}

AuthSessionState _driverSession() {
  return AuthSessionState.fromProfile(
    UserProfileModel(
      id: 77,
      name: 'Driver 77',
      phone: '0823477',
      email: 'driver77@example.com',
      avatar: null,
      avatarUrl: null,
      role: 'driver',
      driverProfile: const DriverProfileModel(
        registrationStatus: 'active',
        status: 'available',
        vehicleType: 'Motor Matic',
        vehicleBrand: 'Honda',
        vehicleModel: 'Beat',
        vehiclePlate: 'H 1234 DL',
        licenseNumber: 'SIM-DRIVER-001',
        totalDeliveries: 12,
      ),
      stats: const UserStatsModel(totalOrders: 0, totalPaid: 0),
      addresses: const <SavedAddressModel>[],
    ),
  );
}
