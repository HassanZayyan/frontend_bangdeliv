import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tracking map falls back to straight route before following driver', () {
    final source = File(
      'lib/widgets/tracking_map_section.dart',
    ).readAsStringSync();

    expect(source, contains("PolylineId('order_route_fallback')"));
    expect(source, contains('_routeLinePoints()'));
    expect(source, contains('unawaited(_fitInitialCamera())'));
    expect(
      source,
      isNot(
        contains(
          'onMapCreated: (controller) {\n'
          '                _mapController = controller;\n'
          '                if (widget.followDriver && _hasDriverCoordinates)',
        ),
      ),
    );
  });

  test('tracking map fits route markers with tight default padding', () {
    final source = File(
      'lib/widgets/tracking_map_section.dart',
    ).readAsStringSync();

    expect(source, contains('_markerFitPadding = 28'));
    expect(source, contains('newLatLngBounds(bounds, _markerFitPadding)'));
    expect(source, isNot(contains('newLatLngBounds(bounds, 64)')));
  });

  test('tracking map uses yellow route polylines', () {
    final source = File(
      'lib/widgets/tracking_map_section.dart',
    ).readAsStringSync();

    expect(source, contains('AppColors.routeYellow.withValues(alpha: 0.95)'));
    expect(source, contains('AppColors.routeYellow.withValues(alpha: 0.65)'));
  });

  test('tracking map delays platform view mount during route transitions', () {
    final source = File(
      'lib/widgets/tracking_map_section.dart',
    ).readAsStringSync();

    expect(source, contains('_mapMountDelay = Duration(milliseconds: 650)'));
    expect(source, contains('_buildMapLoadingPlaceholder()'));
    expect(source, contains('if (!_mapMountReady)'));
  });

  test('tracking map rotates centered flat driver marker', () {
    final source = File(
      'lib/widgets/tracking_map_section.dart',
    ).readAsStringSync();

    expect(source, contains('_syncDriverMovementBearing('));
    expect(source, contains('MapPickerHelpers.bearingBetween('));
    expect(source, contains('MapPickerHelpers.normalizeBearing('));
    expect(source, contains('anchor: const Offset(0.5, 0.5)'));
    expect(source, contains('flat: true'));
    expect(source, contains('rotation: _driverMarkerRotation'));
  });
}
