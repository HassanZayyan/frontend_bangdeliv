import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../models/home_data_model.dart';
import '../../../../models/merchant_model.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../widgets/bang_ui.dart';

class NearbyMerchantsScreen extends ConsumerStatefulWidget {
  const NearbyMerchantsScreen({super.key});

  @override
  ConsumerState<NearbyMerchantsScreen> createState() =>
      _NearbyMerchantsScreenState();
}

class _NearbyMerchantsScreenState extends ConsumerState<NearbyMerchantsScreen> {
  late final TextEditingController _searchController;
  late Future<HomeDataModel> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _future = _fetch();
  }

  Future<HomeDataModel> _fetch() {
    return ref.read(homeApiServiceProvider).fetchHomeData(search: _query);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _fetch();
    });
    await _future;
  }

  void _submitSearch(String value) {
    setState(() {
      _query = value.trim();
      _future = _fetch();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Toko & Resto Terdekat'),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: FutureBuilder<HomeDataModel>(
          future: _future,
          builder: (context, snapshot) {
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;
            final data = snapshot.data;
            final merchants = data?.nearbyMerchants ?? const <MerchantModel>[];

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 116),
                children: [
                  BangSearchField(
                    controller: _searchController,
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
                    const Column(
                      children: [
                        BangLoadingSkeleton(height: 96),
                        SizedBox(height: 12),
                        BangLoadingSkeleton(height: 96),
                        SizedBox(height: 12),
                        BangLoadingSkeleton(height: 96),
                      ],
                    )
                  else if (merchants.isEmpty)
                    const BangEmptyState(
                      message: 'Belum ada toko/resto terdekat.',
                      icon: Icons.storefront_outlined,
                    )
                  else
                    ...merchants.map(
                      (merchant) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MerchantListCard(
                          merchant: merchant,
                          onTap: () => context.push(
                            AppRoutes.merchantDetailPath(merchant.id),
                            extra: merchant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLocationInfo(int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Toko/resto diurutkan berdasarkan lokasi terdekat',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.addresses),
              child: const Text('Ubah Lokasi'),
            ),
          ],
        ),
        Text(
          '$count toko/resto ditemukan',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

class _MerchantListCard extends StatelessWidget {
  const _MerchantListCard({required this.merchant, required this.onTap});

  final MerchantModel merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BangCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 96,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              merchant.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Transform.translate(
            offset: const Offset(0, 1.5),
            child: Icon(
              Icons.keyboard_arrow_right_rounded,
              size: 21,
              color: AppColors.textSecondary.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}
