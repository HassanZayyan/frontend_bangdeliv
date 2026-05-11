import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_colors.dart';
import '../config/app_env.dart';
import '../models/route_location_picker_result.dart';

class RouteLocationPickerScreen extends StatefulWidget {
  const RouteLocationPickerScreen({super.key, required this.args});

  final RouteLocationPickerArgs args;

  @override
  State<RouteLocationPickerScreen> createState() =>
      _RouteLocationPickerScreenState();
}

class _RouteLocationPickerScreenState extends State<RouteLocationPickerScreen> {
  static const LatLng _fallbackCenter = LatLng(-7.3294948, 110.5080427);

  GoogleMapController? _mapController;
  late LatLng _cameraTarget;
  late double _initialZoom;
  late String _activeTarget;
  _RoutePoint? _pickupPoint;
  _RoutePoint? _destinationPoint;
  bool _isDestinationMapVisible = false;
  bool _pickupChanged = false;
  bool _isResolvingCurrentLocation = false;
  bool _showLocationButtonLoading = false;
  bool _isSavingManualDestination = false;
  int _mapAddressRequestId = 0;
  String? _mapCenterAddress;
  bool _isLocationPermissionGranted = false;
  String? _statusHint;

  String get _pickupTarget => widget.args.pickupTarget;
  String get _destinationTarget => widget.args.destinationTarget;

  @override
  void initState() {
    super.initState();

    final pickupInitial = _validLatLng(
      widget.args.pickupInitialLatitude ?? widget.args.defaultPickupLatitude,
      widget.args.pickupInitialLongitude ?? widget.args.defaultPickupLongitude,
    );
    final destinationInitial = _validLatLng(
      widget.args.destinationInitialLatitude,
      widget.args.destinationInitialLongitude,
    );

    if (pickupInitial != null) {
      _pickupPoint = _RoutePoint(
        target: _pickupTarget,
        latitude: pickupInitial.latitude,
        longitude: pickupInitial.longitude,
        address: widget.args.defaultPickupAddress,
        source: 'profile_default',
      );
    }
    if (destinationInitial != null) {
      _destinationPoint = _RoutePoint(
        target: _destinationTarget,
        latitude: destinationInitial.latitude,
        longitude: destinationInitial.longitude,
        source: 'map_pin',
      );
    }

    _activeTarget = pickupInitial != null
        ? _destinationTarget
        : (destinationInitial != null ? _destinationTarget : _pickupTarget);
    _cameraTarget = pickupInitial ?? destinationInitial ?? _fallbackCenter;
    _initialZoom = (pickupInitial ?? destinationInitial) == null ? 13.0 : 17.0;

    if (destinationInitial == null && pickupInitial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _moveToCurrentLocation();
      });
    }
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      if (mounted) {
        setState(() => _isLocationPermissionGranted = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAddress = _activePoint?.displayAddress;
    final displayAddress =
        activeAddress ??
        (_isManualDestinationSelectionMode ? _mapCenterAddress : null);
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final showMapPanel = _shouldShowMap && !keyboardOpen;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.args.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: _pickupTarget,
                    label: Text(widget.args.pickupLabel),
                    icon: const Icon(Icons.trip_origin, size: 18),
                  ),
                  ButtonSegment(
                    value: _destinationTarget,
                    label: Text(widget.args.destinationLabel),
                    icon: const Icon(Icons.location_on_outlined, size: 18),
                  ),
                ],
                selected: {_activeTarget},
                onSelectionChanged: (selection) {
                  _selectTarget(selection.first);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SearchAnchor(
                builder: (BuildContext context, SearchController controller) {
                  return SearchBar(
                    controller: controller,
                    padding: const WidgetStatePropertyAll<EdgeInsets>(
                      EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onTap: controller.openView,
                    onChanged: (_) => controller.openView(),
                    onSubmitted: (value) async {
                      final query = value.trim();
                      if (query.isEmpty) return;
                      controller.closeView(query);
                      await _goToPlace(fallbackQuery: query);
                      FocusManager.instance.primaryFocus?.unfocus();
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
                      final results = await _searchPlaces(query);
                      return results.map((prediction) {
                        return ListTile(
                          leading: const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                          ),
                          title: Text(prediction['description']),
                          onTap: () async {
                            controller.closeView(prediction['description']);
                            await _goToPlace(
                              placeId: prediction['place_id']?.toString(),
                              fallbackQuery: prediction['description']?.toString(),
                            );
                            FocusManager.instance.primaryFocus?.unfocus();
                          },
                        );
                      });
                    },
              ),
            ),
            if (!showMapPanel) const SizedBox(height: 12),
            if (showMapPanel)
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
                          markers: _markers(),
                          onMapCreated: (controller) {
                            _mapController = controller;
                          },
                          onCameraMove: (position) {
                            _cameraTarget = position.target;
                            if (_isMapSelectionActive &&
                                _mapCenterAddress != null) {
                              setState(() => _mapCenterAddress = null);
                            }
                          },
                          onCameraIdle: _handleMapCameraIdle,
                        ),
                        IgnorePointer(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 44),
                              child: Icon(
                                _activeTarget == _pickupTarget
                                    ? Icons.trip_origin
                                    : Icons.location_pin,
                                color: _activeTarget == _pickupTarget
                                    ? AppColors.success
                                    : AppColors.error,
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
            if (showMapPanel)
              _buildBottomSection(displayAddress, showMapPanel: showMapPanel)
            else
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: _buildBottomSection(
                    displayAddress,
                    showMapPanel: showMapPanel,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection(
    String? activeAddress, {
    required bool showMapPanel,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        showMapPanel ? 0 : 4,
        16,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPointSummary(),
          const SizedBox(height: 12),
          if (showMapPanel)
            Text(
              'Peta aktif: ${_activeTarget == _pickupTarget ? widget.args.pickupLabel : widget.args.destinationLabel}',
              key: const Key('route_picker_active_label'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            )
          else
            const Text(
              'Pilih tujuan dari pencarian atau pilih lewat peta.',
              key: Key('route_picker_hidden_map_hint'),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          if ((activeAddress ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              activeAddress!,
              key: const Key('route_picker_active_address'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          if ((_statusHint ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _statusHint!,
              key: const Key('route_picker_status_hint'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _handleLocationButtonPressed,
              icon: _showLocationButtonLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isDestinationMapEntryMode
                          ? Icons.map_outlined
                          : Icons.my_location,
                      size: 18,
                    ),
              label: Text(
                _isDestinationMapEntryMode ? 'Pilih lewat peta' : 'Lokasi Saya',
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!_canConfirmRoute) ...[
            Text(
              _isManualDestinationSelectionMode
                  ? 'Geser peta lalu pilih "Gunakan titik ini" untuk menetapkan ${widget.args.destinationLabel}.'
                  : 'Pilih ${widget.args.destinationLabel} terlebih dahulu agar rute bisa disimpan.',
              key: const Key('route_picker_confirm_hint'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _canConfirmRoute
                  ? _confirmRoute
                  : (_isManualDestinationSelectionMode &&
                            !_isSavingManualDestination
                        ? _saveDestinationFromMapCenter
                        : null),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.border,
                disabledForegroundColor: AppColors.textSecondary,
                elevation: 0,
                padding: EdgeInsets.zero,
                alignment: Alignment.center,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _canConfirmRoute
                    ? widget.args.confirmLabel
                    : (_isManualDestinationSelectionMode
                          ? 'Gunakan titik ini'
                          : 'Pilih ${widget.args.destinationLabel}'),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointSummary() {
    return Row(
      children: [
        Expanded(
          child: _PointCard(
            label: widget.args.pickupLabel,
            point: _pickupPoint,
            isActive: _activeTarget == _pickupTarget,
            color: AppColors.success,
            onTap: () => _selectTarget(_pickupTarget),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PointCard(
            label: widget.args.destinationLabel,
            point: _destinationPoint,
            isActive: _activeTarget == _destinationTarget,
            color: AppColors.primary,
            onTap: () => _selectTarget(_destinationTarget),
          ),
        ),
      ],
    );
  }

  _RoutePoint? get _activePoint =>
      _activeTarget == _pickupTarget ? _pickupPoint : _destinationPoint;

  bool get _shouldShowMap {
    if (_activeTarget == _pickupTarget) {
      return _pickupPoint != null;
    }
    return _destinationPoint != null || _isDestinationMapVisible;
  }

  bool get _canConfirmRoute => _pickupPoint != null && _destinationPoint != null;

  bool get _isManualDestinationSelectionMode =>
      _activeTarget == _destinationTarget &&
      _shouldShowMap &&
      _destinationPoint == null;

  bool get _isMapSelectionActive => _shouldShowMap;

  bool get _isDestinationMapEntryMode =>
      _activeTarget == _destinationTarget && !_shouldShowMap;

  void _selectTarget(String target) {
    if (target != _pickupTarget && target != _destinationTarget) {
      return;
    }

    setState(() {
      _activeTarget = target;
      _statusHint = null;
      if (target != _destinationTarget) {
        _mapCenterAddress = null;
      }
    });
    _focusSelectedPoint(target);
  }

  Set<Marker> _markers() {
    final markers = <Marker>{};
    final pickup = _pickupPoint;
    final destination = _destinationPoint;
    if (pickup != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(pickup.latitude, pickup.longitude),
          infoWindow: InfoWindow(title: widget.args.pickupLabel),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }
    if (destination != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(destination.latitude, destination.longitude),
          infoWindow: InfoWindow(title: widget.args.destinationLabel),
        ),
      );
    }
    return markers;
  }

  Future<void> _focusSelectedPoint(String target) async {
    final point = target == _pickupTarget ? _pickupPoint : _destinationPoint;
    if (point == null) return;

    final latLng = LatLng(point.latitude, point.longitude);
    _cameraTarget = latLng;
    await _animateCameraSafely(latLng, 17);
  }

  Future<void> _handleMapCameraIdle() async {
    if (!mounted) return;
    if (!_isMapSelectionActive || _isResolvingCurrentLocation) {
      setState(() {});
      return;
    }

    final requestId = ++_mapAddressRequestId;
    final target = _cameraTarget;

    setState(() {
      _statusHint = 'Mencari alamat titik peta...';
    });

    final address = await _reverseGeocode(target);
    if (!mounted || requestId != _mapAddressRequestId) return;

    if (_activePoint != null) {
      _cameraTarget = target;
      _saveActivePoint('map_pin', address: address);
    }

    setState(() {
      _mapCenterAddress = address;
      _statusHint = address == null
          ? 'Alamat belum ditemukan, kamu tetap bisa gunakan titik ini.'
          : null;
    });
  }

  Future<void> _moveToCurrentLocation() async {
    if (_isResolvingCurrentLocation) return;

    final showButtonLoading = !_isDestinationMapEntryMode;
    setState(() {
      _isResolvingCurrentLocation = true;
      _showLocationButtonLoading = showButtonLoading;
      _statusHint = null;
      if (_activeTarget == _destinationTarget && _destinationPoint == null) {
        // Show map instantly for destination flow while GPS resolves.
        _isDestinationMapVisible = true;
      }
    });

    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        _showMessage(
          'Layanan lokasi belum aktif. Aktifkan GPS lalu coba lagi.',
        );
        setState(() {
          _statusHint = 'GPS belum aktif, pilih titik manual di peta.';
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
          _statusHint = 'Izin lokasi ditolak, pilih titik manual di peta.';
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage('Izin lokasi ditolak permanen. Aktifkan dari pengaturan.');
        await Geolocator.openAppSettings();
        return;
      }

      if (!_isLocationPermissionGranted && mounted) {
        setState(() => _isLocationPermissionGranted = true);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final target = LatLng(position.latitude, position.longitude);
      _cameraTarget = target;
      await _animateCameraSafely(target, 18);
      final address = await _reverseGeocode(target);
      if (!mounted) return;

      _saveActivePoint('gps', address: address);
      setState(() {
        _statusHint = address == null
            ? 'Titik dipilih di peta untuk ${_activeLabelLower()}.'
            : null;
      });
    } catch (_) {
      _showMessage('Gagal mengambil lokasi saat ini. Coba lagi.');
      setState(() {
        _statusHint = 'Lokasi tidak tersedia, pilih titik manual di peta.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingCurrentLocation = false;
          _showLocationButtonLoading = false;
        });
      }
    }
  }

  void _handleLocationButtonPressed() {
    _moveToCurrentLocation();
  }

  Future<void> _saveDestinationFromMapCenter() async {
    if (_isSavingManualDestination || _activeTarget != _destinationTarget) return;

    final manualTarget = _cameraTarget;
    setState(() => _isSavingManualDestination = true);

    try {
      final address = _mapCenterAddress ?? await _reverseGeocode(manualTarget);
      if (!mounted) return;

      _cameraTarget = manualTarget;
      _saveActivePoint('map_pin', address: address);
      setState(() => _statusHint = null);
    } finally {
      if (mounted) {
        setState(() => _isSavingManualDestination = false);
      }
    }
  }

  void _saveActivePoint(String source, {String? address}) {
    final cleanedAddress = _cleanAddress(address);
    final point = _RoutePoint(
      target: _activeTarget,
      latitude: _cameraTarget.latitude,
      longitude: _cameraTarget.longitude,
      address: cleanedAddress,
      source: source,
    );

    setState(() {
      if (_activeTarget == _pickupTarget) {
        _pickupPoint = point;
        _pickupChanged = true;
      } else {
        _destinationPoint = point;
        _mapCenterAddress = null;
      }
    });
  }

  void _confirmRoute() {
    final pickup = _pickupPoint;
    final destination = _destinationPoint;
    if (pickup == null) {
      _showMessage('${widget.args.pickupLabel} belum dipilih.');
      setState(() => _activeTarget = _pickupTarget);
      return;
    }
    if (destination == null) {
      _showMessage('${widget.args.destinationLabel} belum dipilih.');
      setState(() => _activeTarget = _destinationTarget);
      return;
    }

    final hasDefaultPickup =
        _validLatLng(
          widget.args.defaultPickupLatitude,
          widget.args.defaultPickupLongitude,
        ) !=
        null;

    final locations = <RouteLocationPickerPoint>[
      if (_pickupChanged || !hasDefaultPickup)
        RouteLocationPickerPoint(
          target: pickup.target,
          latitude: pickup.latitude,
          longitude: pickup.longitude,
          address: pickup.address,
          source: pickup.source,
        ),
      RouteLocationPickerPoint(
        target: destination.target,
        latitude: destination.latitude,
        longitude: destination.longitude,
        address: destination.address,
        source: destination.source,
      ),
    ];

    context.pop(RouteLocationPickerResult(locations: locations));
  }

  Future<List<Map<String, dynamic>>> _searchPlaces(String query) async {
    if (query.isEmpty) return [];
    final apiKey = AppEnv.googleMapsApiKey.trim();
    if (apiKey.isEmpty) return [];

    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      <String, String>{
        'input': query,
        'key': apiKey,
        'components': 'country:id',
        'language': 'id',
      },
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return List<Map<String, dynamic>>.from(data['predictions']);
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> _goToPlace({String? placeId, String? fallbackQuery}) async {
    final apiKey = AppEnv.googleMapsApiKey.trim();
    if (apiKey.isEmpty) {
      _showMessage('Google Maps API key belum dikonfigurasi.');
      return;
    }

    var isResolved = false;

    if ((placeId ?? '').isNotEmpty) {
      final placeDetailsUrl = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        <String, String>{
          'place_id': placeId!,
          'key': apiKey,
          'language': 'id',
        },
      );

      try {
        final response = await http.get(placeDetailsUrl);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is Map<String, dynamic> && data['status'] == 'OK') {
            final result = data['result'];
            if (result is Map<String, dynamic>) {
              final geometry = result['geometry'];
              final location = geometry is Map<String, dynamic>
                  ? geometry['location']
                  : null;
              final lat = location is Map<String, dynamic>
                  ? location['lat']
                  : null;
              final lng = location is Map<String, dynamic>
                  ? location['lng']
                  : null;
              if (lat is num && lng is num) {
                await _applyPlaceSelection(
                  LatLng(lat.toDouble(), lng.toDouble()),
                  address:
                      _cleanAddress(result['formatted_address']) ??
                      _cleanAddress(result['name']) ??
                      _cleanAddress(fallbackQuery),
                );
                isResolved = true;
              }
            }
          }
        }
      } catch (_) {}
    }

    if (!isResolved && (fallbackQuery ?? '').isNotEmpty) {
      final geocoded = await _geocodePlaceQuery(fallbackQuery!, apiKey);
      if (geocoded != null) {
        final target = geocoded['target'];
        if (target is LatLng) {
          await _applyPlaceSelection(
            target,
            address:
                _cleanAddress(geocoded['address']) ?? _cleanAddress(fallbackQuery),
          );
          isResolved = true;
        }
      }
    }

    if (!isResolved) {
      _showMessage('Gagal mengambil detail lokasi.');
    }
  }

  Future<void> _applyPlaceSelection(LatLng target, {String? address}) async {
    _cameraTarget = target;
    await _animateCameraSafely(target, 18);
    _saveActivePoint('search', address: address);
    if (mounted) {
      setState(() => _statusHint = null);
    }
  }

  Future<void> _animateCameraSafely(LatLng target, double zoom) async {
    final controller = _mapController;
    if (controller == null) return;

    try {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
    } catch (_) {
      // Map can be temporarily unmounted (hidden state). Ignore stale controller.
      _mapController = null;
    }
  }

  Future<Map<String, dynamic>?> _geocodePlaceQuery(
    String query,
    String apiKey,
  ) async {
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      <String, String>{'address': query, 'key': apiKey, 'language': 'id'},
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      if (data is! Map<String, dynamic> || data['status'] != 'OK') return null;

      final results = data['results'];
      if (results is! List || results.isEmpty) return null;

      final first = results.first;
      if (first is! Map<String, dynamic>) return null;

      final geometry = first['geometry'];
      final location = geometry is Map<String, dynamic>
          ? geometry['location']
          : null;
      final lat = location is Map<String, dynamic> ? location['lat'] : null;
      final lng = location is Map<String, dynamic> ? location['lng'] : null;
      if (lat is! num || lng is! num) return null;

      return <String, dynamic>{
        'target': LatLng(lat.toDouble(), lng.toDouble()),
        'address': _cleanAddress(first['formatted_address']),
      };
    } catch (_) {
      return null;
    }
  }

  Future<String?> _reverseGeocode(LatLng target) async {
    final apiKey = AppEnv.googleMapsApiKey.trim();
    if (apiKey.isEmpty) return null;

    final url = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', <
      String,
      String
    >{
      'latlng':
          '${target.latitude.toStringAsFixed(6)},${target.longitude.toStringAsFixed(6)}',
      'key': apiKey,
      'language': 'id',
    });

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      if (data['status'] != 'OK') return null;

      final results = data['results'];
      if (results is! List || results.isEmpty) return null;

      final first = results.first;
      if (first is! Map<String, dynamic>) return null;

      return _cleanAddress(first['formatted_address']);
    } catch (_) {
      return null;
    }
  }

  String? _cleanAddress(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    if (RegExp(r'^pin\s+-?\d', caseSensitive: false).hasMatch(text)) {
      return null;
    }
    return text;
  }

  String _activeLabelLower() {
    if (_activeTarget == _pickupTarget) {
      return widget.args.pickupLabel.toLowerCase();
    }
    return widget.args.destinationLabel.toLowerCase();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.black87),
    );
  }

  LatLng? _validLatLng(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return null;
    if (latitude < -90 || latitude > 90) return null;
    if (longitude < -180 || longitude > 180) return null;
    if (latitude == 0 && longitude == 0) return null;
    return LatLng(latitude, longitude);
  }
}

class _PointCard extends StatelessWidget {
  const _PointCard({
    required this.label,
    required this.point,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  final String label;
  final _RoutePoint? point;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final point = this.point;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 84,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.08) : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : AppColors.border,
            width: isActive ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive ? color : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              point == null ? 'Belum dipilih' : point.displayAddress,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutePoint {
  const _RoutePoint({
    required this.target,
    required this.latitude,
    required this.longitude,
    required this.source,
    this.address,
  });

  final String target;
  final double latitude;
  final double longitude;
  final String source;
  final String? address;

  String get displayAddress {
    final normalized = address?.trim();
    if (normalized == null || normalized.isEmpty) {
      return 'Titik dipilih di peta';
    }
    return normalized;
  }
}
