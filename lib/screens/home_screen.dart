import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/home_data_model.dart';
import '../models/merchant_model.dart';
import '../models/customer_order_model.dart';
import '../models/user_profile_model.dart';
import '../providers/api_providers.dart';
import '../providers/auth_session_provider.dart';
import '../providers/customer_order_providers.dart';
import '../utils/order_formatters.dart';
import '../utils/order_ui_helpers.dart';
import '../widgets/app_content_background.dart';
import '../widgets/bang_ui.dart';
import '../widgets/service_visual_icon.dart';

typedef _HomeDataRequest = ({double? latitude, double? longitude});

final _homeScreenDataProvider = FutureProvider.autoDispose
    .family<HomeDataModel, _HomeDataRequest>((ref, request) async {
      final service = ref.watch(homeApiServiceProvider);

      return service.fetchHomeData(
        limitMerchants: 5,
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
  @override
  Widget build(BuildContext context) {
    final activeAddress = _activeAddress(
      ref.watch(authSessionProvider).profile,
    );
    final homeRequest = (
      latitude: _usableCoordinate(activeAddress?.latitude),
      longitude: _usableCoordinate(activeAddress?.longitude),
    );
    final homeDataAsync = ref.watch(_homeScreenDataProvider(homeRequest));
    final activeOrder = ref.watch(customerActiveOrderProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context, activeAddress),
            Expanded(
              child: AppContentBackground(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.white,
                  onRefresh: () => _refreshHomeData(homeRequest),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: homeDataAsync.when(
                      loading: () => _buildLoadingContent(context),
                      error: (error, stackTrace) =>
                          _buildErrorContent(error.toString(), homeRequest),
                      data: (data) => _buildDataContent(
                        context,
                        data,
                        activeOrder: activeOrder,
                      ),
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

  Future<void> _refreshHomeData(_HomeDataRequest request) async {
    ref.invalidate(_homeScreenDataProvider(request));
    try {
      await ref.read(_homeScreenDataProvider(request).future);
    } catch (_) {
      // Error state is rendered by _homeScreenDataProvider.
    }
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
    final changed = await context.push<bool>(AppRoutes.addressPicker);
    if (changed == true && mounted) {
      await ref.read(authSessionProvider.notifier).refreshSession();
    }
  }

  Widget _buildHeader(BuildContext context, SavedAddressModel? activeAddress) {
    final addressText = activeAddress?.displayAddress.trim() ?? '';

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openAddressPicker,
                      borderRadius: BorderRadius.circular(12),
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
                                              ?.copyWith(fontSize: 15),
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
                                      fontSize: 12,
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
                const SizedBox(width: 10),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Notifikasi',
                      onPressed: () => context.push(AppRoutes.notifications),
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: AppColors.textPrimary,
                        size: 24,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
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
    context.push(target);
  }

  void _openMerchantDetail(BuildContext context, MerchantModel merchant) {
    if (merchant.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detail merchant tidak tersedia.')),
      );
      return;
    }

    context.push(AppRoutes.merchantDetailPath(merchant.id), extra: merchant);
  }

  Widget _buildServiceCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildServiceTile(
            context: context,
            title: 'Antar Jemput',
            serviceType: 'antar_jemput',
          ),
          _buildServiceTile(
            context: context,
            title: 'Kurir',
            serviceType: 'kurir',
          ),
          _buildServiceTile(
            context: context,
            title: 'Nitip',
            serviceType: 'nitip',
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTile({
    required BuildContext context,
    required String title,
    required String serviceType,
  }) {
    void handleTap() => _openServiceChat(context, serviceType);

    return Expanded(
      child: Semantics(
        button: true,
        label: title,
        onTap: handleTap,
        child: ExcludeSemantics(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: handleTap,
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 100,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ServiceVisualIcon(serviceCode: serviceType),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          height: 1.08,
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
        const BangSectionHeader(title: 'Layanan BangDeliv'),
        const SizedBox(height: 12),
        _buildServiceCards(context),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: BangLoadingSkeleton(height: 164),
        ),
        const SizedBox(height: 24),
        const BangSectionHeader(title: 'Toko & Resto Terdekat'),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: BangLoadingSkeleton(height: 96),
        ),
        const SizedBox(height: 84),
      ],
    );
  }

  Widget _buildErrorContent(String message, _HomeDataRequest request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BangSectionHeader(title: 'Layanan BangDeliv'),
        const SizedBox(height: 12),
        _buildServiceCards(context),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: BangErrorState(
            title: 'Gagal memuat data beranda',
            message: message,
            onRetry: () => ref.invalidate(_homeScreenDataProvider(request)),
          ),
        ),
        const SizedBox(height: 84),
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
        const BangSectionHeader(title: 'Layanan BangDeliv'),
        const SizedBox(height: 12),
        _buildServiceCards(context),
        if (activeOrder != null) ...[
          const SizedBox(height: 20),
          _buildActiveOrderCard(context, activeOrder),
        ],
        const SizedBox(height: 24),
        BangSectionHeader(
          title: 'Toko & Resto Terdekat',
          actionLabel: 'Lihat semua',
          onAction: () => context.push(AppRoutes.nearbyMerchants),
        ),
        const SizedBox(height: 12),
        _buildNearbyMerchants(data),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildActiveOrderCard(
    BuildContext context,
    CustomerOrderSummaryModel order,
  ) {
    final statusColor = orderStatusColor(order.statusCode);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: BangCard(
        padding: const EdgeInsets.all(16),
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
                    style: GoogleFonts.nunitoSans(
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
                    onPressed: order.canTrack
                        ? () => context.push(AppRoutes.track, extra: order.id)
                        : null,
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
                        style: GoogleFonts.nunitoSans(
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

    final merchants = data.nearbyMerchants.take(5).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (final merchant in merchants) ...[
            _buildNearbyMerchantCard(
              merchant: merchant,
              onTap: () => _openMerchantDetail(context, merchant),
            ),
            if (merchant != merchants.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildNearbyMerchantCard({
    required MerchantModel merchant,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  merchant.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    height: 1.18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Transform.translate(
                offset: const Offset(0, 1.5),
                child: Icon(
                  Icons.keyboard_arrow_right_rounded,
                  size: 20,
                  color: AppColors.textSecondary.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySection(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: BangEmptyState(message: message),
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
