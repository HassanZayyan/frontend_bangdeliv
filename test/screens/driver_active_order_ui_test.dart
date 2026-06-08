import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('driver active map renders driver marker from foreground reporter', () {
    final source = File(
      'lib/screens/driver_active_order_screen.dart',
    ).readAsStringSync();
    final mapCard = source.substring(
      source.indexOf('class _MapCardState extends State<_MapCard>'),
      source.indexOf('class _RouteUnavailableBadge'),
    );

    expect(source, contains('driverLocationReporterProvider'));
    expect(mapCard, isNot(contains('Geolocator.getPositionStream')));
    expect(mapCard, contains("MarkerId('driver_position')"));
    expect(mapCard, contains("InfoWindow(title: 'Posisi Anda')"));
    expect(mapCard, contains('buildMotorDriverMarker(size: 40)'));
  });

  test('shopping checkout item cards use compact spacing', () {
    final source = File(
      'lib/screens/driver_active_order_screen.dart',
    ).readAsStringSync();
    final itemEditor = source.substring(
      source.indexOf('Widget _buildItemEditor(DriverShoppingItemModel item)'),
      source.indexOf('Widget _buildStopSection(DriverShoppingStopModel stop)'),
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
    final source = File(
      'lib/screens/driver_active_order_screen.dart',
    ).readAsStringSync();
    final actionCard = source.substring(
      source.indexOf('class _ActionCard extends StatelessWidget'),
      source.indexOf('class _FailedPickupReport'),
    );

    expect(actionCard, contains('isWaitingCancellationFeePayment'));
    expect(
      actionCard,
      contains('Menunggu pembayaran biaya pembatalan dari customer.'),
    );
  });
}
