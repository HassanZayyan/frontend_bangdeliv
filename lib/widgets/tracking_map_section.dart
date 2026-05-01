import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/app_colors.dart';
import '../utils/order_formatters.dart';

class TrackingMapSection extends StatefulWidget {
  const TrackingMapSection({
    super.key,
    required this.dropoffAddress,
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.driverLatitude,
    this.driverLongitude,
    this.driverLocationUpdatedAt,
    this.height = 260,
    this.borderRadius = 16,
    this.showLegend = true,
  });

  final String dropoffAddress;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final double? driverLatitude;
  final double? driverLongitude;
  final DateTime? driverLocationUpdatedAt;
  final double height;
  final double borderRadius;
  final bool showLegend;

  @override
  State<TrackingMapSection> createState() => _TrackingMapSectionState();
}

class _TrackingMapSectionState extends State<TrackingMapSection> {
  GoogleMapController? _mapController;

  static const LatLng _fallbackCenter = LatLng(-7.0503, 110.4370);

  @override
  void didUpdateWidget(covariant TrackingMapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fitCameraToMarkers();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markers = _buildMarkers();

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
                target: markers.first.position,
                zoom: 14,
              ),
              markers: markers,
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
              onMapCreated: (controller) {
                _mapController = controller;
                _fitCameraToMarkers();
              },
            ),
            Positioned(top: 10, left: 10, right: 10, child: _buildTopHint()),
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

    if (widget.pickupLatitude != null && widget.pickupLongitude != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(widget.pickupLatitude!, widget.pickupLongitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'Titik Pickup'),
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
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: const InfoWindow(title: 'Posisi Driver'),
        ),
      );
    }

    return markers;
  }

  Future<void> _fitCameraToMarkers() async {
    final controller = _mapController;
    if (controller == null || !mounted) {
      return;
    }

    final points = <LatLng>[];

    if (widget.pickupLatitude != null && widget.pickupLongitude != null) {
      points.add(LatLng(widget.pickupLatitude!, widget.pickupLongitude!));
    }
    if (widget.dropoffLatitude != null && widget.dropoffLongitude != null) {
      points.add(LatLng(widget.dropoffLatitude!, widget.dropoffLongitude!));
    }
    if (widget.driverLatitude != null && widget.driverLongitude != null) {
      points.add(LatLng(widget.driverLatitude!, widget.driverLongitude!));
    }

    if (points.isEmpty) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(_fallbackCenter, 12),
      );
      return;
    }

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

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 64));
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
}
