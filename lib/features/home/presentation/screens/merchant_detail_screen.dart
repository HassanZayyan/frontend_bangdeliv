import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_colors.dart';
import '../../../../models/merchant_model.dart';
import '../../../../core/di/app_providers.dart';

class MerchantDetailScreen extends ConsumerWidget {
  const MerchantDetailScreen({
    super.key,
    required this.merchantId,
    this.initialMerchant,
  });

  final String merchantId;
  final MerchantModel? initialMerchant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallbackMerchant = initialMerchant;

    if (fallbackMerchant != null) {
      return _MerchantDetailView(merchant: fallbackMerchant);
    }

    final homeDataAsync = ref.watch(homeDataProvider);

    return homeDataAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const _MerchantDetailErrorState(
        message: 'Gagal memuat detail merchant.',
      ),
      data: (homeData) {
        MerchantModel? matchedMerchant;
        for (final merchant in homeData.nearbyMerchants) {
          if (merchant.id == merchantId) {
            matchedMerchant = merchant;
            break;
          }
        }

        if (matchedMerchant == null) {
          return const _MerchantDetailErrorState(
            message: 'Merchant tidak ditemukan.',
          );
        }

        return _MerchantDetailView(merchant: matchedMerchant);
      },
    );
  }
}

class _MerchantDetailView extends StatelessWidget {
  const _MerchantDetailView({required this.merchant});

  final MerchantModel merchant;

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
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: double.infinity,
                height: 220,
                child: merchant.imageUrl.isEmpty
                    ? Container(
                        color: AppColors.primaryLight,
                        child: const Icon(
                          Icons.storefront_outlined,
                          size: 56,
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
              merchant.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  merchant.distance,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
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
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Informasi detail merchant akan ditampilkan lebih lengkap pada pembaruan berikutnya.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MerchantDetailErrorState extends StatelessWidget {
  const _MerchantDetailErrorState({required this.message});

  final String message;

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
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
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
