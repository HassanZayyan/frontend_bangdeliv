import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../models/merchant_model.dart';

class NearbyMerchantCard extends StatelessWidget {
  const NearbyMerchantCard({
    super.key,
    required this.merchant,
    required this.onTap,
  });

  final MerchantModel merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distance = merchant.distance.trim();
    final scaleT = AppTextScaling.scaleProgress(context);
    final titleFontSize = 14.0 - (0.5 * scaleT);
    final distanceFontSize = 10.25 - (0.25 * scaleT);
    final imageAspectRatio = AppTextScaling.adaptive(
      context,
      normal: 1.32,
      large: 1.38,
    );

    return Material(
      color: AppColors.white,
      elevation: 2,
      shadowColor: AppColors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: imageAspectRatio,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _MerchantImage(imageUrl: merchant.imageUrl),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  merchant.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                if (distance.isNotEmpty && distance != '-') ...[
                  const SizedBox(height: 3),
                  Text(
                    distance,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: distanceFontSize,
                      fontWeight: FontWeight.w600,
                      height: 1.12,
                    ),
                  ),
                ],
              ],
            ),
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
    if (imageUrl.isEmpty) {
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
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.surfaceAlt),
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
                Icons.storefront_rounded,
                size: 34,
                color: AppColors.textMuted,
              ),
      ),
    );
  }
}
