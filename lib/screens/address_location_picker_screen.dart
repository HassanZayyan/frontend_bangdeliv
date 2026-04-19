import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/app_colors.dart';
import '../models/address_location_picker_result.dart';

class AddressLocationPickerScreen extends StatefulWidget {
  const AddressLocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<AddressLocationPickerScreen> createState() =>
      _AddressLocationPickerScreenState();
}

class _AddressLocationPickerScreenState extends State<AddressLocationPickerScreen> {
  static const LatLng _fallbackCenter = LatLng(-7.0503, 110.4370);

  GoogleMapController? _mapController;
  late LatLng _cameraTarget;
  bool _isResolvingCurrentLocation = false;
  String? _locationHint;
  String _selectedSource = 'map_pin';

  @override
  void initState() {
    super.initState();

    final hasInitialCoordinate = widget.initialLatitude != null &&
        widget.initialLongitude != null &&
        widget.initialLatitude! >= -90 &&
        widget.initialLatitude! <= 90 &&
        widget.initialLongitude! >= -180 &&
        widget.initialLongitude! <= 180;

    _cameraTarget = hasInitialCoordinate
        ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
        : _fallbackCenter;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Pilih Titik Alamat',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _cameraTarget,
                          zoom: 17,
                        ),
                        myLocationButtonEnabled: false,
                        mapToolbarEnabled: false,
                        zoomControlsEnabled: false,
                        compassEnabled: true,
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        onCameraMove: (position) {
                          _cameraTarget = position.target;
                          if (!_isResolvingCurrentLocation) {
                            _selectedSource = 'map_pin';
                          }
                        },
                        onCameraIdle: () {
                          if (!mounted) {
                            return;
                          }
                          setState(() {});
                        },
                      ),
                      const IgnorePointer(
                        child: Center(
                          child: Icon(
                            Icons.location_pin,
                            color: AppColors.error,
                            size: 44,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            'Geser peta sampai pin merah tepat di lokasi rumahmu.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Koordinat terpilih: ${_cameraTarget.latitude.toStringAsFixed(6)}, ${_cameraTarget.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if ((_locationHint ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _locationHint!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isResolvingCurrentLocation
                              ? null
                              : _moveToCurrentLocation,
                          icon: _isResolvingCurrentLocation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location),
                          label: const Text('Pakai Lokasi Saya'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _confirmSelection,
                          child: const Text('Konfirmasi Titik'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() {
      _isResolvingCurrentLocation = true;
      _locationHint = null;
    });

    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        _showMessage('Layanan lokasi belum aktif. Aktifkan GPS lalu coba lagi.');
        setState(() {
          _locationHint = 'GPS belum aktif, kamu tetap bisa memilih titik dengan drag peta.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showMessage('Izin lokasi ditolak. Pilih titik manual di peta.');
        setState(() {
          _locationHint = 'Izin lokasi ditolak, gunakan drag peta untuk memilih titik.';
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage('Izin lokasi ditolak permanen. Buka pengaturan untuk mengaktifkannya.');
        await Geolocator.openAppSettings();
        setState(() {
          _locationHint =
              'Izin lokasi ditolak permanen, kamu bisa lanjut pilih titik manual.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final target = LatLng(position.latitude, position.longitude);
      _cameraTarget = target;

      final controller = _mapController;
      if (controller != null) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(target, 18),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _locationHint = 'Lokasi saat ini berhasil digunakan sebagai titik awal.';
        _selectedSource = 'gps';
      });
    } catch (_) {
      _showMessage('Gagal mengambil lokasi saat ini. Coba lagi atau pilih titik manual.');
      setState(() {
        _locationHint = 'Lokasi tidak tersedia, kamu tetap bisa drag peta untuk memilih titik.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingCurrentLocation = false;
        });
      }
    }
  }

  void _confirmSelection() {
    context.pop(
      AddressLocationPickerResult(
        latitude: _cameraTarget.latitude,
        longitude: _cameraTarget.longitude,
        source: _selectedSource,
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black87,
      ),
    );
  }
}
