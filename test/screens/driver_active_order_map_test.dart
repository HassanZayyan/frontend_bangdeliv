import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('driver active map falls back to straight route and fits markers', () {
    final source = File(
      'lib/features/driver_orders/presentation/widgets/driver_active_order_map_widgets.dart',
    ).readAsStringSync();

    expect(source, contains("PolylineId('order_route_fallback')"));
    expect(source, contains('_routeLinePoints()'));
    expect(source, contains('unawaited(_fitCameraToMapPoints())'));
    expect(source, contains('CameraUpdate.newLatLngBounds'));
  });

  test('driver active map uses yellow route polylines', () {
    final source = File(
      'lib/features/driver_orders/presentation/widgets/driver_active_order_map_widgets.dart',
    ).readAsStringSync();

    expect(source, contains('AppColors.routeYellow.withValues(alpha: 0.95)'));
    expect(source, contains('AppColors.routeYellow.withValues(alpha: 0.65)'));
  });

  test('driver active map delays platform view mount during nav churn', () {
    final source = File(
      'lib/features/driver_orders/presentation/widgets/driver_active_order_map_widgets.dart',
    ).readAsStringSync();

    expect(source, contains('_mapMountDelay = Duration(milliseconds: 650)'));
    expect(source, contains('_buildMapLoadingPlaceholder()'));
    expect(source, contains('if (!_mapMountReady)'));
  });

  test('driver active map rotates centered flat driver marker', () {
    final source = File(
      'lib/features/driver_orders/presentation/widgets/driver_active_order_map_widgets.dart',
    ).readAsStringSync();

    expect(source, contains('_syncDriverMovementBearing('));
    expect(source, contains('MapPickerHelpers.bearingBetween('));
    expect(source, contains('MapPickerHelpers.normalizeBearing('));
    expect(source, contains('anchor: const Offset(0.5, 0.5)'));
    expect(source, contains('flat: true'));
    expect(source, contains('rotation: _driverMarkerRotation'));
  });
}
