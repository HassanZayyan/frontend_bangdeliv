import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../config/app_colors.dart';
import '../../../../models/address_location_picker_result.dart';
import '../../../../services/google_maps_lookup_service.dart';

class AddressLocationPickerScreen extends StatefulWidget {
  const AddressLocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.restrictAddressSearchToServiceArea = false,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final bool restrictAddressSearchToServiceArea;

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
  String _selectedSource = 'map_pin';
  bool _isLocationPermissionGranted = false;
  int _addressRequestId = 0;
  String? _selectedAddress;
  bool _isResolvingAddress = false;

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
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolveSelectedAddress(_cameraTarget);
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

  String get _selectedAddressText {
    final address = (_selectedAddress ?? '').trim();
    if (address.isNotEmpty) {
      return address;
    }

    if (_isResolvingAddress || _isResolvingCurrentLocation) {
      return 'Mengambil detail alamat...';
    }

    return 'Detail alamat belum tersedia. Geser peta atau cari alamat.';
  }

  GoogleMapsLookupScope get _addressSearchScope =>
      widget.restrictAddressSearchToServiceArea
      ? GoogleMapsLookupScope.salatigaServiceAreaAddress
      : GoogleMapsLookupScope.indonesia;

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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildSearchBar(),
            ),
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
                        onCameraIdle: _handleCameraIdle,
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
                  SizedBox(
                    height: 54,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        _selectedAddressText,
                        key: ValueKey(_selectedAddressText),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _selectedAddress == null
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
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
                            label: const Text('Lokasi Saya'),
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
                              'Simpan',
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

  Widget _buildSearchBar() {
    return SearchAnchor(
      viewBackgroundColor: AppColors.white,
      viewSurfaceTintColor: AppColors.white,
      builder: (BuildContext context, SearchController controller) {
        return SearchBar(
          controller: controller,
          padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: 16),
          ),
          onTap: controller.openView,
          onChanged: (_) => controller.openView(),
          leading: const Icon(Icons.search),
          hintText: 'Cari alamat / lokasi...',
          hintStyle: const WidgetStatePropertyAll(
            TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.border),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          backgroundColor: WidgetStatePropertyAll(
            AppColors.white.withValues(alpha: 0.95),
          ),
          elevation: const WidgetStatePropertyAll(1),
        );
      },
      suggestionsBuilder:
          (BuildContext context, SearchController controller) async {
            final query = controller.text;
            if (query.isEmpty) {
              return const Iterable<Widget>.empty();
            }
            final results = await _mapsLookup.searchPlaces(
              query,
              scope: _addressSearchScope,
            );
            return results.map((prediction) {
              return ListTile(
                leading: const Icon(
                  Icons.location_on,
                  color: AppColors.primary,
                ),
                title: Text(prediction.description),
                onTap: () {
                  controller.closeView(prediction.description);
                  _goToPlace(prediction.placeId);
                },
              );
            });
          },
    );
  }

  Future<void> _handleCameraIdle() async {
    if (!mounted) {
      return;
    }

    if (_isResolvingCurrentLocation) {
      setState(() {});
      return;
    }

    await _resolveSelectedAddress(_cameraTarget);
  }

  Future<void> _resolveSelectedAddress(
    LatLng target, {
    String? preferredAddress,
  }) async {
    if (!mounted) {
      return;
    }

    final cleanedPreferred = _mapsLookup.cleanAddress(preferredAddress);
    final requestId = ++_addressRequestId;

    setState(() {
      _isResolvingAddress = cleanedPreferred == null;
      _selectedAddress = cleanedPreferred;
    });

    if (cleanedPreferred != null) {
      setState(() {
        _isResolvingAddress = false;
      });
      return;
    }

    final resolvedAddress = await _mapsLookup.reverseGeocode(target);
    if (!mounted || requestId != _addressRequestId) {
      return;
    }

    setState(() {
      _selectedAddress = _mapsLookup.cleanAddress(resolvedAddress);
      _isResolvingAddress = false;
    });
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() {
      _isResolvingCurrentLocation = true;
      _isResolvingAddress = true;
    });

    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        _showMessage(
          'Layanan lokasi belum aktif. Aktifkan GPS lalu coba lagi.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showMessage('Izin lokasi ditolak. Pilih titik manual di peta.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          'Izin lokasi ditolak permanen. Buka pengaturan untuk mengaktifkannya.',
        );
        await Geolocator.openAppSettings();
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
        _selectedSource = 'gps';
      });
      await _resolveSelectedAddress(target);
    } catch (_) {
      _showMessage(
        'Gagal mengambil lokasi saat ini. Coba lagi atau pilih titik manual.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingCurrentLocation = false;
          _isResolvingAddress = false;
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

    final resolved = await _mapsLookup.resolvePlace(
      placeId: placeId,
      scope: _addressSearchScope,
    );
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
    });
    await _resolveSelectedAddress(
      resolved.target,
      preferredAddress: resolved.address,
    );
  }
}
