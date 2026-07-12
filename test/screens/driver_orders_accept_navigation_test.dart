import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend_bangdeliv/config/app_colors.dart';
import 'package:frontend_bangdeliv/config/app_routes.dart';
import 'package:frontend_bangdeliv/core/di/app_providers.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/screens/driver_orders_screen.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';
import 'package:frontend_bangdeliv/services/driver_order_service.dart';
import 'package:frontend_bangdeliv/utils/order_status.dart';
import 'package:frontend_bangdeliv/utils/service_type.dart';

import '../fakes/fake_order_realtime_client.dart';

void main() {
  testWidgets('accept order opens active order route after server success', (
    tester,
  ) async {
    final acceptCompleter = Completer<void>();
    final fakeService = _AcceptNavigationDriverOrderService(
      acceptCompleter: acceptCompleter,
    );
    final router = _buildRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            () => _FakeAuthSessionNotifier(_driverSession()),
          ),
          driverOrderServiceProvider.overrideWithValue(fakeService),
          orderRealtimeClientProvider.overrideWithValue(
            FakeOrderRealtimeClient(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    await _openFirstOrderDetail(tester);
    expect(find.text('Terima Order'), findsOneWidget);

    await tester.tap(find.text('Terima Order'));
    await tester.pump();
    expect(find.text('active-order:42'), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.driverOrders,
    );

    acceptCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.text('active-order:42'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/driver/orders/42/active',
    );
  });

  testWidgets('accept stale conflict stays on order list and removes order', (
    tester,
  ) async {
    final acceptCompleter = Completer<void>();
    final fakeService = _AcceptNavigationDriverOrderService(
      acceptCompleter: acceptCompleter,
      acceptFailure: const DriverOrderApiException(
        'Order sudah diambil driver lain.',
        statusCode: 409,
      ),
    );
    final router = _buildRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            () => _FakeAuthSessionNotifier(_driverSession()),
          ),
          driverOrderServiceProvider.overrideWithValue(fakeService),
          orderRealtimeClientProvider.overrideWithValue(
            FakeOrderRealtimeClient(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    await _openFirstOrderDetail(tester);
    expect(find.text('Terima Order'), findsOneWidget);

    await tester.tap(find.text('Terima Order'));
    await tester.pump();
    acceptCompleter.complete();
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.driverOrders,
    );
    expect(find.text('active-order:42'), findsNothing);
    expect(find.text('Orderan ini sudah diambil driver lain.'), findsOneWidget);
    expect(find.text('Belum ada orderan masuk'), findsOneWidget);
  });

  testWidgets('incoming shopping order shows all merchant stops', (
    tester,
  ) async {
    await _pumpDriverOrders(
      tester,
      service: _AcceptNavigationDriverOrderService(
        incomingOrders: [
          _incomingShoppingOrder(
            stops: [
              _shoppingStop(
                pickupLocationId: 11,
                sequenceNo: 1,
                name: 'Kopi Nako Semarang Candi',
                address: 'Jl. Jangli Gabeng No.1',
                itemName: 'Es Kopi',
              ),
              _shoppingStop(
                pickupLocationId: 12,
                sequenceNo: 2,
                name: 'Oriana Coffee',
                address: 'Jl. Jupiter II No.8',
                itemName: 'Latte',
              ),
              _shoppingStop(
                pickupLocationId: 13,
                sequenceNo: 3,
                name: 'Araya Catering',
                address: 'Jl. Jupiter II No.11',
                itemName: 'Nasi Box',
              ),
            ],
          ),
        ],
      ),
    );

    await _openFirstOrderDetail(tester);
    expect(find.text('Tempat 1'), findsWidgets);
    expect(find.text('Tempat 2'), findsOneWidget);
    expect(find.text('Tempat 3'), findsWidgets);
    expect(find.textContaining('Kopi Nako Semarang Candi'), findsWidgets);
    expect(find.textContaining('Oriana Coffee'), findsOneWidget);
    expect(find.textContaining('Araya Catering'), findsWidgets);
    expect(find.textContaining('baskoro raya'), findsWidgets);
  });

  testWidgets('incoming order opens detail from the whole card surface', (
    tester,
  ) async {
    await _pumpDriverOrders(
      tester,
      service: _AcceptNavigationDriverOrderService(),
    );

    await tester.tap(find.text('Mhn Zayyan'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Order'), findsOneWidget);
    expect(find.text('Terima Order'), findsOneWidget);
  });

  testWidgets('empty incoming orders uses activity empty illustration', (
    tester,
  ) async {
    await _pumpDriverOrders(
      tester,
      service: _AcceptNavigationDriverOrderService(
        incomingOrders: const <DriverOrderModel>[],
      ),
    );

    expect(find.text('Belum ada orderan masuk'), findsOneWidget);
    final emptyText = tester.widget<Text>(find.text('Belum ada orderan masuk'));
    expect(emptyText.style?.fontSize, 13);
    expect(emptyText.style?.fontWeight, FontWeight.w500);
    expect(emptyText.style?.color, AppColors.textSecondary);
    expect(find.byIcon(Icons.description_rounded), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsNothing);
  });

  testWidgets('empty incoming orders can pull refresh to load new orders', (
    tester,
  ) async {
    final service = _AcceptNavigationDriverOrderService(
      incomingOrders: const <DriverOrderModel>[],
    );

    await _pumpDriverOrders(tester, service: service);

    final initialFetchCount = service.fetchOrdersCallCount;
    expect(find.text('Belum ada orderan masuk'), findsOneWidget);
    expect(find.text('Lihat Detail'), findsNothing);

    service.setIncomingOrders([
      _AcceptNavigationDriverOrderService.defaultIncomingOrder,
    ]);
    await tester.drag(find.byType(Scrollable), const Offset(0, 320));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(service.fetchOrdersCallCount, greaterThan(initialFetchCount));
    expect(find.text('Belum ada orderan masuk'), findsNothing);
    expect(find.text('Lihat Detail'), findsOneWidget);
  });

  testWidgets('offline empty state stays scrollable with status action', (
    tester,
  ) async {
    await _pumpDriverOrders(
      tester,
      service: _AcceptNavigationDriverOrderService(
        incomingOrders: const <DriverOrderModel>[],
        availabilityStatus: 'offline',
      ),
    );

    expect(find.text('Status kerja offline'), findsOneWidget);
    expect(find.text('Atur Status Kerja'), findsOneWidget);
    expect(find.byType(Scrollable), findsOneWidget);
  });

  testWidgets('incoming shopping order shows only available merchant count', (
    tester,
  ) async {
    await _pumpDriverOrders(
      tester,
      service: _AcceptNavigationDriverOrderService(
        incomingOrders: [
          _incomingShoppingOrder(
            stops: [
              _shoppingStop(
                pickupLocationId: 21,
                sequenceNo: 1,
                name: 'Merchant Pertama',
                address: 'Jl. Satu',
              ),
              _shoppingStop(
                pickupLocationId: 22,
                sequenceNo: 2,
                name: 'Merchant Kedua',
                address: 'Jl. Dua',
              ),
            ],
          ),
        ],
      ),
    );

    await _openFirstOrderDetail(tester);
    expect(find.text('Tempat 1'), findsWidgets);
    expect(find.text('Tempat 2'), findsWidgets);
    expect(find.text('Tempat 3'), findsNothing);
    expect(find.textContaining('Merchant Pertama'), findsWidgets);
    expect(find.textContaining('Merchant Kedua'), findsWidgets);
  });

  testWidgets('incoming shopping order without stops falls back to pickup', (
    tester,
  ) async {
    await _pumpDriverOrders(
      tester,
      service: _AcceptNavigationDriverOrderService(
        incomingOrders: [
          _incomingShoppingOrder(stops: const <DriverShoppingStopModel>[]),
        ],
      ),
    );

    expect(find.text('Jemput'), findsOneWidget);
    expect(find.text('Tempat 1'), findsNothing);
    expect(find.textContaining('Fallback merchant address'), findsOneWidget);
  });

  testWidgets(
    'incoming ride order can expand full pickup and dropoff address',
    (tester) async {
      const pickup =
          'baskoro raya, Bejalen, Kecamatan Ambarawa, Kabupaten Semarang, '
          'Jawa Tengah, 50611';
      const dropoff =
          'Erha Skin Setiabudi, Jalan Setia Budi Nomor 84, Sumurboto, '
          'Kecamatan Banyumanik, Kota Semarang, Jawa Tengah 50263';

      await _pumpDriverOrders(
        tester,
        service: _AcceptNavigationDriverOrderService(
          incomingOrders: [
            _incomingRideOrder(pickupAddress: pickup, dropoffAddress: dropoff),
          ],
        ),
      );

      await _openFirstOrderDetail(tester);
      expect(find.text(pickup), findsWidgets);
      expect(find.text(dropoff), findsWidgets);

      if (find.text('Lihat alamat lengkap').evaluate().isNotEmpty) {
        await tester.tap(find.text('Lihat alamat lengkap'));
        await tester.pumpAndSettle();

        expect(find.text(pickup), findsWidgets);
        expect(find.text(dropoff), findsWidgets);
        expect(find.text('Tutup alamat'), findsOneWidget);
      }
    },
  );
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: AppRoutes.driverOrders,
    routes: [
      GoRoute(
        path: AppRoutes.driverOrders,
        builder: (context, state) => const DriverOrdersScreen(),
      ),
      GoRoute(
        path: AppRoutes.driverOrderActive,
        builder: (context, state) => Scaffold(
          body: Text('active-order:${state.pathParameters['orderId']}'),
        ),
      ),
    ],
  );
}

Future<void> _pumpDriverOrders(
  WidgetTester tester, {
  required _AcceptNavigationDriverOrderService service,
}) async {
  final router = _buildRouter();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          () => _FakeAuthSessionNotifier(_driverSession()),
        ),
        driverOrderServiceProvider.overrideWithValue(service),
        orderRealtimeClientProvider.overrideWithValue(
          FakeOrderRealtimeClient(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openFirstOrderDetail(WidgetTester tester) async {
  await tester.tap(find.text('Lihat Detail').first);
  await tester.pumpAndSettle();
}

class _AcceptNavigationDriverOrderService extends DriverOrderService {
  _AcceptNavigationDriverOrderService({
    Completer<void>? acceptCompleter,
    List<DriverOrderModel>? incomingOrders,
    List<List<DriverOrderModel>>? incomingOrderBatches,
    this.availabilityStatus = 'available',
    this.acceptFailure,
  }) : acceptCompleter = acceptCompleter ?? Completer<void>(),
       incomingOrderBatches =
           incomingOrderBatches ??
           [
             incomingOrders ?? const [_defaultIncomingOrder],
           ] {
    _latestIncomingOrders = this.incomingOrderBatches.first;
  }

  final Completer<void> acceptCompleter;
  final List<List<DriverOrderModel>> incomingOrderBatches;
  final String availabilityStatus;
  final DriverOrderApiException? acceptFailure;
  late List<DriverOrderModel> _latestIncomingOrders;
  List<DriverOrderModel>? _manualIncomingOrders;
  int fetchOrdersCallCount = 0;

  static const DriverOrderModel _defaultIncomingOrder = DriverOrderModel(
    id: '42',
    orderNumber: 'BDR-260615-6142',
    customerName: 'Mhn Zayyan',
    pickupAddress: 'baskoro raya',
    dropoffAddress: 'Mie Gacoan Setiabudi',
    etaMinutes: 8,
    fee: 9000,
    totalPrice: 9000,
    itemCount: 1,
    statusCode: OrderStatusCodes.pending,
  );

  static DriverOrderModel get defaultIncomingOrder => _defaultIncomingOrder;

  void setIncomingOrders(List<DriverOrderModel> orders) {
    _manualIncomingOrders = orders;
  }

  @override
  Future<String> fetchAvailabilityStatus() async => availabilityStatus;

  @override
  Future<DriverOrdersPayload> fetchOrders() async {
    fetchOrdersCallCount += 1;
    final manualIncomingOrders = _manualIncomingOrders;
    if (manualIncomingOrders != null) {
      _latestIncomingOrders = manualIncomingOrders;
    } else {
      final batchIndex = fetchOrdersCallCount - 1 < incomingOrderBatches.length
          ? fetchOrdersCallCount - 1
          : incomingOrderBatches.length - 1;
      _latestIncomingOrders = incomingOrderBatches[batchIndex];
    }

    return DriverOrdersPayload(
      incoming: _latestIncomingOrders,
      running: const <DriverOrderModel>[],
    );
  }

  @override
  Future<DriverOrderModel> acceptOrder(String orderId) async {
    await acceptCompleter.future;
    final failure = acceptFailure;
    if (failure != null) {
      throw failure;
    }

    final selectedOrder = _latestIncomingOrders.firstWhere(
      (order) => order.id == orderId,
      orElse: () => _latestIncomingOrders.first,
    );
    return selectedOrder.copyWith(
      statusCode: OrderStatusCodes.driverAssigned,
      statusDisplayName: orderStatusLabel(OrderStatusCodes.driverAssigned),
    );
  }
}

DriverOrderModel _incomingRideOrder({
  required String pickupAddress,
  required String dropoffAddress,
}) {
  return DriverOrderModel(
    id: '42',
    orderNumber: 'BDR-260615-6142',
    customerName: 'Mhn Zayyan',
    serviceTypeCode: ServiceTypeCodes.ride,
    pickupAddress: pickupAddress,
    dropoffAddress: dropoffAddress,
    etaMinutes: 8,
    fee: 9000,
    totalPrice: 9000,
    itemCount: 1,
    statusCode: OrderStatusCodes.pending,
  );
}

DriverOrderModel _incomingShoppingOrder({
  required List<DriverShoppingStopModel> stops,
}) {
  return DriverOrderModel(
    id: '43',
    orderNumber: 'BDR-260615-6143',
    customerName: 'Mhn Zayyan',
    serviceTypeCode: ServiceTypeCodes.shopping,
    pickupAddress: 'Fallback merchant address',
    dropoffAddress: 'baskoro raya, Bejalen, Kec. Ambarawa, Kabupaten Semarang',
    etaMinutes: 8,
    fee: 21000,
    totalPrice: 21000,
    itemCount: 3,
    statusCode: OrderStatusCodes.pending,
    shoppingStops: stops,
  );
}

DriverShoppingStopModel _shoppingStop({
  required int pickupLocationId,
  required int sequenceNo,
  required String name,
  required String address,
  String itemName = 'Item',
}) {
  return DriverShoppingStopModel(
    pickupLocationId: pickupLocationId,
    sequenceNo: sequenceNo,
    merchant: DriverShoppingMerchantModel(
      id: null,
      name: name,
      merchantType: 'cafe',
      address: address,
    ),
    items: [
      DriverShoppingItemModel(
        id: pickupLocationId,
        pickupLocationId: pickupLocationId,
        itemSource: 'MANUAL',
        name: itemName,
        quantity: 1,
        unitPrice: 0,
        subtotal: 0,
        isAvailable: true,
      ),
    ],
  );
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
        totalDeliveries: 12,
      ),
      stats: const UserStatsModel(totalOrders: 0, totalPaid: 0),
      addresses: const <SavedAddressModel>[],
    ),
  );
}
