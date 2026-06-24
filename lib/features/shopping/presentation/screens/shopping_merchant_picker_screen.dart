import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../features/auth/application/auth_session_provider.dart';
import '../../../../models/merchant_model.dart';
import '../../../../models/user_profile_model.dart';
import '../../../../services/customer_order_api_service.dart';
import '../../../../utils/address_readiness.dart';
import '../../../../utils/map_picker_helpers.dart';
import '../../../../widgets/bang_ui.dart';
import '../widgets/shopping_widget_helpers.dart';
import 'shopping_merchant_map_picker_screen.dart';

class ShoppingMerchantPickerScreen extends ConsumerStatefulWidget {
  const ShoppingMerchantPickerScreen({super.key, this.args});

  final ShoppingMerchantMapPickerArgs? args;

  @override
  ConsumerState<ShoppingMerchantPickerScreen> createState() =>
      _ShoppingMerchantPickerScreenState();
}

class _ShoppingMerchantPickerScreenState
    extends ConsumerState<ShoppingMerchantPickerScreen>
    with WidgetsBindingObserver {
  static const _searchDebounceDuration = Duration(milliseconds: 400);
  static const _fallbackSearchTarget = _PickerTarget(
    latitude: -7.319916770351389,
    longitude: 110.46393594806243,
  );

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  List<MerchantModel> _merchants = const <MerchantModel>[];
  _PickerTarget? _currentUserTarget;
  bool _isLoading = true;
  String? _errorText;
  int _loadRequestId = 0;
  bool _wasKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_scheduleSearch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_hydrateCurrentUserLocation());
        _loadMerchants();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.removeListener(_scheduleSearch);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) {
      return;
    }

    final isKeyboardVisible = View.of(context).viewInsets.bottom > 0;
    final didKeyboardClose = _wasKeyboardVisible && !isKeyboardVisible;
    _wasKeyboardVisible = isKeyboardVisible;

    if (didKeyboardClose) {
      _unfocusWhenKeyboardClosed();
    }
  }

  void _scheduleSearch() {
    _loadRequestId += 1;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (mounted) {
        unawaited(_loadMerchants());
      }
    });
  }

  void _runSearchNow({bool unfocus = false}) {
    _searchDebounce?.cancel();
    if (unfocus) {
      _searchFocusNode.unfocus();
    }
    unawaited(_loadMerchants());
  }

  void _syncKeyboardVisibility(bool isKeyboardOpen) {
    _wasKeyboardVisible = isKeyboardOpen;
  }

  void _unfocusWhenKeyboardClosed() {
    if (!mounted) {
      return;
    }

    final view = View.maybeOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || (view?.viewInsets.bottom ?? 0) > 0) {
        return;
      }

      if (_searchFocusNode.hasFocus) {
        _dismissSearchFocus();
      }
    });
  }

  void _dismissSearchFocus() {
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _handleBackNavigation() {
    if (!mounted) {
      return;
    }

    if (_searchFocusNode.hasFocus ||
        MediaQuery.viewInsetsOf(context).bottom > 0) {
      _dismissSearchFocus();
      _unfocusWhenKeyboardClosed();
      return;
    }

    context.pop();
  }

  Future<void> _loadMerchants() async {
    final requestId = ++_loadRequestId;
    final search = _searchController.text.trim();

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final target = _defaultSearchTarget();

    try {
      final merchants = await ref
          .read(homeApiServiceProvider)
          .fetchNearbyMerchants(
            search: search,
            latitude: target?.latitude,
            longitude: target?.longitude,
          );

      if (!mounted || requestId != _loadRequestId) {
        return;
      }

      setState(() {
        _merchants = merchants;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _loadRequestId) {
        return;
      }

      setState(() {
        _errorText = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _hydrateCurrentUserLocation() async {
    try {
      final target = await MapPickerHelpers.currentLocationIfPermitted();
      if (!mounted || target == null) {
        return;
      }

      setState(() {
        _currentUserTarget = _PickerTarget(
          latitude: target.latitude,
          longitude: target.longitude,
        );
      });

      unawaited(_loadMerchants());
    } catch (_) {
      return;
    }
  }

  _PickerTarget? _defaultSearchTarget() {
    final currentUserTarget = _currentUserTarget;
    if (currentUserTarget != null) {
      return currentUserTarget;
    }

    final initialLatitude = widget.args?.initialLatitude;
    final initialLongitude = widget.args?.initialLongitude;
    if (_hasValidCoordinate(initialLatitude, initialLongitude)) {
      return _PickerTarget(
        latitude: initialLatitude!,
        longitude: initialLongitude!,
      );
    }

    final profile = ref.read(authSessionProvider).profile;
    final address = defaultUsableSavedAddress(
      profile?.addresses ?? const <SavedAddressModel>[],
    );
    if (address == null) {
      return _fallbackSearchTarget;
    }

    return _PickerTarget(
      latitude: address.latitude,
      longitude: address.longitude,
    );
  }

  bool _hasValidCoordinate(double? latitude, double? longitude) {
    return latitude != null &&
        longitude != null &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        !(latitude == 0 && longitude == 0);
  }

  void _selectMerchant(MerchantModel merchant) {
    final latitude = merchant.latitude;
    final longitude = merchant.longitude;
    final merchantId = int.tryParse(merchant.id.trim());

    if (!_hasValidCoordinate(latitude, longitude) ||
        merchantId == null ||
        merchantId <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Toko/resto ini belum punya titik peta. Gunakan Cari tempat lain di Maps.',
            ),
          ),
        );
      return;
    }

    context.pop(
      ShoppingMerchantPickerResult(
        merchantId: merchantId,
        place: ShoppingMerchantPlacePayload(
          placeId: null,
          name: merchant.name,
          address: merchant.address.trim().isEmpty
              ? merchant.name
              : merchant.address.trim(),
          latitude: latitude!,
          longitude: longitude!,
          types: <String>[
            if (merchant.merchantType.trim().isNotEmpty)
              merchant.merchantType.trim(),
            'bangdeliv_official',
          ],
        ),
      ),
    );
  }

  Future<void> _openMapPicker() async {
    final target = _defaultSearchTarget();
    final result = await context.push<ShoppingMerchantPickerResult>(
      AppRoutes.chatbotShoppingMerchantMapPickerPath(),
      extra: ShoppingMerchantMapPickerArgs(
        initialLatitude: target?.latitude,
        initialLongitude: target?.longitude,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    context.pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchController.text.trim();
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    _syncKeyboardVisibility(isKeyboardOpen);

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Pilih Toko/Resto',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            onPressed: _handleBackNavigation,
          ),
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadMerchants,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                BangSearchField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  hintText: 'Cari toko/resto',
                  onSubmitted: (_) {
                    _runSearchNow(unfocus: true);
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _openMapPicker,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Cari toko/resto lain di Maps'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    alignment: Alignment.center,
                    foregroundColor: AppColors.primaryDark,
                    backgroundColor: AppColors.white,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.45),
                    ),
                    overlayColor: AppColors.primary.withValues(alpha: 0.06),
                    textStyle: GoogleFonts.nunitoSans(
                      fontSize: 13.25,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if ((_errorText ?? '').trim().isNotEmpty)
                  BangEmptyState(
                    message: _errorText!,
                    icon: Icons.info_outline_rounded,
                  )
                else if (_isLoading && _merchants.isEmpty)
                  const _MerchantPickerLoadingList()
                else if (_merchants.isEmpty && searchQuery.isNotEmpty)
                  _MerchantSearchEmptyState(query: searchQuery)
                else if (_merchants.isEmpty)
                  const _MerchantSearchEmptyState()
                else ...[
                  ..._merchants.map(
                    (merchant) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MerchantPickerTile(
                        merchant: merchant,
                        canSelect: _hasValidCoordinate(
                          merchant.latitude,
                          merchant.longitude,
                        ),
                        onTap: () => _selectMerchant(merchant),
                      ),
                    ),
                  ),
                  _MapSearchFooter(onTap: _openMapPicker),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MerchantSearchEmptyState extends StatelessWidget {
  const _MerchantSearchEmptyState({this.query = ''});

  final String query;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim();
    final title = normalizedQuery.isEmpty
        ? 'Toko/resto belum tersedia'
        : 'Tidak ada hasil untuk "$normalizedQuery"';
    final subtitle = normalizedQuery.isEmpty
        ? 'Coba muat ulang halaman atau cari lewat Maps.'
        : 'Periksa ejaan atau cari toko/resto lewat Maps.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 32,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunitoSans(
              color: AppColors.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapSearchFooter extends StatelessWidget {
  const _MapSearchFooter({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Tidak menemukan toko/resto yang Anda cari?',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.map_outlined, size: 17),
            label: const Text('Cari lewat Maps'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              backgroundColor: AppColors.white,
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.45),
              ),
              overlayColor: AppColors.primary.withValues(alpha: 0.06),
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              textStyle: GoogleFonts.nunitoSans(
                fontSize: 13.25,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MerchantPickerTile extends StatelessWidget {
  const _MerchantPickerTile({
    required this.merchant,
    required this.canSelect,
    required this.onTap,
  });

  final MerchantModel merchant;
  final bool canSelect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distance = merchant.distance.trim();

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox.square(
                  dimension: 68,
                  child: _MerchantImage(imageUrl: merchant.imageUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      merchant.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _MerchantMetaRow(
                      merchantType: merchant.merchantType,
                      distance: distance,
                      needsMap: !canSelect,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                canSelect ? Icons.chevron_right_rounded : Icons.info_outline,
                color: canSelect ? AppColors.textSecondary : AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MerchantImage extends StatelessWidget {
  const _MerchantImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return const _MerchantImageFallback();
    }

    return Image.network(
      imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const _MerchantImageFallback(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return const _MerchantImageFallback(isLoading: true);
      },
    );
  }
}

class _MerchantImageFallback extends StatelessWidget {
  const _MerchantImageFallback({this.isLoading = false});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceAlt,
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : const Icon(
                Icons.storefront_outlined,
                size: 28,
                color: AppColors.textMuted,
              ),
      ),
    );
  }
}

class _MerchantMetaRow extends StatelessWidget {
  const _MerchantMetaRow({
    required this.merchantType,
    required this.distance,
    required this.needsMap,
  });

  final String merchantType;
  final String distance;
  final bool needsMap;

  @override
  Widget build(BuildContext context) {
    final hasDistance = distance.isNotEmpty && distance != '-';
    final items = <Widget>[
      _MerchantMetaItem(
        icon: shoppingMerchantIcon(merchantType),
        label: shoppingMerchantTypeLabel(merchantType),
      ),
      if (hasDistance)
        _MerchantMetaItem(
          icon: Icons.near_me_outlined,
          label: distance,
          isStrong: true,
        ),
      if (needsMap)
        const _MerchantMetaItem(
          icon: Icons.map_outlined,
          label: 'Pilih lewat Maps',
          color: AppColors.primary,
          isStrong: true,
        ),
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const _MerchantMetaSeparator(),
          items[index],
        ],
      ],
    );
  }
}

class _MerchantMetaItem extends StatelessWidget {
  const _MerchantMetaItem({
    required this.icon,
    required this.label,
    this.color = AppColors.textSecondary,
    this.isStrong = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: isStrong ? FontWeight.w700 : FontWeight.w600,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _MerchantMetaSeparator extends StatelessWidget {
  const _MerchantMetaSeparator();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '·',
      style: TextStyle(
        color: AppColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    );
  }
}

class _MerchantPickerLoadingList extends StatelessWidget {
  const _MerchantPickerLoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < 5; index++) ...[
          const BangLoadingSkeleton(height: 90),
          if (index < 4) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PickerTarget {
  const _PickerTarget({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}
