import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../config/app_colors.dart';
import '../../../../models/driver_order_model.dart';
import '../../../../utils/map_marker_icons.dart';
import '../../../../utils/map_picker_helpers.dart';

class DriverActiveOrderMapCard extends StatefulWidget {
  final DriverOrderModel order;
  final LatLng? driverPosition;

  const DriverActiveOrderMapCard({
    super.key,
    required this.order,
    this.driverPosition,
  });

  @override
  State<DriverActiveOrderMapCard> createState() =>
      _DriverActiveOrderMapCardState();
}

class _DriverActiveOrderMapCardState extends State<DriverActiveOrderMapCard> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _driverMarkerIcon;
  LatLng? _lastDriverPositionForBearing;
  Timer? _mapMountTimer;
  bool _mapMountReady = false;
  bool _hasFittedDriverPosition = false;
  double _driverMovementBearing = 0;

  static const double _driverBearingJitterThresholdMeters = 2;
  static const Duration _mapMountDelay = Duration(milliseconds: 650);

  double get _driverMarkerRotation =>
      MapPickerHelpers.normalizeBearing(_driverMovementBearing - 90);

  @override
  void initState() {
    super.initState();
    _lastDriverPositionForBearing = widget.driverPosition;
    _scheduleMapMount();
    unawaited(_loadDriverMarkerIcon());
  }

  void _scheduleMapMount() {
    _mapMountTimer?.cancel();
    _mapMountTimer = Timer(_mapMountDelay, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _mapMountReady = true;
      });
    });
  }

  @override
  void dispose() {
    _mapMountTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DriverActiveOrderMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.driverPosition != widget.driverPosition) {
      _syncDriverMovementBearing(
        oldWidget.driverPosition,
        widget.driverPosition,
      );
    }

    if (oldWidget.driverPosition == null &&
        widget.driverPosition != null &&
        !_hasFittedDriverPosition) {
      _hasFittedDriverPosition = true;
      unawaited(_fitCameraToMapPoints());
    }
  }

  Future<void> _loadDriverMarkerIcon() async {
    final icon = await buildMotorDriverMarker(size: 40);
    if (!mounted) {
      return;
    }

    setState(() => _driverMarkerIcon = icon);
  }

  @override
  Widget build(BuildContext context) {
    final pickupPoints = _pickupPoints();
    final pickup = pickupPoints.isEmpty ? null : pickupPoints.first.position;
    final dropoff = _latLng(
      widget.order.dropoffLatitude,
      widget.order.dropoffLongitude,
    );
    final driverPosition = widget.driverPosition;

    if (pickupPoints.isEmpty && dropoff == null) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: const Center(
          child: Text(
            'Koordinat map belum tersedia untuk order ini.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final initial = pickup ?? dropoff!;
    final showRouteUnavailableHint = _shouldShowRouteUnavailableHint();
    final markers = <Marker>{
      for (final pickupPoint in pickupPoints)
        Marker(
          markerId: MarkerId('pickup_${pickupPoint.id}'),
          position: pickupPoint.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: pickupPoint.label),
        ),
      if (dropoff != null)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoff,
          infoWindow: const InfoWindow(title: 'Dropoff'),
        ),
      if (driverPosition != null)
        Marker(
          markerId: const MarkerId('driver_position'),
          position: driverPosition,
          icon:
              _driverMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: _driverMarkerRotation,
          infoWindow: const InfoWindow(title: 'Posisi Anda'),
        ),
    };

    if (!_mapMountReady) {
      return _buildMapLoadingPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 230,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: initial, zoom: 14),
              markers: markers,
              polylines: _buildPolylines(),
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  EagerGestureRecognizer.new,
                ),
              },
              myLocationButtonEnabled: false,
              mapToolbarEnabled: true,
              zoomControlsEnabled: false,
              compassEnabled: true,
              onMapCreated: (controller) {
                _mapController = controller;
                unawaited(_fitCameraToMapPoints());
              },
            ),
            if (showRouteUnavailableHint)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: const _RouteUnavailableBadge(),
              ),
            if (widget.order.deliveryDistanceLabel.isNotEmpty)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: _MapDistanceBadge(
                  label: widget.order.deliveryDistanceLabel,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapLoadingPlaceholder() {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }

  LatLng? _latLng(double? lat, double? lng) {
    if (lat == null || lng == null) {
      return null;
    }
    return LatLng(lat, lng);
  }

  void _syncDriverMovementBearing(
    LatLng? previousPosition,
    LatLng? nextPosition,
  ) {
    if (nextPosition == null) {
      _lastDriverPositionForBearing = null;
      return;
    }

    final origin = _lastDriverPositionForBearing ?? previousPosition;
    if (origin == null) {
      _lastDriverPositionForBearing = nextPosition;
      return;
    }

    final distanceMeters = MapPickerHelpers.distanceMeters(
      origin,
      nextPosition,
    );
    if (distanceMeters < _driverBearingJitterThresholdMeters) {
      return;
    }

    _driverMovementBearing = MapPickerHelpers.bearingBetween(
      origin,
      nextPosition,
    );
    _lastDriverPositionForBearing = nextPosition;
  }

  List<_DriverPickupPoint> _pickupPoints() {
    final orderedIds =
        widget.order.route?.orderedPickupLocationIds ?? const <int>[];
    final activeStops = widget.order.shoppingStops
        .where((stop) => stop.isActive)
        .where(
          (stop) =>
              stop.merchant.latitude != null && stop.merchant.longitude != null,
        )
        .toList(growable: false);
    activeStops.sort((a, b) {
      final aIndex = orderedIds.indexOf(a.pickupLocationId);
      final bIndex = orderedIds.indexOf(b.pickupLocationId);
      if (aIndex >= 0 || bIndex >= 0) {
        return (aIndex < 0 ? 1 << 20 : aIndex).compareTo(
          bIndex < 0 ? 1 << 20 : bIndex,
        );
      }
      return a.sequenceNo.compareTo(b.sequenceNo);
    });

    final stopPoints = activeStops
        .map(
          (stop) => _DriverPickupPoint(
            id: stop.pickupLocationId.toString(),
            label:
                'Tempat ${stop.sequenceNo <= 0 ? 1 : stop.sequenceNo}: ${stop.merchant.name}',
            position: LatLng(stop.merchant.latitude!, stop.merchant.longitude!),
          ),
        )
        .toList(growable: false);

    if (stopPoints.isNotEmpty) {
      return stopPoints;
    }

    final fallback = _latLng(
      widget.order.pickupLatitude,
      widget.order.pickupLongitude,
    );
    if (fallback == null) {
      return const <_DriverPickupPoint>[];
    }

    return [
      _DriverPickupPoint(id: 'default', label: 'Pickup', position: fallback),
    ];
  }

  Set<Polyline> _buildPolylines() {
    final decodedPoints = _decodePolyline(widget.order.route?.encodedPolyline);
    if (decodedPoints.length >= 2) {
      return {
        Polyline(
          polylineId: const PolylineId('order_route'),
          points: decodedPoints,
          color: AppColors.routeYellow.withValues(alpha: 0.95),
          width: 4,
          geodesic: true,
        ),
      };
    }

    final fallbackPoints = _routeLinePoints();
    if (fallbackPoints.length < 2) {
      return const <Polyline>{};
    }

    return {
      Polyline(
        polylineId: const PolylineId('order_route_fallback'),
        points: fallbackPoints,
        color: AppColors.routeYellow.withValues(alpha: 0.65),
        width: 3,
        geodesic: true,
      ),
    };
  }

  bool _shouldShowRouteUnavailableHint() {
    if (_decodePolyline(widget.order.route?.encodedPolyline).length >= 2) {
      return false;
    }

    return _pickupPoints().isNotEmpty &&
        _latLng(widget.order.dropoffLatitude, widget.order.dropoffLongitude) !=
            null;
  }

  List<LatLng> _routeLinePoints() {
    final points = <LatLng>[..._pickupPoints().map((point) => point.position)];
    final dropoff = _latLng(
      widget.order.dropoffLatitude,
      widget.order.dropoffLongitude,
    );
    if (dropoff != null) {
      points.add(dropoff);
    }

    return points;
  }

  Future<void> _fitCameraToMapPoints() async {
    final controller = _mapController;
    if (controller == null || !mounted) {
      return;
    }

    final points = <LatLng>[..._routeLinePoints(), ?widget.driverPosition];

    if (points.isEmpty) {
      return;
    }

    try {
      if (points.length == 1) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(points.first, 15),
        );
        return;
      }

      double minLat = points.first.latitude;
      double maxLat = points.first.latitude;
      double minLng = points.first.longitude;
      double maxLng = points.first.longitude;

      for (final point in points.skip(1)) {
        if (point.latitude < minLat) {
          minLat = point.latitude;
        }
        if (point.latitude > maxLat) {
          maxLat = point.latitude;
        }
        if (point.longitude < minLng) {
          minLng = point.longitude;
        }
        if (point.longitude > maxLng) {
          maxLng = point.longitude;
        }
      }

      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          64,
        ),
      );
    } catch (_) {
      // Camera animation can fail while the platform map is being recreated.
    }
  }

  List<LatLng> _decodePolyline(String? encoded) {
    final value = (encoded ?? '').trim();
    if (value.isEmpty) {
      return const <LatLng>[];
    }

    final points = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;

    while (index < value.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = value.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < value.length);
      latitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        byte = value.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < value.length);
      longitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      points.add(LatLng(latitude / 1e5, longitude / 1e5));
    }

    return points;
  }
}

class _MapDistanceBadge extends StatelessWidget {
  const _MapDistanceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.route_outlined,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Jarak $label',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteUnavailableBadge extends StatelessWidget {
  const _RouteUnavailableBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: const Text(
          'Rute jalan belum tersedia, coba refresh.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DriverPickupPoint {
  const _DriverPickupPoint({
    required this.id,
    required this.label,
    required this.position,
  });

  final String id;
  final String label;
  final LatLng position;
}
