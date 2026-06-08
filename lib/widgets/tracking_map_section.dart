import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/app_colors.dart';
import '../utils/map_marker_icons.dart';
import '../utils/order_formatters.dart';

class TrackingMapPickupPoint {
  const TrackingMapPickupPoint({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String label;
  final double latitude;
  final double longitude;
}

class TrackingMapSection extends StatefulWidget {
  const TrackingMapSection({
    super.key,
    required this.dropoffAddress,
    this.pickupStops = const <TrackingMapPickupPoint>[],
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.driverLatitude,
    this.driverLongitude,
    this.driverLocationUpdatedAt,
    this.encodedPolyline,
    this.height = 260,
    this.borderRadius = 16,
    this.showLegend = true,
    this.followDriver = false,
  });

  final String dropoffAddress;
  final List<TrackingMapPickupPoint> pickupStops;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final double? driverLatitude;
  final double? driverLongitude;
  final DateTime? driverLocationUpdatedAt;
  final String? encodedPolyline;
  final double height;
  final double borderRadius;
  final bool showLegend;
  final bool followDriver;

  @override
  State<TrackingMapSection> createState() => _TrackingMapSectionState();
}

class _TrackingMapSectionState extends State<TrackingMapSection> {
  GoogleMapController? _mapController;
  bool _isFollowingDriver = false;
  bool _isProgrammaticCameraMove = false;
  bool _hasPerformedInitialFit = false;
  LatLng? _lastFocusedDriverPosition;
  DateTime? _lastFocusedDriverUpdatedAt;
  BitmapDescriptor? _driverMarkerIcon;

  static const LatLng _fallbackCenter = LatLng(-7.0503, 110.4370);
  static const double _driverFollowZoom = 16;

  @override
  void initState() {
    super.initState();
    _isFollowingDriver = widget.followDriver;
    unawaited(_loadDriverMarkerIcon());
  }

  Future<void> _loadDriverMarkerIcon() async {
    final icon = await buildMotorDriverMarker();
    if (!mounted) {
      return;
    }
    setState(() => _driverMarkerIcon = icon);
  }

  @override
  void didUpdateWidget(covariant TrackingMapSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_routePointsChanged(oldWidget)) {
      _hasPerformedInitialFit = false;
    }

    if (!widget.followDriver) {
      _isFollowingDriver = false;
      unawaited(_fitCameraToMarkers());
      return;
    }

    if (!_hasDriverCoordinates) {
      _lastFocusedDriverPosition = null;
      _lastFocusedDriverUpdatedAt = null;
      unawaited(_fitCameraToMarkers());
      return;
    }

    if (!oldWidget.followDriver && widget.followDriver) {
      _isFollowingDriver = true;
    }

    if (!_hasPerformedInitialFit) {
      unawaited(_fitInitialCamera());
      return;
    }

    if (_isFollowingDriver && _driverPositionChanged(oldWidget)) {
      unawaited(_focusCameraOnDriver());
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  bool get _hasDriverCoordinates =>
      widget.driverLatitude != null && widget.driverLongitude != null;

  LatLng? get _driverPosition {
    if (!_hasDriverCoordinates) {
      return null;
    }

    return LatLng(widget.driverLatitude!, widget.driverLongitude!);
  }

  LatLng _initialCameraTarget(Set<Marker> markers) {
    final routePoints = _routeLinePoints();
    if (routePoints.isNotEmpty) {
      return routePoints.first;
    }

    return markers.first.position;
  }

  double _initialZoom() {
    if (_routeLinePoints().length < 2 &&
        widget.followDriver &&
        _hasDriverCoordinates) {
      return _driverFollowZoom;
    }

    return 14;
  }

  void _handleCameraMoveStarted() {
    if (!widget.followDriver ||
        !_hasDriverCoordinates ||
        !_isFollowingDriver ||
        _isProgrammaticCameraMove) {
      return;
    }

    setState(() {
      _isFollowingDriver = false;
    });
  }

  void _resumeDriverFollow() {
    if (!_hasDriverCoordinates) {
      return;
    }

    setState(() {
      _isFollowingDriver = true;
    });

    _focusCameraOnDriver(force: true);
  }

  Future<void> _focusCameraOnDriver({bool force = false}) async {
    final driverPosition = _driverPosition;
    if (_mapController == null || !mounted || driverPosition == null) {
      return;
    }

    if (!force && !_shouldMoveToDriver(driverPosition)) {
      return;
    }

    _lastFocusedDriverPosition = driverPosition;
    _lastFocusedDriverUpdatedAt = widget.driverLocationUpdatedAt;

    await _animateCamera(
      CameraUpdate.newLatLngZoom(driverPosition, _driverFollowZoom),
    );
  }

  bool _shouldMoveToDriver(LatLng driverPosition) {
    final lastPosition = _lastFocusedDriverPosition;
    final lastUpdatedAt = _lastFocusedDriverUpdatedAt;
    final updatedAt = widget.driverLocationUpdatedAt;

    if (lastPosition == null) {
      return true;
    }

    final movedEnough =
        (lastPosition.latitude - driverPosition.latitude).abs() > 0.00001 ||
        (lastPosition.longitude - driverPosition.longitude).abs() > 0.00001;
    if (movedEnough) {
      return true;
    }

    if (updatedAt == null) {
      return false;
    }

    return lastUpdatedAt == null || !lastUpdatedAt.isAtSameMomentAs(updatedAt);
  }

  Future<void> _animateCamera(CameraUpdate update) async {
    final controller = _mapController;
    if (controller == null || !mounted) {
      return;
    }

    _isProgrammaticCameraMove = true;
    try {
      await controller.animateCamera(update);
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      _isProgrammaticCameraMove = false;
    }
  }

  Future<void> _fitCameraToMarkers() async {
    final controller = _mapController;
    if (controller == null || !mounted) {
      return;
    }

    final points = <LatLng>[];

    points.addAll(_pickupPoints().map((point) => point.position));
    if (widget.dropoffLatitude != null && widget.dropoffLongitude != null) {
      points.add(LatLng(widget.dropoffLatitude!, widget.dropoffLongitude!));
    }
    if (widget.driverLatitude != null && widget.driverLongitude != null) {
      points.add(LatLng(widget.driverLatitude!, widget.driverLongitude!));
    }

    if (points.isEmpty) {
      await _animateCamera(CameraUpdate.newLatLngZoom(_fallbackCenter, 12));
      return;
    }

    if (points.length == 1) {
      await _animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
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

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    await _animateCamera(CameraUpdate.newLatLngBounds(bounds, 64));
  }

  Future<void> _fitInitialCamera() async {
    if (_hasPerformedInitialFit) {
      return;
    }

    _hasPerformedInitialFit = true;
    await _fitCameraToMarkers();

    if (widget.followDriver && _hasDriverCoordinates) {
      _isFollowingDriver = true;
      _lastFocusedDriverPosition = _driverPosition;
      _lastFocusedDriverUpdatedAt = widget.driverLocationUpdatedAt;
    }
  }

  bool _routePointsChanged(TrackingMapSection oldWidget) {
    return oldWidget.pickupStops != widget.pickupStops ||
        oldWidget.pickupLatitude != widget.pickupLatitude ||
        oldWidget.pickupLongitude != widget.pickupLongitude ||
        oldWidget.dropoffLatitude != widget.dropoffLatitude ||
        oldWidget.dropoffLongitude != widget.dropoffLongitude ||
        oldWidget.encodedPolyline != widget.encodedPolyline;
  }

  bool _driverPositionChanged(TrackingMapSection oldWidget) {
    return oldWidget.driverLatitude != widget.driverLatitude ||
        oldWidget.driverLongitude != widget.driverLongitude ||
        oldWidget.driverLocationUpdatedAt != widget.driverLocationUpdatedAt;
  }

  @override
  Widget build(BuildContext context) {
    final markers = _buildMarkers();
    final showRouteUnavailableHint = _shouldShowRouteUnavailableHint();

    if (markers.isEmpty) {
      return _buildUnavailableMap();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialCameraTarget(markers),
                zoom: _initialZoom(),
              ),
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
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              onCameraMoveStarted: _handleCameraMoveStarted,
              onMapCreated: (controller) {
                _mapController = controller;
                unawaited(_fitInitialCamera());
              },
            ),
            Positioned(top: 10, left: 10, right: 10, child: _buildTopHint()),
            if (showRouteUnavailableHint)
              Positioned(
                top: 52,
                left: 10,
                right: 10,
                child: _buildRouteUnavailableHint(),
              ),
            if (widget.followDriver &&
                _hasDriverCoordinates &&
                !_isFollowingDriver)
              Positioned(top: 52, right: 10, child: _buildResumeFollowButton()),
            if (widget.showLegend)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: _buildLegend(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteUnavailableHint() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Rute jalan belum tersedia, coba refresh.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildResumeFollowButton() {
    return Material(
      color: AppColors.white.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        onPressed: _resumeDriverFollow,
        tooltip: 'Ikuti driver',
        icon: const Icon(Icons.my_location_rounded),
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildUnavailableMap() {
    return Container(
      width: double.infinity,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Row(
              children: [
                Icon(Icons.map_outlined, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text(
                  'Peta tracking belum tersedia',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Koordinat rute belum lengkap. Alamat tujuan: ${widget.dropoffAddress}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        _driverUpdateText(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _legendItem('Pickup', Colors.green),
          _legendItem('Tujuan', AppColors.error),
          _legendItem('Driver', AppColors.primary),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    for (final point in _pickupPoints()) {
      markers.add(
        Marker(
          markerId: MarkerId('pickup_${point.id}'),
          position: point.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: point.label),
        ),
      );
    }

    if (widget.dropoffLatitude != null && widget.dropoffLongitude != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(widget.dropoffLatitude!, widget.dropoffLongitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Titik Tujuan'),
        ),
      );
    }

    if (widget.driverLatitude != null && widget.driverLongitude != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(widget.driverLatitude!, widget.driverLongitude!),
          icon:
              _driverMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Posisi Driver'),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final decodedPoints = _decodePolyline(widget.encodedPolyline);
    if (decodedPoints.length >= 2) {
      return {
        Polyline(
          polylineId: const PolylineId('order_route'),
          points: decodedPoints,
          color: AppColors.primary,
          width: 5,
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
        color: AppColors.primary.withValues(alpha: 0.55),
        width: 4,
        geodesic: true,
      ),
    };
  }

  bool _shouldShowRouteUnavailableHint() {
    if (_decodePolyline(widget.encodedPolyline).length >= 2) {
      return false;
    }

    return _pickupPoints().isNotEmpty &&
        widget.dropoffLatitude != null &&
        widget.dropoffLongitude != null;
  }

  List<LatLng> _routeLinePoints() {
    final points = <LatLng>[..._pickupPoints().map((point) => point.position)];
    if (widget.dropoffLatitude != null && widget.dropoffLongitude != null) {
      points.add(LatLng(widget.dropoffLatitude!, widget.dropoffLongitude!));
    }

    return points;
  }

  List<_PickupPointView> _pickupPoints() {
    if (widget.pickupStops.isNotEmpty) {
      return widget.pickupStops
          .map(
            (stop) => _PickupPointView(
              id: stop.id,
              label: stop.label.trim().isEmpty ? 'Merchant' : stop.label,
              position: LatLng(stop.latitude, stop.longitude),
            ),
          )
          .toList(growable: false);
    }

    if (widget.pickupLatitude == null || widget.pickupLongitude == null) {
      return const <_PickupPointView>[];
    }

    return [
      _PickupPointView(
        id: 'default',
        label: 'Titik Pickup',
        position: LatLng(widget.pickupLatitude!, widget.pickupLongitude!),
      ),
    ];
  }

  String _driverUpdateText() {
    final hasDriverCoordinates =
        widget.driverLatitude != null && widget.driverLongitude != null;

    if (!hasDriverCoordinates) {
      return 'Lokasi driver belum tersedia';
    }

    final updatedAt = widget.driverLocationUpdatedAt;
    if (updatedAt == null) {
      return 'Lokasi driver tersedia';
    }

    return 'Update lokasi driver terakhir ${formatTime(updatedAt)}';
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

class _PickupPointView {
  const _PickupPointView({
    required this.id,
    required this.label,
    required this.position,
  });

  final String id;
  final String label;
  final LatLng position;
}
