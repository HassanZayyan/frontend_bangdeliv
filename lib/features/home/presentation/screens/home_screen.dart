import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../models/home_data_model.dart';
import '../../../../models/merchant_model.dart';
import '../../../../models/customer_order_model.dart';
import '../../../../models/user_profile_model.dart';
import '../../../../core/di/app_providers.dart';
import '../../../auth/application/auth_session_provider.dart';
import '../../../location/application/current_user_location_provider.dart';
import '../../../location/application/post_login_location_permission_provider.dart';
import '../../../orders/application/customer_order_providers.dart';
import '../../../../utils/map_picker_helpers.dart';
import '../../../../utils/order_formatters.dart';
import '../../../../utils/order_ui_helpers.dart';
import '../../../../widgets/app_content_background.dart';
import '../../../../widgets/bang_ui.dart';
import '../../../auth/presentation/widgets/guest_login_prompt.dart';
import '../../../../widgets/service_visual_icon.dart';
import '../widgets/nearby_merchant_card.dart';

typedef _HomeDataRequest = ({double? latitude, double? longitude});

const int _homeNearbyMerchantLimit = 6;
const double _homeHorizontalPadding = 20;
const double _homeBottomNavClearance = 88;

final _homeScreenDataProvider = FutureProvider.autoDispose
    .family<HomeDataModel, _HomeDataRequest>((ref, request) async {
      final service = ref.watch(homeApiServiceProvider);

      return service.fetchHomeData(
        limitMerchants: _homeNearbyMerchantLimit,
        latitude: request.latitude,
        longitude: request.longitude,
      );
    });

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  HomeDataModel? _lastHomeData;
  bool _isHeaderScrolled = false;
  bool _isResolvingCurrentLocation = true;
  int? _lastLocationPermissionRefreshSignal;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    unawaited(_hydrateCurrentUserLocation());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    final nextValue =
        _scrollController.hasClients && _scrollController.position.pixels > 2;
    if (nextValue == _isHeaderScrolled) {
      return;
    }

    setState(() => _isHeaderScrolled = nextValue);
  }

  @override
  Widget build(BuildContext context) {
    final activeAddress = _activeAddress(
      ref.watch(authSessionProvider).profile,
    );
    final currentUserLocation = ref.watch(currentUserLocationProvider);
    final homeRequest = _homeRequestFor(activeAddress, currentUserLocation);
    final shouldWaitForInitialLocation =
        _isResolvingCurrentLocation && currentUserLocation == null;
    _handleLocationPermissionRefreshSignal(
      ref.watch(postLoginLocationPermissionRefreshProvider),
    );
    final AsyncValue<HomeDataModel> homeDataAsync;
    final HomeDataModel? visibleHomeData;
    if (shouldWaitForInitialLocation) {
      homeDataAsync = const AsyncValue.loading();
      visibleHomeData = _lastHomeData;
    } else {
      ref.listen<AsyncValue<HomeDataModel>>(
        _homeScreenDataProvider(homeRequest),
        (_, next) {
          final data = next.value;
          if (data != null) {
            _lastHomeData = data;
          }
        },
      );
      homeDataAsync = ref.watch(_homeScreenDataProvider(homeRequest));
      visibleHomeData = homeDataAsync.value ?? _lastHomeData;
    }
    final activeOrder = ref.watch(customerActiveOrderProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context, activeAddress, isScrolled: _isHeaderScrolled),
            Expanded(
              child: AppContentBackground(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.white,
                  onRefresh: _refreshHomeData,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    child: _buildHomeContent(
                      context,
                      homeDataAsync: homeDataAsync,
                      visibleData: visibleHomeData,
                      activeOrder: activeOrder,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshHomeData() async {
    await _hydrateCurrentUserLocation();
    if (!mounted) {
      return;
    }

    final activeAddress = _activeAddress(ref.read(authSessionProvider).profile);
    final currentUserLocation = ref.read(currentUserLocationProvider);
    final request = _homeRequestFor(activeAddress, currentUserLocation);
    ref.invalidate(_homeScreenDataProvider(request));
    try {
      await ref.read(_homeScreenDataProvider(request).future);
    } catch (_) {
      // Error state is rendered by _homeScreenDataProvider.
    }
  }

  void _handleLocationPermissionRefreshSignal(int signal) {
    if (_lastLocationPermissionRefreshSignal == signal) {
      return;
    }

    _lastLocationPermissionRefreshSignal = signal;
    if (signal <= 0) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_refreshHomeData());
      }
    });
  }

  Widget _buildHomeContent(
    BuildContext context, {
    required AsyncValue<HomeDataModel> homeDataAsync,
    required HomeDataModel? visibleData,
    required CustomerOrderSummaryModel? activeOrder,
  }) {
    if (visibleData != null) {
      return _buildDataContent(context, visibleData, activeOrder: activeOrder);
    }

    return homeDataAsync.when(
      loading: () => _buildLoadingContent(context),
      error: (error, stackTrace) => _buildErrorContent(error.toString()),
      data: (data) =>
          _buildDataContent(context, data, activeOrder: activeOrder),
    );
  }

  Future<void> _hydrateCurrentUserLocation() async {
    try {
      final lastKnown = await MapPickerHelpers.lastKnownLocationIfPermitted();
      if (!mounted) {
        return;
      }

      if (lastKnown != null) {
        _setCurrentUserLocation(lastKnown);
      }

      final target = await MapPickerHelpers.currentLocationIfPermitted();
      if (!mounted) {
        return;
      }

      if (target != null) {
        _setCurrentUserLocation(target);
      }
    } catch (_) {
      // Keep the home screen usable when platform location is unavailable.
    } finally {
      if (mounted && _isResolvingCurrentLocation) {
        setState(() => _isResolvingCurrentLocation = false);
      }
    }
  }

  void _setCurrentUserLocation(LatLng target) {
    ref.read(currentUserLocationProvider.notifier).setLocation(target);
  }

  _HomeDataRequest _homeRequestFor(
    SavedAddressModel? activeAddress,
    LatLng? currentUserLocation,
  ) {
    if (currentUserLocation != null) {
      return (
        latitude: currentUserLocation.latitude,
        longitude: currentUserLocation.longitude,
      );
    }

    return (
      latitude: _usableCoordinate(activeAddress?.latitude),
      longitude: _usableCoordinate(activeAddress?.longitude),
    );
  }

  SavedAddressModel? _activeAddress(UserProfileModel? profile) {
    final addresses = profile?.addresses ?? const <SavedAddressModel>[];
    if (addresses.isEmpty) {
      return null;
    }

    return addresses.firstWhere(
      (address) => address.isDefault,
      orElse: () => addresses.first,
    );
  }

  double? _usableCoordinate(double? value) {
    if (value == null || value == 0) {
      return null;
    }

    return value;
  }

  Future<void> _openAddressPicker() async {
    final session = ref.read(authSessionProvider);
    if (isGuestSession(session)) {
      await showGuestLoginPrompt(
        context,
        title: 'Masuk untuk mengatur lokasi',
        message:
            'Alamat tersimpan dipakai untuk estimasi jarak dan titik antar pesanan Anda.',
        returnTo: AppRoutes.addressPicker,
      );
      return;
    }

    final changed = await context.push<bool>(AppRoutes.addressPicker);
    if (changed == true && mounted) {
      await ref.read(authSessionProvider.notifier).refreshSession();
    }
  }

  Widget _buildHeader(
    BuildContext context,
    SavedAddressModel? activeAddress, {
    required bool isScrolled,
  }) {
    final addressText = activeAddress?.displayAddress.trim() ?? '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: isScrolled ? 1 : 0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: isScrolled ? 0.06 : 0),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openAddressPicker,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const SizedBox.square(
                              dimension: 28,
                              child: Icon(
                                Icons.location_on_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Lokasi Anda',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(fontSize: 14.25),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    addressText.isEmpty
                                        ? 'Pilih alamat untuk estimasi lebih akurat'
                                        : addressText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11.5,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
    );
  }

  void _openServiceChat(BuildContext context, String serviceType) {
    final target =
        '${AppRoutes.chatbot}?service_type=${Uri.encodeComponent(serviceType)}';

    final session = ref.read(authSessionProvider);
    if (isGuestSession(session)) {
      showGuestLoginPrompt(
        context,
        title: 'Masuk untuk mulai memesan',
        message:
            'Anda tetap bisa melihat toko dan menu sebagai tamu. Untuk membuat pesanan, kami perlu akun agar alamat, pembayaran, dan status pesanan tersimpan.',
        returnTo: target,
      );
      return;
    }

    context.push(target);
  }

  void _openMerchantDetail(BuildContext context, MerchantModel merchant) {
    if (merchant.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detail tempat tidak tersedia.')),
      );
      return;
    }

    context.push(AppRoutes.merchantDetailPath(merchant.id), extra: merchant);
  }

  Widget _buildServiceSection(BuildContext context) {
    final textScale = _layoutTextScale(context);
    final topPadding = _lerp(18, 20, textScale);
    final bottomPadding = _lerp(18, 22, textScale);

    return ClipRect(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.background),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/background.png'),
                    fit: BoxFit.cover,
                    alignment: Alignment(0, -0.80),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.white.withValues(alpha: 0.38),
                      AppColors.white.withValues(alpha: 0.72),
                      AppColors.background,
                    ],
                    stops: const [0, 0.58, 1],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(0, topPadding, 0, bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HomeSectionHeader(title: 'Layanan Bang Deliv'),
                  const SizedBox(height: 12),
                  _buildServiceCards(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCards(BuildContext context) {
    final textScale = _layoutTextScale(context);
    final serviceTileHeight = _lerp(94, 124, textScale);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _homeHorizontalPadding),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: serviceTileHeight),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildServiceTile(
              context: context,
              title: 'Antar Jemput',
              serviceType: 'antar_jemput',
              height: serviceTileHeight,
            ),
            _buildServiceTile(
              context: context,
              title: 'Kurir',
              serviceType: 'kurir',
              height: serviceTileHeight,
            ),
            _buildServiceTile(
              context: context,
              title: 'Nitip',
              serviceType: 'nitip',
              height: serviceTileHeight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceTile({
    required BuildContext context,
    required String title,
    required String serviceType,
    required double height,
  }) {
    void handleTap() => _openServiceChat(context, serviceType);
    final textScale = _layoutTextScale(context);
    final iconHeight = _lerp(58, 54, textScale);
    final frameSize = _lerp(50, 47, textScale);
    final iconWidth = _lerp(68, 62, textScale);
    final titleFontSize = _lerp(12, 11.25, textScale);

    return Expanded(
      child: Semantics(
        button: true,
        label: title,
        onTap: handleTap,
        child: ExcludeSemantics(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: handleTap,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: height,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ServiceVisualIcon(
                      serviceCode: serviceType,
                      height: iconHeight,
                      frameSize: frameSize,
                      iconWidth: iconWidth,
                      iconHeight: iconHeight - 6,
                    ),
                    SizedBox(height: _lerp(7, 6, textScale)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: titleFontSize,
                          height: 1.05,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildServiceSection(context),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: _homeHorizontalPadding),
          child: BangLoadingSkeleton(height: 164),
        ),
        const SizedBox(height: 24),
        const _HomeSectionHeader(title: 'Toko & Resto Terdekat'),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: _homeHorizontalPadding),
          child: BangLoadingSkeleton(height: 96),
        ),
        const SizedBox(height: _homeBottomNavClearance),
      ],
    );
  }

  Widget _buildErrorContent(String message) {
    return Column(
      children: [
        _buildServiceSection(context),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _homeHorizontalPadding,
            40,
            _homeHorizontalPadding,
            0,
          ),
          child: BangErrorState(
            title: 'Gagal memuat data beranda',
            message: message,
            onRetry: () => unawaited(_refreshHomeData()),
          ),
        ),
        const SizedBox(height: _homeBottomNavClearance + 24),
      ],
    );
  }

  Widget _buildDataContent(
    BuildContext context,
    HomeDataModel data, {
    required CustomerOrderSummaryModel? activeOrder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildServiceSection(context),
        if (activeOrder != null) ...[
          const SizedBox(height: 16),
          _buildActiveOrderCard(context, activeOrder),
          const SizedBox(height: 24),
        ] else ...[
          const SizedBox(height: 12),
        ],
        _HomeSectionHeader(
          title: 'Toko & Resto Terdekat',
          actionLabel: 'Lihat semua',
          onAction: () => context.push(AppRoutes.nearbyMerchants),
        ),
        const SizedBox(height: 12),
        _buildNearbyMerchants(data),
        const SizedBox(height: _homeBottomNavClearance),
      ],
    );
  }

  Widget _buildActiveOrderCard(
    BuildContext context,
    CustomerOrderSummaryModel order,
  ) {
    final statusColor = orderStatusColor(order.statusCode);
    final openTracking = order.canTrack
        ? () => context.push(AppRoutes.track, extra: order.id)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _homeHorizontalPadding),
      child: BangCard(
        padding: const EdgeInsets.all(16),
        onTap: openTracking,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pesanan aktif',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _ActiveOrderStatusLabel(
                        label: order.statusLabel,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              order.restaurantName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatCurrency(order.totalAmount),
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(
                  width: 86,
                  height: 34,
                  child: OutlinedButton(
                    onPressed: openTracking,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Lacak',
                        maxLines: 1,
                        softWrap: false,
                        style: GoogleFonts.inter(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
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
    );
  }

  Widget _buildNearbyMerchants(HomeDataModel data) {
    if (data.nearbyMerchants.isEmpty) {
      return _buildEmptySection('Belum ada toko/resto terdekat.');
    }

    final merchants = data.nearbyMerchants
        .take(_homeNearbyMerchantLimit)
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _homeHorizontalPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardMainAxisExtent = nearbyMerchantCardGridMainAxisExtent(
            context,
            gridWidth: constraints.maxWidth,
          );

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: merchants.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: cardMainAxisExtent,
            ),
            itemBuilder: (context, index) {
              final merchant = merchants[index];

              return NearbyMerchantCard(
                merchant: merchant,
                onTap: () => _openMerchantDetail(context, merchant),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptySection(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _homeHorizontalPadding),
      child: BangEmptyState(message: message),
    );
  }

  double _layoutTextScale(BuildContext context) {
    return MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, AppTextScaling.maxScaleFactor);
  }

  double _lerp(double normal, double large, double textScale) {
    final t = ((textScale - 1) / (AppTextScaling.maxScaleFactor - 1)).clamp(
      0.0,
      1.0,
    );
    return normal + ((large - normal) * t);
  }
}

class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final canShowAction = actionLabel != null && onAction != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _homeHorizontalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.08,
              ),
            ),
          ),
          if (canShowAction) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.only(left: 4, right: 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerRight,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 1),
                  const Icon(Icons.chevron_right_rounded, size: 14),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveOrderStatusLabel extends StatelessWidget {
  const _ActiveOrderStatusLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 190),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              softWrap: true,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
