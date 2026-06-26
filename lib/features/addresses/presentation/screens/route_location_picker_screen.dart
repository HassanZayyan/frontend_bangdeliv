import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../models/route_location_picker_result.dart';
import '../../../../services/google_maps_lookup_service.dart';
import '../../../../utils/map_picker_helpers.dart';

class RouteLocationPickerScreen extends StatefulWidget {
  const RouteLocationPickerScreen({super.key, required this.args});

  final RouteLocationPickerArgs args;

  @override
  State<RouteLocationPickerScreen> createState() =>
      _RouteLocationPickerScreenState();
}

class _RouteLocationPickerScreenState extends State<RouteLocationPickerScreen> {
  static const LatLng _fallbackCenter = LatLng(
    -7.319916770351389,
    110.46393594806243,
  );
  static const _routeSearchRadiusMeters = 50000;
  static const _routeSearchMaxResults = 8;
  static const double _minimumRouteDistanceMeters = 20;
  static const String _routeTooCloseMessage =
      'Titik tujuan terlalu dekat dengan titik jemput. Pilih titik tujuan yang berbeda.';
  static const _bodyHintStyle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    height: 1.35,
  );
  static const _activeAddressStyle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  GoogleMapController? _mapController;
  final SearchController _searchController = SearchController();
  final _mapsLookup = const GoogleMapsLookupService();
  late LatLng _cameraTarget;
  LatLng? _currentUserLocation;
  late double _initialZoom;
  late String _activeTarget;
  String? _pendingMapSelectionTarget;
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
  bool _skipNextCameraIdleGeocode = false;

  String get _pickupTarget => widget.args.pickupTarget;
  String get _destinationTarget => widget.args.destinationTarget;
  LatLng get _searchOriginTarget => _currentUserLocation ?? _cameraTarget;

  @override
  void initState() {
    super.initState();

    final pickupInitial = MapPickerHelpers.validLatLng(
      widget.args.pickupInitialLatitude ?? widget.args.defaultPickupLatitude,
      widget.args.pickupInitialLongitude ?? widget.args.defaultPickupLongitude,
    );
    final hasExplicitPickupInitial =
        widget.args.pickupInitialLatitude != null &&
        widget.args.pickupInitialLongitude != null;
    final destinationInitial = MapPickerHelpers.validLatLng(
      widget.args.destinationInitialLatitude,
      widget.args.destinationInitialLongitude,
    );
    final hasExplicitDestinationInitial =
        widget.args.destinationInitialLatitude != null &&
        widget.args.destinationInitialLongitude != null;

    if (pickupInitial != null) {
      final pickupInitialAddress =
          _mapsLookup.cleanAddress(widget.args.pickupInitialAddress) ??
          (hasExplicitPickupInitial
              ? null
              : _mapsLookup.cleanAddress(widget.args.defaultPickupAddress));
      _pickupPoint = _RoutePoint(
        target: _pickupTarget,
        latitude: pickupInitial.latitude,
        longitude: pickupInitial.longitude,
        address: pickupInitialAddress,
        source: hasExplicitPickupInitial ? 'existing_route' : 'profile_default',
      );
    }
    if (destinationInitial != null) {
      _destinationPoint = _RoutePoint(
        target: _destinationTarget,
        latitude: destinationInitial.latitude,
        longitude: destinationInitial.longitude,
        address: _mapsLookup.cleanAddress(
          widget.args.destinationInitialAddress,
        ),
        source: hasExplicitDestinationInitial ? 'existing_route' : 'map_pin',
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateInitialRouteAddresses();
    });
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    final isGranted = await MapPickerHelpers.hasLocationPermission();
    LatLng? currentLocation;
    if (isGranted) {
      try {
        currentLocation = await MapPickerHelpers.currentLocationIfPermitted();
      } catch (_) {
        currentLocation = null;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLocationPermissionGranted = isGranted;
      if (currentLocation != null) {
        _currentUserLocation = currentLocation;
      }
    });
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SearchAnchor(
                searchController: _searchController,
                viewBackgroundColor: AppColors.white,
                viewSurfaceTintColor: AppColors.white,
                builder: (BuildContext context, SearchController controller) {
                  final fieldFontSize = AppTextScaling.adaptive(
                    context,
                    normal: 14,
                    large: 13.25,
                  );

                  return SearchBar(
                    controller: controller,
                    constraints: const BoxConstraints(minHeight: 50),
                    padding: const WidgetStatePropertyAll<EdgeInsets>(
                      EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onTap: controller.openView,
                    onChanged: (_) => controller.openView(),
                    onSubmitted: (value) async {
                      final query = value.trim();
                      if (query.isEmpty) return;
                      controller.closeView(query);
                      await _goToPlace(fallbackQuery: query);
                      controller.clear();
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    leading: const Icon(
                      Icons.search,
                      color: AppColors.textSecondary,
                    ),
                    textStyle: WidgetStatePropertyAll(
                      TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: fieldFontSize,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    hintText: 'Cari alamat / lokasi...',
                    hintStyle: WidgetStatePropertyAll(
                      TextStyle(
                        color: AppColors.textMuted,
                        fontSize: fieldFontSize,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    side: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.focused)) {
                        return const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        );
                      }
                      return const BorderSide(color: AppColors.border);
                    }),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    backgroundColor: const WidgetStatePropertyAll(
                      AppColors.surface,
                    ),
                    surfaceTintColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    shadowColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    overlayColor: WidgetStatePropertyAll(
                      AppColors.primary.withValues(alpha: 0.08),
                    ),
                    elevation: const WidgetStatePropertyAll(0),
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
                        locationBias: _searchOriginTarget,
                        radiusMeters: _routeSearchRadiusMeters,
                        restrictToLocationBias: true,
                        maxResults: _routeSearchMaxResults,
                      );
                      return results.map((prediction) {
                        final distanceLabel = _routePredictionDistanceLabel(
                          prediction.distanceMeters,
                        );
                        return ListTile(
                          leading: _RoutePredictionPin(
                            distanceLabel: distanceLabel,
                          ),
                          title: Text(
                            prediction.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () async {
                            controller.closeView(prediction.description);
                            await _goToPlace(
                              placeId: prediction.placeId,
                              fallbackQuery: prediction.description,
                            );
                            controller.clear();
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
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
                          onCameraMoveStarted: _handleMapCameraMoveStarted,
                          onCameraMove: (position) {
                            _cameraTarget = position.target;
                          },
                          onCameraIdle: _handleMapCameraIdle,
                        ),
                        if (_isMapSelectionActive)
                          IgnorePointer(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 44),
                                child: Icon(
                                  Icons.location_pin,
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
    final actionButtonTextStyle = GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, showMapPanel ? 2 : 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPointSummary(),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: showMapPanel
                ? ConstrainedBox(
                    key: const ValueKey('route_picker_address_visible'),
                    constraints: BoxConstraints(
                      minHeight: AppTextScaling.adaptive(
                        context,
                        normal: 54,
                        large: 64,
                      ),
                    ),
                    child: Container(
                      alignment: Alignment.topLeft,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          (activeAddress ?? '').trim().isEmpty
                              ? ' '
                              : activeAddress!,
                          key: ValueKey((activeAddress ?? '').trim()),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: _activeAddressStyle,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(key: ValueKey('route_picker_address_hidden')),
          ),
          if (showMapPanel && (_statusHint ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            _InfoHint(
              icon: Icons.schedule,
              iconColor: AppColors.primaryDark,
              text: _statusHint!,
              keyValue: const Key('route_picker_status_hint'),
            ),
          ],
          if (showMapPanel)
            const SizedBox(height: 16)
          else
            const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: AppTextScaling.adaptive(
                      context,
                      normal: 50,
                      large: 54,
                    ),
                  ),
                  child: OutlinedButton.icon(
                    onPressed: _handleLocationButtonPressed,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
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
                      _isDestinationMapEntryMode ? 'Pilih Peta' : 'Lokasi Saya',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: actionButtonTextStyle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: AppTextScaling.adaptive(
                      context,
                      normal: 50,
                      large: 54,
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed:
                        (_canConfirmRoute ||
                            (_isManualDestinationSelectionMode &&
                                !_isSavingManualDestination))
                        ? _handlePrimaryAction
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor: AppColors.border,
                      disabledForegroundColor: AppColors.textSecondary,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      alignment: Alignment.center,
                      textStyle: actionButtonTextStyle,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Simpan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: actionButtonTextStyle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointSummary() {
    final hasDestinationDraftSelection =
        _destinationPoint != null ||
        (_isManualDestinationSelectionMode &&
            (_mapCenterAddress ?? '').trim().isNotEmpty);
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
            isSelected: hasDestinationDraftSelection,
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

  bool get _canConfirmRoute =>
      _pickupPoint != null && _destinationPoint != null;

  bool get _isManualDestinationSelectionMode =>
      _activeTarget == _destinationTarget &&
      _shouldShowMap &&
      _destinationPoint == null;

  bool get _isMapSelectionActive => _shouldShowMap;

  bool get _isDestinationMapEntryMode =>
      _activeTarget == _destinationTarget && !_shouldShowMap;

  void _handleMapCameraMoveStarted() {
    if (!_isMapSelectionActive) {
      return;
    }

    _pendingMapSelectionTarget ??= _activeTarget;
  }

  void _selectTarget(String target) {
    if (target != _pickupTarget && target != _destinationTarget) {
      return;
    }

    setState(() {
      _activeTarget = target;
      _statusHint = null;
    });
    _searchController.clear();
    if (_searchController.isOpen) {
      _searchController.closeView('');
    }
    _focusSelectedPoint(target);
  }

  Set<Marker> _markers() {
    final markers = <Marker>{};
    final pickup = _pickupPoint;
    final destination = _destinationPoint;
    final hideActiveMarker = _isMapSelectionActive;

    if (_activeTarget == _pickupTarget &&
        pickup != null &&
        !(hideActiveMarker && _activeTarget == _pickupTarget)) {
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
    if (_activeTarget == _destinationTarget &&
        destination != null &&
        !(hideActiveMarker && _activeTarget == _destinationTarget)) {
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
    final hasStableAddress = (point.address ?? '').trim().isNotEmpty;
    _skipNextCameraIdleGeocode = hasStableAddress;
    await _animateCameraSafely(latLng, 17);
  }

  Future<void> _hydrateInitialRouteAddresses() async {
    final pickup = _pickupPoint;
    if (pickup != null &&
        pickup.source == 'existing_route' &&
        (pickup.address ?? '').trim().isEmpty) {
      final resolved = await _mapsLookup.reverseGeocode(
        LatLng(pickup.latitude, pickup.longitude),
      );
      if (!mounted) return;

      final latestPickup = _pickupPoint;
      if (latestPickup == null ||
          latestPickup.source != 'existing_route' ||
          (latestPickup.address ?? '').trim().isNotEmpty ||
          !_samePoint(latestPickup, pickup)) {
        return;
      }
      setState(() {
        _pickupPoint = _RoutePoint(
          target: latestPickup.target,
          latitude: latestPickup.latitude,
          longitude: latestPickup.longitude,
          address: _mapsLookup.cleanAddress(resolved),
          source: latestPickup.source,
        );
      });
    }

    final destination = _destinationPoint;
    if (destination != null &&
        destination.source == 'existing_route' &&
        (destination.address ?? '').trim().isEmpty) {
      final resolved = await _mapsLookup.reverseGeocode(
        LatLng(destination.latitude, destination.longitude),
      );
      if (!mounted) return;

      final latestDestination = _destinationPoint;
      if (latestDestination == null ||
          latestDestination.source != 'existing_route' ||
          (latestDestination.address ?? '').trim().isNotEmpty ||
          !_samePoint(latestDestination, destination)) {
        return;
      }
      setState(() {
        _destinationPoint = _RoutePoint(
          target: latestDestination.target,
          latitude: latestDestination.latitude,
          longitude: latestDestination.longitude,
          address: _mapsLookup.cleanAddress(resolved),
          source: latestDestination.source,
        );
      });
    }
  }

  bool _samePoint(_RoutePoint a, _RoutePoint b) {
    return a.target == b.target &&
        a.latitude == b.latitude &&
        a.longitude == b.longitude;
  }

  Future<void> _handleMapCameraIdle() async {
    if (!mounted) return;
    if (!_isMapSelectionActive || _isResolvingCurrentLocation) {
      setState(() {});
      return;
    }
    if (_skipNextCameraIdleGeocode) {
      _skipNextCameraIdleGeocode = false;
      return;
    }

    final requestId = ++_mapAddressRequestId;
    final target = _cameraTarget;
    final saveTarget = _pendingMapSelectionTarget ?? _activeTarget;

    final address = await _mapsLookup.reverseGeocode(target);
    if (!mounted || requestId != _mapAddressRequestId) return;

    _cameraTarget = target;
    _saveActivePoint('map_pin', target: saveTarget, address: address);

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
      final location = await MapPickerHelpers.currentLocation();
      final failure = location.failure;
      if (failure != null) {
        _handleCurrentLocationFailure(failure);
        return;
      }

      if (!_isLocationPermissionGranted && mounted) {
        setState(() => _isLocationPermissionGranted = true);
      }

      final target = location.target!;
      _currentUserLocation = target;
      _cameraTarget = target;
      await _animateCameraSafely(target, 18);
      final address = await _mapsLookup.reverseGeocode(target);
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
    if (_isDestinationMapEntryMode) {
      _enterDestinationMapSelectionMode();
      return;
    }
    _moveToCurrentLocation();
  }

  void _enterDestinationMapSelectionMode() {
    LatLng target = _cameraTarget;
    double zoom = 16;

    final pickup = _pickupPoint;
    if (pickup != null) {
      target = LatLng(pickup.latitude, pickup.longitude);
      zoom = 17;
    }

    setState(() {
      _cameraTarget = target;
      _initialZoom = zoom;
      _isDestinationMapVisible = true;
      _statusHint = null;
    });
  }

  Future<void> _handlePrimaryAction() async {
    if (_canConfirmRoute) {
      _confirmRoute();
      return;
    }

    if (_isManualDestinationSelectionMode && !_isSavingManualDestination) {
      await _saveDestinationFromMapCenter();
      if (!mounted) return;
      if (_canConfirmRoute) {
        _confirmRoute();
      }
    }
  }

  Future<void> _saveDestinationFromMapCenter() async {
    if (_isSavingManualDestination || _activeTarget != _destinationTarget) {
      return;
    }

    final manualTarget = _cameraTarget;
    setState(() => _isSavingManualDestination = true);

    try {
      final address =
          _mapCenterAddress ?? await _mapsLookup.reverseGeocode(manualTarget);
      if (!mounted) return;

      _cameraTarget = manualTarget;
      _saveActivePoint('map_pin', target: _destinationTarget, address: address);
      setState(() => _statusHint = null);
    } finally {
      if (mounted) {
        setState(() => _isSavingManualDestination = false);
      }
    }
  }

  void _saveActivePoint(String source, {String? target, String? address}) {
    final cleanedAddress = _mapsLookup.cleanAddress(address);
    final saveTarget = target ?? _activeTarget;
    final point = _RoutePoint(
      target: saveTarget,
      latitude: _cameraTarget.latitude,
      longitude: _cameraTarget.longitude,
      address: cleanedAddress,
      source: source,
    );

    setState(() {
      if (saveTarget == _pickupTarget) {
        _pickupPoint = point;
        _pickupChanged = true;
      } else {
        _destinationPoint = point;
        _mapCenterAddress = null;
      }
    });

    if (_pendingMapSelectionTarget == saveTarget) {
      _pendingMapSelectionTarget = null;
    }
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

    final routeDistanceMeters = MapPickerHelpers.distanceMeters(
      LatLng(pickup.latitude, pickup.longitude),
      LatLng(destination.latitude, destination.longitude),
    );
    if (routeDistanceMeters < _minimumRouteDistanceMeters) {
      _showMessage(_routeTooCloseMessage);
      setState(() {
        _activeTarget = _destinationTarget;
        _statusHint = 'Geser peta atau cari alamat tujuan yang berbeda.';
      });
      return;
    }

    final hasDefaultPickup =
        MapPickerHelpers.validLatLng(
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

  Future<void> _goToPlace({String? placeId, String? fallbackQuery}) async {
    if (!_mapsLookup.isConfigured) {
      _showMessage('Google Maps API key belum dikonfigurasi.');
      return;
    }

    final resolved = await _mapsLookup.resolvePlace(
      placeId: placeId,
      fallbackQuery: fallbackQuery,
    );
    if (resolved == null) {
      _showMessage('Gagal mengambil detail lokasi.');
      return;
    }

    await _applyPlaceSelection(resolved.target, address: resolved.address);
  }

  Future<void> _applyPlaceSelection(LatLng target, {String? address}) async {
    _cameraTarget = target;
    _skipNextCameraIdleGeocode = true;
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

  void _handleCurrentLocationFailure(MapPickerLocationFailure failure) {
    switch (failure) {
      case MapPickerLocationFailure.serviceDisabled:
        _showMessage(
          'Layanan lokasi belum aktif. Aktifkan GPS lalu coba lagi.',
        );
        setState(() {
          _statusHint = 'GPS belum aktif, pilih titik manual di peta.';
        });
        return;
      case MapPickerLocationFailure.permissionDenied:
        _showMessage('Izin lokasi ditolak. Pilih titik manual di peta.');
        setState(() {
          _statusHint = 'Izin lokasi ditolak, pilih titik manual di peta.';
        });
        return;
      case MapPickerLocationFailure.permissionDeniedForever:
        _showMessage('Izin lokasi ditolak permanen. Aktifkan dari pengaturan.');
        return;
    }
  }
}

class _InfoHint extends StatelessWidget {
  const _InfoHint({
    required this.icon,
    required this.text,
    required this.keyValue,
    this.iconColor = AppColors.textSecondary,
  });

  final IconData icon;
  final String text;
  final Key keyValue;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: keyValue,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: _RouteLocationPickerScreenState._bodyHintStyle,
          ),
        ),
      ],
    );
  }
}

class _PointCard extends StatelessWidget {
  const _PointCard({
    required this.label,
    required this.point,
    required this.isActive,
    required this.color,
    required this.onTap,
    this.isSelected,
  });

  final String label;
  final _RoutePoint? point;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;
  final bool? isSelected;

  @override
  Widget build(BuildContext context) {
    final point = this.point;
    final isChosen = isSelected ?? point != null;
    final labelStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: isActive ? color : AppColors.textPrimary,
      fontWeight: FontWeight.w700,
      fontSize: 14,
    );
    final statusStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: isChosen ? color : AppColors.textSecondary,
      fontWeight: isChosen ? FontWeight.w600 : FontWeight.w500,
      fontSize: 12,
    );
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: AppTextScaling.adaptive(context, normal: 88, large: 96),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.08) : AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? color : AppColors.border,
              width: isActive ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle, size: 14, color: color),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isChosen ? 'Sudah dipilih' : 'Belum dipilih',
                textAlign: TextAlign.center,
                style: statusStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutePredictionPin extends StatelessWidget {
  const _RoutePredictionPin({required this.distanceLabel});

  final String? distanceLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, color: AppColors.primary, size: 26),
          if ((distanceLabel ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              distanceLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String? _routePredictionDistanceLabel(int? distanceMeters) {
  if (distanceMeters == null || distanceMeters < 0) {
    return null;
  }

  if (distanceMeters < 1000) {
    return '$distanceMeters m';
  }

  final distanceKm = distanceMeters / 1000;
  if (distanceKm < 10) {
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  return '${distanceKm.round()} km';
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
