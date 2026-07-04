import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:frontend_bangdeliv/utils/map_picker_helpers.dart';

void main() {
  group('MapPickerHelpers.validLatLng', () {
    test('returns LatLng for valid coordinates', () {
      final target = MapPickerHelpers.validLatLng(-7.33, 110.50);

      expect(target, isNotNull);
      expect(target!.latitude, -7.33);
      expect(target.longitude, 110.50);
    });

    test('rejects missing, out of range, and zero coordinates by default', () {
      expect(MapPickerHelpers.validLatLng(null, 110.50), isNull);
      expect(MapPickerHelpers.validLatLng(-7.33, null), isNull);
      expect(MapPickerHelpers.validLatLng(-91, 110.50), isNull);
      expect(MapPickerHelpers.validLatLng(-7.33, 181), isNull);
      expect(MapPickerHelpers.validLatLng(0, 0), isNull);
    });

    test('allows zero coordinates when requested', () {
      final target = MapPickerHelpers.validLatLng(0, 0, allowZero: true);

      expect(target, isNotNull);
      expect(target!.latitude, 0);
      expect(target.longitude, 0);
    });
  });

  group('MapPickerHelpers.distanceMeters', () {
    test('returns zero for the same point', () {
      const point = LatLng(-7.33, 110.50);

      expect(MapPickerHelpers.distanceMeters(point, point), closeTo(0, 0.01));
    });

    test('calculates a stable haversine distance', () {
      final distance = MapPickerHelpers.distanceMeters(
        const LatLng(0, 0),
        const LatLng(0, 1),
      );

      expect(distance, closeTo(111195, 500));
    });
  });

  group('MapPickerHelpers.normalizeBearing', () {
    test('wraps values into a 0 to 360 degree range', () {
      expect(MapPickerHelpers.normalizeBearing(0), 0);
      expect(MapPickerHelpers.normalizeBearing(360), 0);
      expect(MapPickerHelpers.normalizeBearing(450), 90);
      expect(MapPickerHelpers.normalizeBearing(-90), 270);
    });
  });

  group('MapPickerHelpers.bearingBetween', () {
    test('calculates cardinal movement bearings', () {
      const origin = LatLng(0, 0);

      expect(
        MapPickerHelpers.bearingBetween(origin, const LatLng(1, 0)),
        closeTo(0, 0.001),
      );
      expect(
        MapPickerHelpers.bearingBetween(origin, const LatLng(0, 1)),
        closeTo(90, 0.001),
      );
      expect(
        MapPickerHelpers.bearingBetween(origin, const LatLng(-1, 0)),
        closeTo(180, 0.001),
      );
      expect(
        MapPickerHelpers.bearingBetween(origin, const LatLng(0, -1)),
        closeTo(270, 0.001),
      );
    });
  });

  test('firstAddressSegment returns the first non-empty segment', () {
    expect(
      MapPickerHelpers.firstAddressSegment('  Toko A , Salatiga, Jawa Tengah '),
      'Toko A',
    );
    expect(MapPickerHelpers.firstAddressSegment('  Toko A  '), 'Toko A');
  });

  test('newMapsSessionToken returns a usable token', () {
    final token = MapPickerHelpers.newMapsSessionToken();

    expect(token, isNotEmpty);
    expect(token, contains('-'));
  });
}
