import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend_bangdeliv/config/app_routes.dart';
import 'package:frontend_bangdeliv/core/di/app_providers.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/screens/driver_orders_screen.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';
import 'package:frontend_bangdeliv/services/driver_order_service.dart';
import 'package:frontend_bangdeliv/utils/order_status.dart';

import '../fakes/fake_order_realtime_client.dart';

void main() {
  testWidgets(
    'accept order opens active order route after optimistic removal',
    (tester) async {
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
      expect(find.text('Terima Order'), findsOneWidget);

      await tester.tap(find.text('Terima Order'));
      await tester.pump();
      expect(find.text('Terima Order'), findsNothing);

      acceptCompleter.complete();
      await tester.pumpAndSettle();

      expect(find.text('active-order:42'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/driver/orders/42/active',
      );
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

class _AcceptNavigationDriverOrderService extends DriverOrderService {
  _AcceptNavigationDriverOrderService({required this.acceptCompleter});

  final Completer<void> acceptCompleter;
  final DriverOrderModel incomingOrder = const DriverOrderModel(
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

  @override
  Future<String> fetchAvailabilityStatus() async => 'available';

  @override
  Future<DriverOrdersPayload> fetchOrders() async {
    return DriverOrdersPayload(
      incoming: [incomingOrder],
      running: const <DriverOrderModel>[],
    );
  }

  @override
  Future<DriverOrderModel> acceptOrder(String orderId) async {
    await acceptCompleter.future;
    return incomingOrder.copyWith(
      statusCode: OrderStatusCodes.driverAssigned,
      statusDisplayName: orderStatusLabel(OrderStatusCodes.driverAssigned),
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
        totalDeliveries: 12,
      ),
      stats: const UserStatsModel(totalOrders: 0, totalPaid: 0),
      addresses: const <SavedAddressModel>[],
    ),
  );
}
