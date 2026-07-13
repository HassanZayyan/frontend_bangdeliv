import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/config/app_routes.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/driver_orders/application/driver_location_reporter_provider.dart';
import 'package:frontend_bangdeliv/features/driver_orders/application/driver_order_providers.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/screens/driver_active_order_screen.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/utils/service_type.dart';
import 'package:go_router/go_router.dart';

void main() {
  const screenPath =
      'lib/features/driver_orders/presentation/screens/driver_active_order_screen.dart';
  const mapWidgetsPath =
      'lib/features/driver_orders/presentation/widgets/driver_active_order_map_widgets.dart';
  const shoppingWidgetsPath =
      'lib/features/driver_orders/presentation/widgets/driver_active_order_shopping_widgets.dart';
  const actionWidgetsPath =
      'lib/features/driver_orders/presentation/widgets/driver_active_order_action_widgets.dart';
  const sheetDragRegionPath =
      'lib/features/driver_orders/presentation/widgets/driver_order_sheet_drag_region.dart';
  const sharedSheetDragRegionPath =
      'lib/core/widgets/bang_sheet_drag_region.dart';

  test('driver active map renders driver marker from foreground reporter', () {
    final source =
        File(screenPath).readAsStringSync() +
        File(mapWidgetsPath).readAsStringSync();
    final widgetsSource = File(mapWidgetsPath).readAsStringSync();
    final mapCard = widgetsSource.substring(
      widgetsSource.indexOf(
        'class _DriverActiveOrderMapCardState extends State<DriverActiveOrderMapCard>',
      ),
      widgetsSource.indexOf('class _RouteUnavailableBadge'),
    );

    expect(source, contains('driverLocationReporterProvider'));
    expect(mapCard, isNot(contains('Geolocator.getPositionStream')));
    expect(mapCard, contains("MarkerId('driver_position')"));
    expect(mapCard, contains("InfoWindow(title: 'Posisi Anda')"));
    expect(mapCard, contains('buildMotorDriverMarker(size: 40)'));
    expect(mapCard, contains('anchor: const Offset(0.5, 0.5)'));
    expect(mapCard, contains('flat: true'));
    expect(mapCard, contains('rotation: _driverMarkerRotation'));
  });

  test('shopping checkout item cards use compact spacing', () {
    final widgetsSource = File(shoppingWidgetsPath).readAsStringSync();
    final itemEditor = widgetsSource.substring(
      widgetsSource.indexOf('Widget _buildItemEditor('),
      widgetsSource.indexOf('Widget _buildStopSection('),
    );

    expect(
      itemEditor,
      contains(
        'padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)',
      ),
    );
    expect(itemEditor, contains('MaterialTapTargetSize.shrinkWrap'));
    expect(itemEditor, contains('fontSize: 14'));
  });

  test('cancelled with fee unpaid order shows payment waiting message', () {
    final widgetsSource = File(actionWidgetsPath).readAsStringSync();
    final actionCard = widgetsSource.substring(
      widgetsSource.indexOf(
        'class DriverOrderActionCard extends StatelessWidget',
      ),
      widgetsSource.indexOf('bool _shouldShowShoppingClosureFeeHint'),
    );

    expect(actionCard, contains('isWaitingCancellationFeePayment'));
    expect(
      actionCard,
      contains('Menunggu pembayaran biaya pembatalan dari customer.'),
    );
    expect(actionCard, isNot(contains('onReportPickupFailed')));
    expect(actionCard, isNot(contains('Merchant Tutup / Gagal Pickup')));
  });

  test('shopping closure fee hint replaces legacy failed pickup action', () {
    final widgetsSource = File(actionWidgetsPath).readAsStringSync();

    expect(widgetsSource, isNot(contains('Merchant Tutup / Gagal Pickup')));
    expect(widgetsSource, isNot(contains('class _FailedPickupDialog')));
    expect(widgetsSource, contains('Tempat tutup/order batal'));
    expect(
      widgetsSource,
      contains('Tagihan customer 50% ongkir aktif setelah batas tercapai.'),
    );
  });

  test('shopping cancel with fee opens full delivery fee dialog', () {
    final source = File(screenPath).readAsStringSync();

    expect(
      source,
      contains("action.actionCode.trim().toUpperCase() == 'CANCEL_WITH_FEE'"),
    );
    expect(source, contains('showDriverShoppingCancelWithFeeDialog'));
    expect(source, contains('note: cancellationInput?.reason'));
    expect(
      source,
      contains(
        'cancellationPenaltyBaseDeliveryFee: cancellationInput?.baseDeliveryFee',
      ),
    );
  });

  test('driver active order uses a snapping map-first task sheet', () {
    final source = File(screenPath).readAsStringSync();

    expect(source, contains('DraggableScrollableSheet('));
    expect(source, contains('snap: true'));
    expect(source, contains('const mediumExtent = 0.52'));
    expect(source, contains('driver-active-order-point-selector'));
    expect(source, contains("'Petunjuk arah'"));
    expect(source, contains('selectedPickupLocationId:'));
    expect(source, contains('mapFirstMode: true'));
  });

  test(
    'pending shopping merchants are selectable before processing starts',
    () {
      final source = File(screenPath).readAsStringSync();

      expect(
        source,
        contains('DriverActiveOrderPointPresenter.canStartPendingMerchant'),
      );
      expect(source, contains("label: 'Tempat buka'"));
      expect(
        source,
        contains("'Kembali ke tugas aktif: \${activePoint.label}'"),
      );

      final footer = source.substring(
        source.indexOf('Widget _buildSheetFooter('),
        source.indexOf('Future<void> _markMerchantOpen('),
      );
      expect(
        footer.indexOf('canStartPendingMerchant'),
        lessThan(footer.indexOf('selectedPoint.id != activePoint.id')),
      );
    },
  );

  test('driver active order header extends the draggable sheet surface', () {
    final screenSource = File(screenPath).readAsStringSync();
    final dragRegionSource =
        File(sheetDragRegionPath).readAsStringSync() +
        File(sharedSheetDragRegionPath).readAsStringSync();

    expect(screenSource, contains('DriverOrderSheetDragRegion('));
    expect(screenSource, contains("'driver-order-sheet-drag-region'"));
    expect(dragRegionSource, contains('HitTestBehavior.opaque'));
    expect(dragRegionSource, contains('onVerticalDragUpdate:'));
    expect(dragRegionSource, contains('controller.sizeToPixels'));
    expect(dragRegionSource, contains('.pixelsToSize(currentPixels - delta)'));
    expect(dragRegionSource, contains('MediaQuery.disableAnimationsOf'));
  });

  test(
    'driver active order refresh button exposes visible loading feedback',
    () {
      final source = File(screenPath).readAsStringSync();

      expect(source, contains('driverOrderDetailRefreshProvider(id)'));
      expect(source, contains("message: 'Data order berhasil diperbarui.'"));
      expect(source, contains("ValueKey('driver-order-refresh-progress')"));
      expect(source, contains("label: isLoading ? 'Sedang memperbarui order'"));
      expect(source, contains('onPressed: isLoading ? null : onPressed'));
      expect(source, contains('skipLoadingOnRefresh: true'));
      expect(source, contains('skipError: true'));
    },
  );

  testWidgets('courier shows QRIS on summary and pickup but not dropoff', (
    tester,
  ) async {
    final router = await _pumpActiveOrder(
      tester,
      order: _qrisOrder(ServiceTypeCodes.courier),
    );
    addTearDown(router.dispose);

    await _scrollDetailsToText(tester, 'Bukti Foto Order');
    expect(find.text('Pengambilan'), findsOneWidget);
    expect(find.text('Diterima'), findsNothing);
    await _scrollDetailsToText(tester, 'Bukti QRIS Customer');

    await tester.tap(_pointTab('Ringkasan'));
    await tester.pumpAndSettle();
    await _resetDetailsScroll(tester);

    await _scrollDetailsToText(tester, 'Pengambilan');
    expect(find.text('Diterima'), findsOneWidget);
    await _scrollDetailsToText(tester, 'Bukti QRIS Customer');

    await tester.tap(_pointTab('Antar'));
    await tester.pumpAndSettle();
    await _resetDetailsScroll(tester);

    await _scrollDetailsToText(tester, 'Bukti Foto Order');
    expect(find.text('Pengambilan'), findsNothing);
    expect(find.text('Diterima'), findsOneWidget);
    await _scrollDetailsToBottom(tester);

    expect(find.text('Bukti Foto Order'), findsOneWidget);
    expect(find.text('Bukti QRIS Customer'), findsNothing);
  });

  testWidgets('non-courier keeps QRIS on summary and dropoff only', (
    tester,
  ) async {
    final router = await _pumpActiveOrder(
      tester,
      order: _qrisOrder(ServiceTypeCodes.ride),
    );
    addTearDown(router.dispose);

    await _scrollDetailsToBottom(tester);
    expect(find.text('Bukti QRIS Customer'), findsNothing);

    await tester.tap(_pointTab('Ringkasan'));
    await tester.pumpAndSettle();
    await _resetDetailsScroll(tester);

    await _scrollDetailsToText(tester, 'Bukti QRIS Customer');

    await tester.tap(_pointTab('Antar'));
    await tester.pumpAndSettle();
    await _resetDetailsScroll(tester);

    await _scrollDetailsToText(tester, 'Bukti QRIS Customer');
  });

  testWidgets('paid cancellation fee returns driver to home', (tester) async {
    final order = _qrisOrder(ServiceTypeCodes.shopping).copyWith(
      statusCode: 'CANCELLED_WITH_FEE',
      statusDisplayName: 'Dibatalkan Dengan Biaya',
      paymentStatus: 'paid',
    );
    final router = await _pumpActiveOrder(tester, order: order);
    addTearDown(router.dispose);

    expect(find.text('driver home'), findsOneWidget);
    expect(find.byType(DriverActiveOrderScreen), findsNothing);
  });
}

Finder _pointTab(String label) {
  return find.descendant(
    of: find.byKey(const ValueKey('driver-active-order-point-selector')),
    matching: find.text(label),
  );
}

Finder _detailsScrollable() {
  return find
      .descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(Scrollable),
      )
      .last;
}

Future<void> _scrollDetailsToText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.scrollUntilVisible(
    finder,
    260,
    scrollable: _detailsScrollable(),
  );
  expect(finder, findsOneWidget);
}

Future<void> _scrollDetailsToBottom(WidgetTester tester) async {
  for (var index = 0; index < 6; index++) {
    await tester.drag(_detailsScrollable(), const Offset(0, -500));
    await tester.pumpAndSettle();
  }
}

Future<void> _resetDetailsScroll(WidgetTester tester) async {
  for (var index = 0; index < 6; index++) {
    await tester.drag(_detailsScrollable(), const Offset(0, 500));
    await tester.pumpAndSettle();
  }
}

Future<GoRouter> _pumpActiveOrder(
  WidgetTester tester, {
  required DriverOrderModel order,
}) async {
  final router = GoRouter(
    initialLocation: AppRoutes.driverOrderActivePath(order.id),
    routes: [
      GoRoute(
        path: AppRoutes.driverHome,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('driver home'))),
      ),
      GoRoute(
        path: AppRoutes.driverOrderActive,
        builder: (context, state) => DriverActiveOrderScreen(
          orderId: state.pathParameters['orderId'] ?? '',
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(_ActiveDriverAuthSession.new),
        driverOrderDetailProvider.overrideWith((ref, orderId) async => order),
        driverLocationReporterProvider.overrideWith(
          _IdleDriverLocationReporter.new,
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
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

DriverOrderModel _qrisOrder(String serviceTypeCode) {
  return DriverOrderModel(
    id: '42',
    customerName: 'Customer',
    serviceTypeCode: serviceTypeCode,
    pickupAddress: 'Pickup',
    dropoffAddress: 'Dropoff',
    etaMinutes: 8,
    fee: 18000,
    totalPrice: 23000,
    itemCount: 1,
    statusCode: 'ARRIVED_PICKUP',
    paymentMethod: 'QRIS',
    paymentStatus: 'paid',
    proofs: [
      DriverOrderProofModel(
        id: 1,
        type: 'payment_transfer',
        label: 'Bukti QRIS',
        photoUrl: 'https://example.test/qris.jpg',
        status: 'verified',
        note: 'Bukti QRIS dari customer.',
        createdAt: DateTime.parse('2026-07-13T06:06:00+07:00'),
      ),
    ],
  );
}
