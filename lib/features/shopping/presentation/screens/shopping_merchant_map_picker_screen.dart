import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../config/app_colors.dart';
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
  const ShoppingMerchantMapPickerScreen({super.key, this.args});

  final ShoppingMerchantMapPickerArgs? args;

  @override
  ConsumerState<ShoppingMerchantMapPickerScreen> createState() =>
      _ShoppingMerchantMapPickerScreenState();
}

class _ShoppingMerchantMapPickerScreenState
    extends ConsumerState<ShoppingMerchantMapPickerScreen> {
  static const _fallbackCenter = LatLng(-7.3305, 110.5084);
  static const _shoppingMapStyle = '''
[
  {
    "featureType": "poi.business",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "transit",
    "elementType": "labels.icon",
    "stylers": [{"visibility": "off"}]
  }
]
''';

  final _searchController = TextEditingController();
  final _mapsLookup = const GoogleMapsLookupService();

  GoogleMapController? _mapController;
  List<GoogleMapsPrediction> _predictions = const <GoogleMapsPrediction>[];
  List<ShoppingMerchantOption> _officialMerchants =
      const <ShoppingMerchantOption>[];
  ShoppingMerchantPlacePayload? _selectedPlace;
  BitmapDescriptor? _restaurantMarkerIcon;
  BitmapDescriptor? _warungMarkerIcon;
  bool _isSearching = false;
  bool _isResolving = false;
  String? _errorText;
  late String _sessionToken;

  @override
  void initState() {
    super.initState();
    _sessionToken = MapPickerHelpers.newMapsSessionToken();
    unawaited(_loadOfficialMerchantIcons());
    unawaited(_loadOfficialMerchants());
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  LatLng get _initialTarget {
    return MapPickerHelpers.validLatLng(
          widget.args?.initialLatitude,
          widget.args?.initialLongitude,
        ) ??
        _fallbackCenter;
  }

  Future<void> _searchPlaces() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _errorText = 'Ketik nama toko/resto terlebih dahulu.');
      return;
    }

    if (!_mapsLookup.isConfigured) {
      setState(() => _errorText = 'Google Maps API belum dikonfigurasi.');
      return;
    }

    setState(() {
      _isSearching = true;
      _errorText = null;
    });

    final predictions = await _mapsLookup.searchPlaces(
      query,
      sessionToken: _sessionToken,
      establishmentOnly: true,
    );

    if (!mounted) {
      return;
    }

    final filteredPredictions = predictions
        .where(
          (prediction) => isAllowedShoppingMerchantPlace(
            name:
                prediction.name ??
                MapPickerHelpers.firstAddressSegment(prediction.description),
            types: prediction.types,
          ),
        )
        .toList(growable: false);

    setState(() {
      _predictions = filteredPredictions;
      _isSearching = false;
      if (filteredPredictions.isEmpty) {
        _errorText = 'Tempat tidak ditemukan.';
      }
    });
  }

  Future<void> _selectPrediction(GoogleMapsPrediction prediction) async {
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
        _errorText = 'Detail tempat belum bisa diambil.';
      });
      return;
    }

    final resolvedName =
        resolved.name ??
        prediction.name ??
        MapPickerHelpers.firstAddressSegment(prediction.description);
    if (!isAllowedShoppingMerchantPlace(
      name: resolvedName,
      types: resolved.types,
    )) {
      setState(() {
        _isResolving = false;
        _errorText =
            'Pilih resto, coffee shop, minimarket, market, atau warung.';
      });
      return;
    }

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

  void _setSelectedPlace(ShoppingMerchantPlacePayload place) {
    setState(() {
      _selectedPlace = place;
      _predictions = const <GoogleMapsPrediction>[];
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
    );
  }

  Set<Marker> _buildMarkers() {
    final selectedPlace = _selectedPlace;
    final selectedOfficialMerchant = selectedPlace == null
        ? null
        : _matchedOfficialMerchant(selectedPlace);
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

  void _confirmSelection() {
    final place = _selectedPlace;
    if (place == null) {
      setState(() => _errorText = 'Pilih tempat terlebih dahulu.');
      return;
    }

    Navigator.of(context).pop(place);
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlace = _selectedPlace;
    final selectedOfficialMerchant = selectedPlace == null
        ? null
        : _matchedOfficialMerchant(selectedPlace);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Pilih Tempat',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialTarget,
                zoom: 14,
              ),
              style: _shoppingMapStyle,
              onMapCreated: (controller) => _mapController = controller,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              markers: _buildMarkers(),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: _SearchPanel(
                controller: _searchController,
                predictions: _predictions,
                isSearching: _isSearching,
                isResolving: _isResolving,
                errorText: _errorText,
                onSearch: _searchPlaces,
                onSelectPrediction: _selectPrediction,
              ),
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
    );
  }
}

String _normalizeName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.predictions,
    required this.isSearching,
    required this.isResolving,
    required this.errorText,
    required this.onSearch,
    required this.onSelectPrediction,
  });

  final TextEditingController controller;
  final List<GoogleMapsPrediction> predictions;
  final bool isSearching;
  final bool isResolving;
  final String? errorText;
  final VoidCallback onSearch;
  final ValueChanged<GoogleMapsPrediction> onSelectPrediction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !isResolving,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Cari toko, resto, atau minimarket',
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                    ),
                    onSubmitted: (_) => onSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 46,
                  height: 46,
                  child: IconButton.filled(
                    tooltip: 'Cari tempat',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isSearching || isResolving ? null : onSearch,
                    icon: isSearching
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(Icons.search_rounded, size: 20),
                  ),
                ),
              ],
            ),
            if ((errorText ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.error,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      errorText!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (predictions.isNotEmpty) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 230),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: predictions.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, index) {
                    final prediction = predictions[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.place_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        prediction.name ?? prediction.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: prediction.name == null
                          ? null
                          : Text(
                              prediction.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: isResolving
                          ? null
                          : () => onSelectPrediction(prediction),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
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

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                shoppingMerchantIcon(merchantType),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    place.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isOfficial
                        ? 'Resmi BangDeliv'
                        : shoppingMerchantTypeLabel(merchantType),
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: isResolving ? null : onConfirm,
              child: const Text('Pilih'),
            ),
          ],
        ),
      ),
    );
  }
}
