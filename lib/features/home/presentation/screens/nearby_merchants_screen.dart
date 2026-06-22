import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../models/merchant_model.dart';
import '../../../../models/user_profile_model.dart';
import '../../../../core/di/app_providers.dart';
import '../../../auth/application/auth_session_provider.dart';
import '../../../navigation/presentation/widgets/bang_floating_bottom_nav_bar.dart';
import '../../../../widgets/bang_ui.dart';
import 'merchant_detail_screen.dart';
import '../widgets/nearby_merchant_card.dart';

class NearbyMerchantsScreen extends ConsumerStatefulWidget {
  const NearbyMerchantsScreen({super.key});

  @override
  ConsumerState<NearbyMerchantsScreen> createState() =>
      _NearbyMerchantsScreenState();
}

class _NearbyMerchantsScreenState extends ConsumerState<NearbyMerchantsScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Future<List<MerchantModel>>? _merchantsFuture;
  String _query = '';
  bool _wasKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<List<MerchantModel>> get _currentFuture {
    return _merchantsFuture ??= _fetch();
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || MediaQuery.viewInsetsOf(context).bottom > 0) {
          return;
        }

        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
        }
      });
    }
  }

  Future<List<MerchantModel>> _fetch() {
    final activeAddress = _activeAddress(ref.read(authSessionProvider).profile);

    return ref
        .read(homeApiServiceProvider)
        .fetchNearbyMerchants(
          search: _query,
          latitude: _usableCoordinate(activeAddress?.latitude),
          longitude: _usableCoordinate(activeAddress?.longitude),
        );
  }

  Future<void> _refresh() async {
    final nextFuture = _fetch();
    setState(() {
      _merchantsFuture = nextFuture;
    });
    await nextFuture;
  }

  void _submitSearch(String value) {
    _searchFocusNode.unfocus();
    setState(() {
      _query = value.trim();
      _merchantsFuture = _fetch();
    });
  }

  void _goHome() {
    context.go(AppRoutes.home);
  }

  Future<void> _openAddressPicker() async {
    final changed = await context.push<bool>(AppRoutes.addressPicker);
    if (!mounted) {
      return;
    }

    if (changed == true) {
      await ref.read(authSessionProvider.notifier).refreshSession();
      if (!mounted) {
        return;
      }
      final nextFuture = _fetch();
      setState(() {
        _merchantsFuture = nextFuture;
      });
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _goHome();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Toko & Resto Terdekat',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Kembali',
            onPressed: _goHome,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: FutureBuilder<List<MerchantModel>>(
            future: _currentFuture,
            builder: (context, snapshot) {
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;
              final merchants = snapshot.data ?? const <MerchantModel>[];

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    BangFloatingBottomNavBar.scrollClearance,
                  ),
                  children: [
                    BangSearchField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      hintText: 'Cari resto, minimarket, atau warung...',
                      onSubmitted: _submitSearch,
                    ),
                    const SizedBox(height: 18),
                    _buildLocationInfo(merchants.length),
                    const SizedBox(height: 14),
                    if (snapshot.hasError)
                      BangErrorState(
                        title: 'Gagal memuat toko/resto',
                        message: snapshot.error.toString(),
                        onRetry: _refresh,
                      )
                    else if (isLoading)
                      _buildMerchantGrid(
                        itemCount: 6,
                        itemBuilder: (context, index) =>
                            const BangLoadingSkeleton(height: double.infinity),
                      )
                    else if (merchants.isEmpty)
                      const BangEmptyState(
                        message: 'Belum ada toko/resto terdekat.',
                        icon: Icons.storefront_outlined,
                      )
                    else
                      _buildMerchantGrid(
                        itemCount: merchants.length,
                        itemBuilder: (context, index) {
                          final merchant = merchants[index];

                          return NearbyMerchantCard(
                            merchant: merchant,
                            onTap: () => context.push(
                              AppRoutes.nearbyMerchantDetailPath(merchant.id),
                              extra: MerchantDetailArgs(
                                merchant: merchant,
                                returnPath: AppRoutes.nearbyMerchants,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLocationInfo(int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Toko/resto diurutkan berdasarkan lokasi terdekat',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
            TextButton(
              onPressed: _openAddressPicker,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: AppTextScaling.clampForCompactComponent(
                context: context,
                maxScaleFactor: AppTextScaling.denseComponentMaxScaleFactor,
                child: const Text(
                  'Ubah Lokasi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Text(
            '$count toko/resto ditemukan',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMerchantGrid({
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
  }) {
    final cardMainAxisExtent = AppTextScaling.adaptive(
      context,
      normal: 182,
      large: 194,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: cardMainAxisExtent,
      ),
      itemBuilder: itemBuilder,
    );
  }
}
