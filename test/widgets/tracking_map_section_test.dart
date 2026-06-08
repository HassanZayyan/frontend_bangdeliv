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
}
