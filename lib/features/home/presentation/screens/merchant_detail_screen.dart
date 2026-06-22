import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../models/chatbot_launch_args.dart';
import '../../../../models/food_model.dart';
import '../../../../models/merchant_detail_model.dart';
import '../../../../models/merchant_model.dart';

final _merchantDetailProvider = FutureProvider.autoDispose
    .family<MerchantDetailModel, String>((ref, merchantId) {
      return ref.watch(homeApiServiceProvider).fetchMerchantDetail(merchantId);
    });

class MerchantDetailArgs {
  const MerchantDetailArgs({required this.merchant, this.returnPath});

  final MerchantModel merchant;
  final String? returnPath;
}

class MerchantDetailScreen extends ConsumerWidget {
  const MerchantDetailScreen({
    super.key,
    required this.merchantId,
    this.initialMerchant,
    this.returnPath,
  });

  final String merchantId;
  final MerchantModel? initialMerchant;
  final String? returnPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedMerchantId = merchantId.trim();
    final fallbackMerchant = initialMerchant;

    if (normalizedMerchantId.isEmpty) {
      if (fallbackMerchant != null) {
        return _MerchantDetailView(
          merchant: fallbackMerchant,
          menus: const <FoodModel>[],
          returnPath: returnPath,
          menusError: 'Menu tempat eksternal belum tersedia.',
        );
      }

      return _MerchantDetailErrorState(
        message: 'Tempat tidak valid.',
        onBack: () => _handleBack(context),
      );
    }

    final detailAsync = ref.watch(
      _merchantDetailProvider(normalizedMerchantId),
    );

    return detailAsync.when(
      loading: () {
        if (fallbackMerchant == null) {
          return _MerchantDetailLoadingState(
            onBack: () => _handleBack(context),
          );
        }

        return _MerchantDetailView(
          merchant: fallbackMerchant,
          menus: const <FoodModel>[],
          returnPath: returnPath,
          isLoadingMenus: true,
        );
      },
      error: (error, stackTrace) {
        if (fallbackMerchant != null) {
          return _MerchantDetailView(
            merchant: fallbackMerchant,
            menus: const <FoodModel>[],
            returnPath: returnPath,
            menusError: 'Menu belum bisa dimuat. Tarik untuk coba lagi.',
          );
        }

        return _MerchantDetailErrorState(
          message: 'Gagal memuat detail tempat.',
          onBack: () => _handleBack(context),
        );
      },
      data: (detail) => _MerchantDetailView(
        merchant: detail.merchant,
        menus: detail.menus,
        returnPath: returnPath,
      ),
    );
  }

  void _handleBack(BuildContext context) {
    final target = returnPath;
    if (target != null && target.isNotEmpty) {
      context.go(target);
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    context.go(AppRoutes.home);
  }
}

class _MerchantDetailView extends StatelessWidget {
  const _MerchantDetailView({
    required this.merchant,
    required this.menus,
    this.returnPath,
    this.isLoadingMenus = false,
    this.menusError,
  });

  final MerchantModel merchant;
  final List<FoodModel> menus;
  final String? returnPath;
  final bool isLoadingMenus;
  final String? menusError;

  void _handleBack(BuildContext context) {
    final target = returnPath;
    if (target != null && target.isNotEmpty) {
      context.go(target);
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    context.go(AppRoutes.home);
  }

  void _openNitipChatbot(BuildContext context) {
    final merchantId = int.tryParse(merchant.id.trim());
    final menuSuggestions = menus
        .map(
          (menu) => ChatbotMenuSuggestion(
            name: menu.name,
            presetMessage: '${menu.name} 1',
            priceLabel: menu.formattedPrice,
            imageUrl: menu.imageUrl,
          ),
        )
        .toList(growable: false);
    final target = Uri(
      path: AppRoutes.chatbot,
      queryParameters: const <String, String>{'service_type': 'nitip'},
    ).toString();

    context.push(
      target,
      extra: ChatbotLaunchArgs(
        serviceType: 'nitip',
        merchantId: merchantId,
        merchantName: merchant.name,
        menuSuggestions: menuSuggestions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: returnPath == null || returnPath!.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _handleBack(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Detail Toko & Resto',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            onPressed: () => _handleBack(context),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openNitipChatbot(context),
              icon: const Icon(Icons.sms_outlined),
              label: const Text('Pesan di chatbot'),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MerchantHero(merchant: merchant),
              const SizedBox(height: 18),
              _MerchantInfo(merchant: merchant, menuCount: menus.length),
              const SizedBox(height: 22),
              _MenuSection(
                menus: menus,
                isLoading: isLoadingMenus,
                errorText: menusError,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MerchantHero extends StatelessWidget {
  const _MerchantHero({required this.merchant});

  final MerchantModel merchant;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: merchant.imageUrl.isEmpty
            ? Container(
                color: AppColors.primaryLight,
                child: const Icon(
                  Icons.storefront_outlined,
                  size: 58,
                  color: AppColors.primary,
                ),
              )
            : Image.network(
                merchant.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.primaryLight,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      size: 58,
                      color: AppColors.primary,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _MerchantInfo extends StatelessWidget {
  const _MerchantInfo({required this.merchant, required this.menuCount});

  final MerchantModel merchant;
  final int menuCount;

  @override
  Widget build(BuildContext context) {
    final address = merchant.address.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          merchant.name,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppTextScaling.adaptive(context, normal: 21, large: 19),
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.18,
          ),
        ),
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.location_on_outlined,
          text: address.isEmpty ? merchant.distance : address,
        ),
        if (merchant.distance.trim().isNotEmpty &&
            merchant.distance.trim() != '-' &&
            address.isNotEmpty) ...[
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.near_me_outlined, text: merchant.distance),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoPill(
              icon: Icons.restaurant_menu_outlined,
              label: menuCount > 0 ? '$menuCount menu tersedia' : 'Menu',
            ),
            if (merchant.merchantType.trim().isNotEmpty)
              _InfoPill(
                icon: Icons.storefront_outlined,
                label: _merchantTypeLabel(merchant.merchantType),
              ),
          ],
        ),
      ],
    );
  }

  String _merchantTypeLabel(String value) {
    return switch (value.trim()) {
      'warung' => 'Warung',
      'convenience_store' => 'Minimarket',
      'other' => 'Toko',
      _ => 'Restoran',
    };
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text.trim().isEmpty ? '-' : text,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondary,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({
    required this.menus,
    required this.isLoading,
    required this.errorText,
  });

  final List<FoodModel> menus;
  final bool isLoading;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Menu Restoran',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (isLoading)
          const _MenuLoadingList()
        else if ((errorText ?? '').trim().isNotEmpty)
          _MenuInfoCard(icon: Icons.info_outline_rounded, message: errorText!)
        else if (menus.isEmpty)
          const _MenuInfoCard(
            icon: Icons.restaurant_menu_outlined,
            message: 'Menu resmi tempat ini belum tersedia.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: menus.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _MenuTile(menu: menus[index]);
            },
          ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.menu});

  final FoodModel menu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.square(
              dimension: 64,
              child: menu.imageUrl.isEmpty
                  ? Container(
                      color: AppColors.primaryLight,
                      child: const Icon(
                        Icons.restaurant_menu_outlined,
                        color: AppColors.primary,
                      ),
                    )
                  : Image.network(
                      menu.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.primaryLight,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.primary,
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  menu.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  menu.formattedPrice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuInfoCard extends StatelessWidget {
  const _MenuInfoCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuLoadingList extends StatelessWidget {
  const _MenuLoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < 3; index++) ...[
          Container(
            height: 86,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
          ),
          if (index < 2) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MerchantDetailLoadingState extends StatelessWidget {
  const _MerchantDetailLoadingState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Detail Toko & Resto',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: onBack,
        ),
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _MerchantDetailErrorState extends StatelessWidget {
  const _MerchantDetailErrorState({
    required this.message,
    required this.onBack,
  });

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Detail Toko & Resto',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: onBack,
        ),
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
              TextButton(onPressed: onBack, child: const Text('Kembali')),
            ],
          ),
        ),
      ),
    );
  }
}
