import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../models/merchant_model.dart';

const double _cardHorizontalPadding = 10;
const double _cardTopPadding = 10;
const double _cardBottomPadding = 8;
const double _imageTitleGap = 9;
const double _titleDistanceGap = 3;
const double _titleLineHeightFactor = 1.18;
const double _distanceLineHeightFactor = 1.12;
const double _layoutBuffer = 6;

double nearbyMerchantCardGridMainAxisExtent(
  BuildContext context, {
  required double gridWidth,
  int crossAxisCount = 2,
  double crossAxisSpacing = 12,
}) {
  final scaleT = AppTextScaling.scaleProgress(context);
  final imageAspectRatio = _imageAspectRatio(context);
  final availableGridWidth = gridWidth.isFinite && gridWidth > 0
      ? gridWidth
      : 320.0;
  final totalSpacing = crossAxisSpacing * (crossAxisCount - 1);
  final cardWidth = (availableGridWidth - totalSpacing) / crossAxisCount;
  final imageWidth = (cardWidth - (_cardHorizontalPadding * 2)).clamp(
    0.0,
    double.infinity,
  );
  final imageHeight = imageWidth / imageAspectRatio;
  final titleHeight = _titleBlockHeight(context, scaleT);
  final textScaler = MediaQuery.textScalerOf(context);
  final distanceHeight =
      textScaler.scale(_distanceFontSize(scaleT)) * _distanceLineHeightFactor;

  return (_cardTopPadding +
          imageHeight +
          _imageTitleGap +
          titleHeight +
          _titleDistanceGap +
          distanceHeight +
          _cardBottomPadding +
          _layoutBuffer)
      .ceilToDouble();
}

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
    final titleFontSize = _titleFontSize(scaleT);
    final distanceFontSize = _distanceFontSize(scaleT);
    final imageAspectRatio = _imageAspectRatio(context);
    final titleBlockHeight = _titleBlockHeight(context, scaleT);

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
            padding: const EdgeInsets.fromLTRB(
              _cardHorizontalPadding,
              _cardTopPadding,
              _cardHorizontalPadding,
              _cardBottomPadding,
            ),
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
                SizedBox(
                  height: titleBlockHeight,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      merchant.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w800,
                        height: _titleLineHeightFactor,
                      ),
                    ),
                  ),
                ),
                if (distance.isNotEmpty && distance != '-') ...[
                  const SizedBox(height: _titleDistanceGap),
                  Text(
                    distance,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: distanceFontSize,
                      fontWeight: FontWeight.w600,
                      height: _distanceLineHeightFactor,
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

double _titleFontSize(double scaleT) => 14.0 - (0.5 * scaleT);

double _distanceFontSize(double scaleT) => 10.25 - (0.25 * scaleT);

double _titleBlockHeight(BuildContext context, double scaleT) {
  final scaledTitleSize = MediaQuery.textScalerOf(
    context,
  ).scale(_titleFontSize(scaleT));
  return scaledTitleSize * _titleLineHeightFactor * 2;
}

double _imageAspectRatio(BuildContext context) {
  return AppTextScaling.adaptive(context, normal: 1.32, large: 1.38);
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
