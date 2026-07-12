import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
}
