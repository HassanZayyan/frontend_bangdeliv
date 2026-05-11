import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/app_colors.dart';
import '../models/address_location_picker_result.dart';
import '../services/google_maps_lookup_service.dart';

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

class _AddressLocationPickerScreenState
    extends State<AddressLocationPickerScreen> {
  static const LatLng _fallbackCenter = LatLng(-7.3294948, 110.5080427);

  GoogleMapController? _mapController;
  final _mapsLookup = const GoogleMapsLookupService();
  late LatLng _cameraTarget;
  late double _initialZoom;
  bool _isResolvingCurrentLocation = false;
  String? _locationHint;
  String _selectedSource = 'map_pin';
  bool _isLocationPermissionGranted = false;

  @override
  void initState() {
    super.initState();

    final hasInitialCoordinate =
        widget.initialLatitude != null &&
        widget.initialLongitude != null &&
        widget.initialLatitude! >= -90 &&
        widget.initialLatitude! <= 90 &&
        widget.initialLongitude! >= -180 &&
        widget.initialLongitude! <= 180;

    _cameraTarget = hasInitialCoordinate
        ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
        : _fallbackCenter;

    _initialZoom = hasInitialCoordinate ? 17.0 : 13.0;

    if (!hasInitialCoordinate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _moveToCurrentLocation();
      });
    }

    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      if (mounted) {
        setState(() {
          _isLocationPermissionGranted = true;
        });
      }
    }
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
                          zoom: _initialZoom,
                        ),
                        myLocationEnabled: _isLocationPermissionGranted,
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
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 44.0),
                            child: Icon(
                              Icons.location_pin,
                              color: AppColors.error,
                              size: 44,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        top: 12,
                        child: SearchAnchor(
                          builder:
                              (
                                BuildContext context,
                                SearchController controller,
                              ) {
                                return SearchBar(
                                  controller: controller,
                                  padding:
                                      const WidgetStatePropertyAll<EdgeInsets>(
                                        EdgeInsets.symmetric(horizontal: 16.0),
                                      ),
                                  onTap: () {
                                    controller.openView();
                                  },
                                  onChanged: (_) {
                                    controller.openView();
                                  },
                                  leading: const Icon(Icons.search),
                                  hintText: 'Cari alamat / lokasi...',
                                  backgroundColor: WidgetStatePropertyAll(
                                    AppColors.white.withValues(alpha: 0.95),
                                  ),
                                  elevation: const WidgetStatePropertyAll(2),
                                );
                              },
                          suggestionsBuilder:
                              (
                                BuildContext context,
                                SearchController controller,
                              ) async {
                                final query = controller.text;
                                if (query.isEmpty) {
                                  return const Iterable<Widget>.empty();
                                }
                                final results = await _mapsLookup.searchPlaces(
                                  query,
                                );
                                return results.map((prediction) {
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.location_on,
                                      color: AppColors.primary,
                                    ),
                                    title: Text(prediction.description),
                                    onTap: () {
                                      controller.closeView(
                                        prediction.description,
                                      );
                                      _goToPlace(prediction.placeId);
                                    },
                                  );
                                });
                              },
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
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _isResolvingCurrentLocation
                                ? null
                                : _moveToCurrentLocation,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: AppColors.border),
                              foregroundColor: AppColors.textPrimary,
                            ),
                            icon: _isResolvingCurrentLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location, size: 18),
                            label: const Text('Pakai Lokasi Saat Ini'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _confirmSelection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Konfirmasi',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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
        _showMessage(
          'Layanan lokasi belum aktif. Aktifkan GPS lalu coba lagi.',
        );
        setState(() {
          _locationHint =
              'GPS belum aktif, kamu tetap bisa memilih titik dengan drag peta.';
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
          _locationHint =
              'Izin lokasi ditolak, gunakan drag peta untuk memilih titik.';
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          'Izin lokasi ditolak permanen. Buka pengaturan untuk mengaktifkannya.',
        );
        await Geolocator.openAppSettings();
        setState(() {
          _locationHint =
              'Izin lokasi ditolak permanen, kamu bisa lanjut pilih titik manual.';
        });
        return;
      }

      if (!_isLocationPermissionGranted && mounted) {
        setState(() {
          _isLocationPermissionGranted = true;
        });
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
        await controller.animateCamera(CameraUpdate.newLatLngZoom(target, 18));
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _locationHint =
            'Lokasi saat ini berhasil digunakan sebagai titik awal.';
        _selectedSource = 'gps';
      });
    } catch (_) {
      _showMessage(
        'Gagal mengambil lokasi saat ini. Coba lagi atau pilih titik manual.',
      );
      setState(() {
        _locationHint =
            'Lokasi tidak tersedia, kamu tetap bisa drag peta untuk memilih titik.';
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
      SnackBar(content: Text(message), backgroundColor: Colors.black87),
    );
  }

  Future<void> _goToPlace(String? placeId) async {
    if (!_mapsLookup.isConfigured) {
      _showMessage('Google Maps API key belum dikonfigurasi.');
      return;
    }

    final resolved = await _mapsLookup.resolvePlace(placeId: placeId);
    if (resolved == null) {
      _showMessage('Gagal mengambil detail lokasi.');
      return;
    }

    _cameraTarget = resolved.target;

    final controller = _mapController;
    if (controller != null) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(resolved.target, 18),
      );
    }

    if (!mounted) return;
    setState(() {
      _selectedSource = 'search';
      _locationHint = resolved.address ?? 'Lokasi ditemukan.';
    });
  }
}
