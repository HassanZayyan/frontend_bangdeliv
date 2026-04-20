import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/food_model.dart';
import '../models/home_data_model.dart';
import '../models/merchant_model.dart';
import '../providers/api_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeDataAsync = ref.watch(homeDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.white,
                onRefresh: () async {
                  ref.invalidate(homeDataProvider);
                  await ref.read(homeDataProvider.future);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: homeDataAsync.when(
                    loading: () => _buildLoadingContent(context),
                    error: (error, stackTrace) =>
                        _buildErrorContent(error.toString()),
                    data: (data) => _buildDataContent(context, data),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(color: AppColors.primary),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          ref.read(homeSearchQueryProvider.notifier).setQuery(value);
        },
        decoration: InputDecoration(
          hintText: 'Cari restoran atau menu...',
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  void _openServiceChat(BuildContext context, String serviceType) {
    final target =
        '${AppRoutes.chatbot}?service_type=${Uri.encodeComponent(serviceType)}';
    context.push(target);
  }

  void _openPopularMenuDetail(BuildContext context, FoodModel food) {
    if (food.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detail menu tidak tersedia.')),
      );
      return;
    }

    context.push(AppRoutes.menuDetailPath(food.id), extra: food);
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildServiceCard(
            context: context,
            title: 'Antar Jemput',
            serviceType: 'antar_jemput',
            icon: Icons.route,
            color: AppColors.primary,
          ),
          _buildServiceCard(
            context: context,
            title: 'Kurir',
            serviceType: 'kurir',
            icon: Icons.local_shipping_outlined,
            color: AppColors.primary,
          ),
          _buildServiceCard(
            context: context,
            title: 'Nitip',
            serviceType: 'nitip',
            icon: Icons.shopping_bag_outlined,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required BuildContext context,
    required String title,
    required String serviceType,
    required IconData icon,
    required Color color,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: () => _openServiceChat(context, serviceType),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.white, size: 32),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 92,
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildServiceCards(context),
        const SizedBox(height: 24),
        const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 32),
            child: CircularProgressIndicator(),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent(String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildServiceCards(context),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gagal memuat data beranda',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.invalidate(homeDataProvider),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataContent(BuildContext context, HomeDataModel data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildServiceCards(context),
        const SizedBox(height: 24),
        _buildSectionTitle('Kategori'),
        const SizedBox(height: 12),
        _buildCategories(data),
        const SizedBox(height: 24),
        _buildSectionTitle('Menu Populer'),
        const SizedBox(height: 12),
        _buildPopularMenus(data),
        const SizedBox(height: 24),
        _buildSectionTitle('Merchant Terdekat'),
        const SizedBox(height: 12),
        _buildNearbyMerchants(data),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildCategories(HomeDataModel data) {
    if (data.categories.isEmpty) {
      return _buildEmptySection('Belum ada kategori.');
    }

    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: data.categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = data.categories[index];

          return Container(
            constraints: const BoxConstraints(minWidth: 88),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(category.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 6),
                Text(
                  category.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPopularMenus(HomeDataModel data) {
    if (data.popularMenus.isEmpty) {
      return _buildEmptySection('Belum ada menu populer.');
    }

    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: data.popularMenus.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final food = data.popularMenus[index];

          return _buildPopularMenuCard(
            context: context,
            food: food,
            onTap: () => _openPopularMenuDetail(context, food),
          );
        },
      ),
    );
  }

  Widget _buildPopularMenuCard({
    required BuildContext context,
    required FoodModel food,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 180,
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 104,
                width: double.infinity,
                child: food.imageUrl.isEmpty
                    ? Container(
                        color: AppColors.primaryLight,
                        child: const Icon(Icons.restaurant_menu_outlined),
                      )
                    : Image.network(
                        food.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.primaryLight,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      food.restaurantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(food.rating.toStringAsFixed(1)),
                        const Spacer(),
                        Text(
                          food.formattedPrice,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNearbyMerchants(HomeDataModel data) {
    if (data.nearbyMerchants.isEmpty) {
      return _buildEmptySection('Belum ada merchant terdekat.');
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.nearbyMerchants.length,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final merchant = data.nearbyMerchants[index];

        return _buildNearbyMerchantCard(
          merchant: merchant,
          onTap: () => _openMerchantDetail(context, merchant),
        );
      },
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
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: merchant.imageUrl.isEmpty
                      ? Container(
                          color: AppColors.primaryLight,
                          child: const Icon(Icons.storefront_outlined),
                        )
                      : Image.network(
                          merchant.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: AppColors.primaryLight,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${merchant.distance} • ⭐ ${merchant.rating.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
