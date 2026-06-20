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
      widgetsSource.indexOf('class _FailedPickupReport'),
    );

    expect(actionCard, contains('isWaitingCancellationFeePayment'));
    expect(
      actionCard,
      contains('Menunggu pembayaran biaya pembatalan dari customer.'),
    );
  });
}
