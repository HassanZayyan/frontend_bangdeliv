import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend_bangdeliv/config/app_colors.dart';
import 'package:frontend_bangdeliv/config/app_routes.dart';
import 'package:frontend_bangdeliv/core/di/app_providers.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/driver_orders/application/driver_location_reporter_provider.dart';
import 'package:frontend_bangdeliv/features/driver_orders/application/driver_order_providers.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/screens/driver_history_screen.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/screens/driver_order_history_detail_screen.dart';
import 'package:frontend_bangdeliv/features/navigation/presentation/screens/driver_main_layout.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';
import 'package:frontend_bangdeliv/services/driver_order_service.dart';
import 'package:frontend_bangdeliv/utils/order_formatters.dart';
import 'package:frontend_bangdeliv/utils/order_status.dart';

final _driverHistoryDate = DateTime.now().toUtc();

void main() {
  testWidgets('driver history card opens history detail route', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.driverHistory,
      routes: [
        ShellRoute(
          builder: (context, state, child) => DriverMainLayout(child: child),
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
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            () => _FakeAuthSessionNotifier(_driverSession()),
          ),
          driverOrderServiceProvider.overrideWithValue(
            _FakeDriverHistoryService(),
          ),
          driverIncomingOrderCountProvider.overrideWith((ref) => 0),
          driverLocationReporterProvider.overrideWith(
            _IdleDriverLocationReporter.new,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('BDR-HIST-42'), findsOneWidget);
    expect(find.text('Pendapatan Bersih'), findsOneWidget);
    expect(find.text('Rp 13.500'), findsAtLeastNWidgets(1));
    expect(find.text(formatDateMonthTime(_driverHistoryDate)), findsOneWidget);
    expect(find.text('Bruto Rp 15.000 - Admin 10% Rp 1.500'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(find.text('Riwayat'), findsOneWidget);

    final orderNumberText = tester.widget<Text>(find.text('BDR-HIST-42'));
    expect(orderNumberText.style?.fontSize, 11.5);

    final statusText = tester.widget<Text>(find.text('Selesai'));
    expect(statusText.style?.color, AppColors.success);
    expect(statusText.style?.fontSize, 12.5);

    await tester.tap(find.text('BDR-HIST-42'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Pesanan'), findsOneWidget);
    expect(find.text('Riwayat'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Riwayat Driver'), findsOneWidget);
    expect(find.text('Riwayat'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.driverHistory,
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
    expect(find.text('Pendapatan bruto'), findsOneWidget);
    expect(find.text('Pendapatan bersih'), findsOneWidget);
    expect(find.text('Biaya admin 10%'), findsOneWidget);
    expect(find.text('Total pembayaran customer'), findsOneWidget);
    expect(find.text('Item Belanja'), findsOneWidget);
    expect(find.text('Bukti Foto'), findsOneWidget);
    expect(
      find.text('Koordinat map belum tersedia untuk order ini.'),
      findsNothing,
    );
    expect(find.byIcon(Icons.shopping_bag_outlined), findsNothing);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);

    final itemTitle = tester.widget<Text>(find.text('Item Belanja'));
    expect(itemTitle.style?.fontSize, 16);
    expect(itemTitle.style?.fontWeight, FontWeight.w800);

    final shoppingItemText = tester.widget<Text>(find.text('ramen mala'));
    expect(shoppingItemText.style?.fontSize, 14);
    expect(shoppingItemText.style?.fontWeight, FontWeight.w700);
    expect(find.text('  ramen mala'), findsNothing);

    final proofTitle = tester.widget<Text>(find.text('Bukti Foto'));
    expect(proofTitle.style?.fontSize, 16);
    expect(proofTitle.style?.fontWeight, FontWeight.w800);

    final detailList = tester.widget<ListView>(find.byType(ListView));
    final detailPadding = detailList.padding as EdgeInsets;
    expect(detailPadding.bottom, 24);

    await tester.scrollUntilVisible(
      find.text('Riwayat Status'),
      280,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Riwayat Status'), findsOneWidget);
    expect(find.text('Aksi Driver'), findsNothing);
    expect(find.textContaining('Upload'), findsNothing);
  });

  testWidgets('driver history detail hides shopping item prices', (
    tester,
  ) async {
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

    expect(find.text('Item Belanja'), findsOneWidget);
    expect(find.text('ramen mala'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('less ice'), findsOneWidget);
    expect(find.text('1 x Rp 12.000'), findsNothing);
    expect(find.text('Rp 12.000'), findsNothing);
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
        date: _driverHistoryDate,
        fee: 15000,
        driverIncome: 15000,
        driverIncomeGross: 15000,
        driverAdminFeePercent: 10,
        driverAdminFee: 1500,
        driverIncomeNet: 13500,
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
      fee: 15000,
      driverIncomeGross: 15000,
      driverAdminFeePercent: 10,
      driverAdminFee: 1500,
      driverIncomeNet: 13500,
      deliveryDistanceText: '2.27 km',
      totalPrice: 15000,
      itemCount: 1,
      statusCode: OrderStatusCodes.completed,
      statusDisplayName: 'Selesai',
      paymentMethod: 'TRANSFER',
      paymentStatus: 'paid',
      shoppingItems: const [
        DriverShoppingItemModel(
          id: 1,
          itemSource: 'MANUAL',
          name: '  ramen mala',
          quantity: 1,
          unitPrice: 12000,
          subtotal: 12000,
          isAvailable: true,
          notes: 'less ice',
        ),
      ],
      proofs: [
        DriverOrderProofModel(
          id: 1,
          type: 'receipt',
          label: 'Foto struk',
          photoUrl: 'https://example.com/receipt.jpg',
          status: 'approved',
          createdAt: DateTime.now().toUtc(),
        ),
      ],
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

class _IdleDriverLocationReporter extends DriverLocationReporterNotifier {
  @override
  DriverLocationReporterState build() {
    return const DriverLocationReporterState();
  }
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
        totalDeliveries: 12,
      ),
      stats: const UserStatsModel(totalOrders: 0, totalPaid: 0),
      addresses: const <SavedAddressModel>[],
    ),
  );
}
