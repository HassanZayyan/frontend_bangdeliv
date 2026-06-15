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
}
