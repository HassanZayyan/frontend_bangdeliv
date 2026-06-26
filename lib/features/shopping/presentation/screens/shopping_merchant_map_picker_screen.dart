import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../services/customer_order_api_service.dart';
import '../../../../services/google_maps_lookup_service.dart';
import '../../../../utils/map_marker_icons.dart';
import '../../../../utils/map_picker_helpers.dart';
import '../widgets/shopping_widget_helpers.dart';

class ShoppingMerchantMapPickerArgs {
  const ShoppingMerchantMapPickerArgs({
    this.initialLatitude,
    this.initialLongitude,
  });

  final double? initialLatitude;
  final double? initialLongitude;
}

class ShoppingMerchantMapPickerScreen extends ConsumerStatefulWidget {
  const ShoppingMerchantMapPickerScreen({
    super.key,
    this.args,
    GoogleMapsLookupService? mapsLookup,
  }) : mapsLookup = mapsLookup ?? const GoogleMapsLookupService();

  final ShoppingMerchantMapPickerArgs? args;
  final GoogleMapsLookupService mapsLookup;

  @override
  ConsumerState<ShoppingMerchantMapPickerScreen> createState() =>
      _ShoppingMerchantMapPickerScreenState();
}

class _ShoppingMerchantMapPickerScreenState
    extends ConsumerState<ShoppingMerchantMapPickerScreen> {
  static const _fallbackCenter = LatLng(-7.319916770351389, 110.46393594806243);
  static const _placeSearchRadiusMeters = 50000;
  static const _placeSearchMaxResults = 8;

  final SearchController _searchController = SearchController();
  late final GoogleMapsLookupService _mapsLookup;

  GoogleMapController? _mapController;
  LatLng? _lastCameraTarget;
  LatLng? _currentUserLocation;
  List<ShoppingMerchantOption> _officialMerchants =
      const <ShoppingMerchantOption>[];
  ShoppingMerchantPlacePayload? _selectedPlace;
  int? _selectedOfficialMerchantId;
  BitmapDescriptor? _restaurantMarkerIcon;
  BitmapDescriptor? _warungMarkerIcon;
  bool _isResolving = false;
  bool _isLocationPermissionGranted = false;
  String? _errorText;
  late String _sessionToken;
  int _tapResolveRequestId = 0;

  @override
  void initState() {
    super.initState();
    _mapsLookup = widget.mapsLookup;
    _sessionToken = MapPickerHelpers.newMapsSessionToken();
    unawaited(_loadOfficialMerchantIcons());
    unawaited(_loadOfficialMerchants());
    unawaited(_hydrateCurrentUserLocation());
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  LatLng get _initialTarget {
    final explicitTarget = MapPickerHelpers.validLatLng(
      widget.args?.initialLatitude,
      widget.args?.initialLongitude,
    );
    if (explicitTarget != null) {
      return explicitTarget;
    }

    return _currentUserLocation ?? _fallbackCenter;
  }

  bool get _hasExplicitInitialTarget {
    return MapPickerHelpers.validLatLng(
          widget.args?.initialLatitude,
          widget.args?.initialLongitude,
        ) !=
        null;
  }

  LatLng get _searchBiasTarget {
    final currentUserLocation = _currentUserLocation;
    if (currentUserLocation != null) {
      return currentUserLocation;
    }

    final selectedPlace = _selectedPlace;
    if (selectedPlace != null) {
      return LatLng(selectedPlace.latitude, selectedPlace.longitude);
    }

    return _lastCameraTarget ?? _initialTarget;
  }

  Future<List<GoogleMapsPrediction>> _searchPredictions(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty || !_mapsLookup.isConfigured) {
      return const <GoogleMapsPrediction>[];
    }

    return _mapsLookup.searchPlaces(
      normalizedQuery,
      scope: GoogleMapsLookupScope.bangDelivServiceAreaAddress,
      sessionToken: _sessionToken,
      establishmentOnly: true,
      locationBias: _searchBiasTarget,
      radiusMeters: _placeSearchRadiusMeters,
      restrictToLocationBias: true,
      maxResults: _placeSearchMaxResults,
    );
  }

  Future<void> _hydrateCurrentUserLocation() async {
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
        _lastCameraTarget ??= currentLocation;
      }
    });

    if (!_hasExplicitInitialTarget && currentLocation != null) {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(currentLocation, 14),
      );
    }
  }

  Future<void> _selectPrediction(GoogleMapsPrediction prediction) async {
    _tapResolveRequestId += 1;
    setState(() {
      _isResolving = true;
      _errorText = null;
    });

    final resolved = await _mapsLookup.resolvePlace(
      placeId: prediction.placeId,
      fallbackQuery: prediction.description,
      sessionToken: _sessionToken,
    );

    if (!mounted) {
      return;
    }

    if (resolved == null) {
      setState(() {
        _isResolving = false;
        _errorText = 'Detail toko/resto belum bisa diambil.';
      });
      return;
    }

    final resolvedName =
        resolved.name ??
        prediction.name ??
        MapPickerHelpers.firstAddressSegment(prediction.description);

    final place = ShoppingMerchantPlacePayload(
      placeId: resolved.placeId ?? prediction.placeId,
      name: resolvedName,
      address: resolved.address ?? prediction.description,
      latitude: resolved.target.latitude,
      longitude: resolved.target.longitude,
      types: resolved.types,
    );

    _sessionToken = MapPickerHelpers.newMapsSessionToken();
    _setSelectedPlace(place);
  }

  Future<void> _handleMapTap(LatLng target) async {
    if (!_mapsLookup.isConfigured) {
      setState(() => _errorText = 'Google Maps API belum dikonfigurasi.');
      return;
    }

    final requestId = ++_tapResolveRequestId;
    setState(() {
      _isResolving = true;
      _errorText = null;
      _selectedOfficialMerchantId = null;
      _selectedPlace = ShoppingMerchantPlacePayload(
        placeId: null,
        name: 'Mencari toko/resto...',
        address: 'Mengambil alamat toko/resto dari titik peta.',
        latitude: target.latitude,
        longitude: target.longitude,
        types: const <String>['map_tap'],
      );
    });

    final resolved = await _mapsLookup.findNearestEstablishment(target);

    if (!mounted || requestId != _tapResolveRequestId) {
      return;
    }

    if (resolved == null) {
      setState(() {
        _isResolving = false;
        _selectedPlace = null;
        _errorText =
            'Nama toko/resto belum ditemukan. Tap lebih dekat ke label toko/resto atau cari nama toko/resto.';
      });
      return;
    }

    final name = (resolved.name ?? '').trim();
    if (name.isEmpty) {
      setState(() {
        _isResolving = false;
        _selectedPlace = null;
        _errorText =
            'Nama toko/resto belum ditemukan. Tap lebih dekat ke label toko/resto atau cari nama toko/resto.';
      });
      return;
    }

    final fallbackAddress =
        '${resolved.target.latitude.toStringAsFixed(6)}, ${resolved.target.longitude.toStringAsFixed(6)}';
    final address = (resolved.address ?? '').trim().isNotEmpty
        ? resolved.address!.trim()
        : fallbackAddress;

    _sessionToken = MapPickerHelpers.newMapsSessionToken();
    _setSelectedPlace(
      ShoppingMerchantPlacePayload(
        placeId: resolved.placeId,
        name: name,
        address: address,
        latitude: resolved.target.latitude,
        longitude: resolved.target.longitude,
        types: resolved.types.isEmpty
            ? const <String>['establishment']
            : resolved.types,
      ),
    );
  }

  void _setSelectedPlace(
    ShoppingMerchantPlacePayload place, {
    int? officialMerchantId,
  }) {
    setState(() {
      _selectedPlace = place;
      _selectedOfficialMerchantId = officialMerchantId;
      _searchController.text = place.name;
      _isResolving = false;
      _errorText = null;
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(place.latitude, place.longitude), 16),
    );
  }

  Future<void> _loadOfficialMerchantIcons() async {
    final icons = await Future.wait([
      buildOfficialMerchantMarker('restaurant'),
      buildOfficialMerchantMarker('warung'),
    ]);
    if (!mounted) {
      return;
    }

    setState(() {
      _restaurantMarkerIcon = icons[0];
      _warungMarkerIcon = icons[1];
    });
  }

  Future<void> _loadOfficialMerchants() async {
    try {
      final merchants = await ref
          .read(customerOrderRepositoryProvider)
          .searchShoppingMerchants('', perPage: 50);
      if (!mounted) {
        return;
      }

      setState(() {
        _officialMerchants = merchants
            .where(
              (merchant) =>
                  MapPickerHelpers.validLatLng(
                    merchant.latitude,
                    merchant.longitude,
                  ) !=
                  null,
            )
            .toList(growable: false);
      });
    } catch (_) {
      return;
    }
  }

  void _selectOfficialMerchant(ShoppingMerchantOption merchant) {
    _tapResolveRequestId += 1;
    final latitude = merchant.latitude;
    final longitude = merchant.longitude;
    if (latitude == null || longitude == null) {
      return;
    }

    _setSelectedPlace(
      ShoppingMerchantPlacePayload(
        placeId: null,
        name: merchant.name,
        address: (merchant.address ?? '').trim().isNotEmpty
            ? merchant.address!.trim()
            : '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
        latitude: latitude,
        longitude: longitude,
        types: [
          if ((merchant.merchantType ?? '').trim().isNotEmpty)
            merchant.merchantType!.trim(),
          'bangdeliv_official',
        ],
      ),
      officialMerchantId: merchant.id,
    );
  }

  Set<Marker> _buildMarkers() {
    final selectedPlace = _selectedPlace;
    final selectedOfficialMerchant = _selectedOfficialMerchant(selectedPlace);
    final markers = <Marker>{};

    for (final merchant in _officialMerchants) {
      final target = MapPickerHelpers.validLatLng(
        merchant.latitude,
        merchant.longitude,
      );
      if (target == null) {
        continue;
      }

      final isWarung =
          (merchant.merchantType ?? '').trim().toLowerCase() == 'warung';
      markers.add(
        Marker(
          markerId: MarkerId('official_merchant_${merchant.id}'),
          position: target,
          icon:
              (isWarung ? _warungMarkerIcon : _restaurantMarkerIcon) ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: merchant.name,
            snippet: shoppingMerchantTypeLabel(merchant.merchantType),
          ),
          onTap: () => _selectOfficialMerchant(merchant),
        ),
      );
    }

    if (selectedPlace != null && selectedOfficialMerchant == null) {
      markers.add(
        Marker(
          markerId: const MarkerId('selected-shopping-merchant'),
          position: LatLng(selectedPlace.latitude, selectedPlace.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(title: selectedPlace.name),
        ),
      );
    }

    return markers;
  }

  ShoppingMerchantOption? _matchedOfficialMerchant(
    ShoppingMerchantPlacePayload place,
  ) {
    for (final merchant in _officialMerchants) {
      if (_normalizeName(merchant.name) != _normalizeName(place.name)) {
        continue;
      }
      final target = MapPickerHelpers.validLatLng(
        merchant.latitude,
        merchant.longitude,
      );
      if (target == null) {
        continue;
      }

      final distance = MapPickerHelpers.distanceMeters(
        target,
        LatLng(place.latitude, place.longitude),
      );
      if (distance <= 10) {
        return merchant;
      }
    }

    return null;
  }

  ShoppingMerchantOption? _selectedOfficialMerchant(
    ShoppingMerchantPlacePayload? place,
  ) {
    if (place == null) {
      return null;
    }

    final selectedId = _selectedOfficialMerchantId;
    if (selectedId != null && selectedId > 0) {
      for (final merchant in _officialMerchants) {
        if (merchant.id == selectedId) {
          return merchant;
        }
      }
    }

    return _matchedOfficialMerchant(place);
  }

  void _confirmSelection() {
    final place = _selectedPlace;
    if (place == null) {
      setState(() => _errorText = 'Pilih toko/resto terlebih dahulu.');
      return;
    }

    final officialMerchant = _selectedOfficialMerchant(place);
    Navigator.of(context).pop(
      ShoppingMerchantPickerResult(
        place: place,
        merchantId: officialMerchant?.id ?? _selectedOfficialMerchantId,
      ),
    );
  }

  Widget _buildSearchAnchor() {
    return SearchAnchor(
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
          leading: const Icon(Icons.search, color: AppColors.textSecondary),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              color: AppColors.textPrimary,
              fontSize: fieldFontSize,
              fontWeight: FontWeight.w400,
            ),
          ),
          hintText: 'Cari nama toko/resto',
          hintStyle: WidgetStatePropertyAll(
            TextStyle(
              color: AppColors.textMuted,
              fontSize: fieldFontSize,
              fontWeight: FontWeight.w400,
            ),
          ),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return const BorderSide(color: AppColors.primary, width: 1.5);
            }
            return const BorderSide(color: AppColors.border);
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: WidgetStatePropertyAll(
            AppColors.primary.withValues(alpha: 0.08),
          ),
          elevation: const WidgetStatePropertyAll(0),
        );
      },
      suggestionsBuilder:
          (BuildContext context, SearchController controller) async {
            final query = controller.text.trim();
            if (query.isEmpty) {
              return const Iterable<Widget>.empty();
            }

            final results = await _searchPredictions(query);
            return results.map((prediction) {
              final distanceLabel = _predictionDistanceLabel(
                prediction.distanceMeters,
              );
              return ListTile(
                leading: _PredictionPin(distanceLabel: distanceLabel),
                title: Text(
                  prediction.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () async {
                  controller.closeView(prediction.description);
                  await _selectPrediction(prediction);
                  FocusManager.instance.primaryFocus?.unfocus();
                },
              );
            });
          },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlace = _selectedPlace;
    final selectedOfficialMerchant = _selectedOfficialMerchant(selectedPlace);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Pilih Toko/Resto',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSearchAnchor(),
                  if ((_errorText ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _SearchErrorText(message: _errorText!),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _initialTarget,
                      zoom: 14,
                    ),
                    onMapCreated: (controller) => _mapController = controller,
                    onCameraMove: (position) =>
                        _lastCameraTarget = position.target,
                    myLocationEnabled: _isLocationPermissionGranted,
                    myLocationButtonEnabled: _isLocationPermissionGranted,
                    zoomControlsEnabled: false,
                    onTap: _handleMapTap,
                    markers: _buildMarkers(),
                  ),
                  if (selectedPlace != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _SelectedPlacePanel(
                        place: selectedPlace,
                        isOfficial: selectedOfficialMerchant != null,
                        isResolving: _isResolving,
                        onConfirm: _confirmSelection,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _normalizeName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

class _SearchErrorText extends StatelessWidget {
  const _SearchErrorText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: AppColors.error,
          size: 16,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PredictionPin extends StatelessWidget {
  const _PredictionPin({required this.distanceLabel});

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

String? _predictionDistanceLabel(int? distanceMeters) {
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

class _SelectedPlacePanel extends StatelessWidget {
  const _SelectedPlacePanel({
    required this.place,
    required this.isOfficial,
    required this.isResolving,
    required this.onConfirm,
  });

  final ShoppingMerchantPlacePayload place;
  final bool isOfficial;
  final bool isResolving;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final merchantType = shoppingMerchantTypeFromPlace(
      name: place.name,
      types: place.types,
    );
    final categoryLabel = isOfficial
        ? 'Resmi BangDeliv'
        : shoppingMerchantTypeLabel(merchantType);
    final categoryColor = isOfficial
        ? AppColors.primaryDark
        : AppColors.textSecondary;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    place.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    place.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.25,
                      fontWeight: FontWeight.w500,
                      height: 1.28,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        shoppingMerchantIcon(merchantType),
                        size: 14,
                        color: categoryColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          categoryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: categoryColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 82,
              height: 48,
              child: FilledButton(
                onPressed: isResolving ? null : onConfirm,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Pilih'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
