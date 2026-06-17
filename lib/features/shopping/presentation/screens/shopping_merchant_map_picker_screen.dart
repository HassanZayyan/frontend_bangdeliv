import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../config/app_colors.dart';
import '../../../../services/customer_order_api_service.dart';
import '../../../../services/google_maps_lookup_service.dart';
import '../widgets/shopping_widget_helpers.dart';

class ShoppingMerchantMapPickerArgs {
  const ShoppingMerchantMapPickerArgs({
    this.initialLatitude,
    this.initialLongitude,
  });

  final double? initialLatitude;
  final double? initialLongitude;
}

class ShoppingMerchantMapPickerScreen extends StatefulWidget {
  const ShoppingMerchantMapPickerScreen({super.key, this.args});

  final ShoppingMerchantMapPickerArgs? args;

  @override
  State<ShoppingMerchantMapPickerScreen> createState() =>
      _ShoppingMerchantMapPickerScreenState();
}

class _ShoppingMerchantMapPickerScreenState
    extends State<ShoppingMerchantMapPickerScreen> {
  static const _fallbackCenter = LatLng(-7.3305, 110.5084);

  final _searchController = TextEditingController();
  final _mapsLookup = const GoogleMapsLookupService();

  GoogleMapController? _mapController;
  List<GoogleMapsPrediction> _predictions = const <GoogleMapsPrediction>[];
  ShoppingMerchantPlacePayload? _selectedPlace;
  bool _isSearching = false;
  bool _isResolving = false;
  String? _errorText;
  late String _sessionToken;

  @override
  void initState() {
    super.initState();
    _sessionToken = _newSessionToken();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  LatLng get _initialTarget {
    final latitude = widget.args?.initialLatitude;
    final longitude = widget.args?.initialLongitude;
    if (latitude == null || longitude == null) {
      return _fallbackCenter;
    }

    return LatLng(latitude, longitude);
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
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _predictions = predictions;
      _isSearching = false;
      if (predictions.isEmpty) {
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

    final place = ShoppingMerchantPlacePayload(
      placeId: resolved.placeId ?? prediction.placeId,
      name:
          resolved.name ??
          prediction.name ??
          _firstAddressSegment(prediction.description),
      address: resolved.address ?? prediction.description,
      latitude: resolved.target.latitude,
      longitude: resolved.target.longitude,
      types: resolved.types,
    );

    _sessionToken = _newSessionToken();
    _setSelectedPlace(place);
  }

  Future<void> _selectMapPoint(LatLng target) async {
    setState(() {
      _isResolving = true;
      _errorText = null;
    });

    final address = await _mapsLookup.reverseGeocode(target);

    if (!mounted) {
      return;
    }

    final displayAddress =
        address ??
        '${target.latitude.toStringAsFixed(6)}, ${target.longitude.toStringAsFixed(6)}';

    _setSelectedPlace(
      ShoppingMerchantPlacePayload(
        placeId: null,
        name: _firstAddressSegment(displayAddress),
        address: displayAddress,
        latitude: target.latitude,
        longitude: target.longitude,
      ),
    );
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
              onMapCreated: (controller) => _mapController = controller,
              onTap: _isResolving ? null : _selectMapPoint,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              markers: {
                if (selectedPlace != null)
                  Marker(
                    markerId: const MarkerId('selected-shopping-merchant'),
                    position: LatLng(
                      selectedPlace.latitude,
                      selectedPlace.longitude,
                    ),
                    infoWindow: InfoWindow(title: selectedPlace.name),
                  ),
              },
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
    required this.isResolving,
    required this.onConfirm,
  });

  final ShoppingMerchantPlacePayload place;
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
                    shoppingMerchantTypeLabel(merchantType),
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

String _newSessionToken() {
  return '${DateTime.now().microsecondsSinceEpoch}-${Object().hashCode}';
}

String _firstAddressSegment(String value) {
  final segments = value
      .split(',')
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  return segments.isEmpty ? value.trim() : segments.first;
}
