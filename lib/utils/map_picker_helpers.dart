import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum MapPickerLocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class MapPickerCurrentLocationResult {
  const MapPickerCurrentLocationResult._({this.target, this.failure});

  const MapPickerCurrentLocationResult.success(LatLng target)
    : this._(target: target);

  const MapPickerCurrentLocationResult.failed(MapPickerLocationFailure failure)
    : this._(failure: failure);

  final LatLng? target;
  final MapPickerLocationFailure? failure;

  bool get isSuccess => target != null;
}

class MapPickerHelpers {
  const MapPickerHelpers._();

  static LatLng? validLatLng(
    double? latitude,
    double? longitude, {
    bool allowZero = false,
  }) {
    if (latitude == null || longitude == null) return null;
    if (latitude < -90 || latitude > 90) return null;
    if (longitude < -180 || longitude > 180) return null;
    if (!allowZero && latitude == 0 && longitude == 0) return null;

    return LatLng(latitude, longitude);
  }

  static double distanceMeters(LatLng start, LatLng end) {
    const earthRadiusMeters = 6371000.0;
    final startLatitudeRad = _degreesToRadians(start.latitude);
    final endLatitudeRad = _degreesToRadians(end.latitude);
    final deltaLatitudeRad = _degreesToRadians(end.latitude - start.latitude);
    final deltaLongitudeRad = _degreesToRadians(
      end.longitude - start.longitude,
    );

    final haversine =
        math.sin(deltaLatitudeRad / 2) * math.sin(deltaLatitudeRad / 2) +
        math.cos(startLatitudeRad) *
            math.cos(endLatitudeRad) *
            math.sin(deltaLongitudeRad / 2) *
            math.sin(deltaLongitudeRad / 2);
    final safeHaversine = math.min(1.0, math.max(0.0, haversine));
    final centralAngle =
        2 * math.atan2(math.sqrt(safeHaversine), math.sqrt(1 - safeHaversine));

    return earthRadiusMeters * centralAngle;
  }

  static double normalizeBearing(double value) {
    final bearing = value % 360;
    return bearing < 0 ? bearing + 360 : bearing;
  }

  static double bearingBetween(LatLng start, LatLng end) {
    if (start == end) {
      return 0;
    }

    final startLatitudeRad = _degreesToRadians(start.latitude);
    final endLatitudeRad = _degreesToRadians(end.latitude);
    final deltaLongitudeRad = _degreesToRadians(
      end.longitude - start.longitude,
    );

    final y = math.sin(deltaLongitudeRad) * math.cos(endLatitudeRad);
    final x =
        math.cos(startLatitudeRad) * math.sin(endLatitudeRad) -
        math.sin(startLatitudeRad) *
            math.cos(endLatitudeRad) *
            math.cos(deltaLongitudeRad);

    if (x == 0 && y == 0) {
      return 0;
    }

    return normalizeBearing(_radiansToDegrees(math.atan2(y, x)));
  }

  static String newMapsSessionToken() {
    return '${DateTime.now().microsecondsSinceEpoch}-${Object().hashCode}';
  }

  static String firstAddressSegment(String value) {
    final segments = value
        .split(',')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);

    return segments.isEmpty ? value.trim() : segments.first;
  }

  static Future<bool> hasLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    final permission = await Geolocator.checkPermission();

    return isLocationPermissionGranted(permission);
  }

  static bool isLocationPermissionGranted(LocationPermission permission) {
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Future<LocationPermission> requestLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  static Future<MapPickerCurrentLocationResult> currentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const MapPickerCurrentLocationResult.failed(
        MapPickerLocationFailure.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (!isLocationPermissionGranted(permission)) {
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();

        return const MapPickerCurrentLocationResult.failed(
          MapPickerLocationFailure.permissionDeniedForever,
        );
      }

      return const MapPickerCurrentLocationResult.failed(
        MapPickerLocationFailure.permissionDenied,
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    return MapPickerCurrentLocationResult.success(
      LatLng(position.latitude, position.longitude),
    );
  }

  static Future<LatLng?> currentLocationIfPermitted() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    final permission = await Geolocator.checkPermission();
    if (!isLocationPermissionGranted(permission)) return null;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    return LatLng(position.latitude, position.longitude);
  }

  static Future<LatLng?> lastKnownLocationIfPermitted() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    final permission = await Geolocator.checkPermission();
    if (!isLocationPermissionGranted(permission)) return null;

    final position = await Geolocator.getLastKnownPosition();
    if (position == null) {
      return null;
    }

    return LatLng(position.latitude, position.longitude);
  }

  static double _degreesToRadians(double value) => value * math.pi / 180;

  static double _radiansToDegrees(double value) => value * 180 / math.pi;
}
