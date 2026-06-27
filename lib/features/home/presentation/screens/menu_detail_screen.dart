import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../models/food_model.dart';
import '../../../../core/di/app_providers.dart';
import '../../../auth/application/auth_session_provider.dart';
import '../../../auth/presentation/widgets/guest_login_prompt.dart';

class MenuDetailScreen extends ConsumerWidget {
  const MenuDetailScreen({super.key, required this.menuId, this.initialMenu});

  final String menuId;
  final FoodModel? initialMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallbackMenu = initialMenu;

    if (fallbackMenu != null) {
      return _MenuDetailView(food: fallbackMenu);
    }

    final homeDataAsync = ref.watch(homeDataProvider);

    return homeDataAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) =>
          _MenuDetailErrorState(message: 'Gagal memuat detail menu.'),
      data: (homeData) {
        FoodModel? matchedMenu;
        for (final food in homeData.popularMenus) {
          if (food.id == menuId) {
            matchedMenu = food;
            break;
          }
        }

        if (matchedMenu == null) {
          return const _MenuDetailErrorState(message: 'Menu tidak ditemukan.');
        }

        return _MenuDetailView(food: matchedMenu);
      },
    );
  }
}

class _MenuDetailView extends ConsumerWidget {
  const _MenuDetailView({required this.food});

  final FoodModel food;

  void _openNitipChatbot(BuildContext context, WidgetRef ref) {
    final target = Uri(
      path: AppRoutes.chatbot,
      queryParameters: const {'service_type': 'nitip'},
    ).toString();

    final session = ref.read(authSessionProvider);
    if (isGuestSession(session)) {
      showGuestLoginPrompt(
        context,
        title: 'Masuk untuk pesan menu ini',
        message:
            'Anda bisa melihat detail menu sebagai tamu. Untuk membuat pesanan Nitip, masuk dulu agar pesanan tersimpan ke akun Anda.',
        returnTo: GoRouterState.of(context).uri.toString(),
      );
      return;
    }

    context.push(target);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasReferencePrice = food.hasReferencePrice;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Detail Menu',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openNitipChatbot(context, ref),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('Pesan via Nitip'),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: double.infinity,
                height: 220,
                child: food.imageUrl.isEmpty
                    ? Container(
                        color: AppColors.primaryLight,
                        child: const Icon(
                          Icons.restaurant_menu_outlined,
                          size: 56,
                          color: AppColors.primary,
                        ),
                      )
                    : Image.network(
                        food.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.primaryLight,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              size: 56,
                              color: AppColors.primary,
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              food.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    food.restaurantName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Harga',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    food.formattedPrice,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: hasReferencePrice
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: hasReferencePrice
                          ? AppColors.primary
                          : AppColors.textSecondary,
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

class _MenuDetailErrorState extends StatelessWidget {
  const _MenuDetailErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Detail Menu'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_outline,
                size: 38,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
