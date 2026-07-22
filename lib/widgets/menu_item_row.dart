import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../config/app_text_scaling.dart';

/// Baris item menu bersama: thumbnail + nama + label harga + trailing opsional.
/// Chrome kontainer (padding/border/card) tetap tanggung jawab pemanggil.
class MenuItemRow extends StatelessWidget {
  const MenuItemRow({
    super.key,
    required this.name,
    this.priceLabel,
    this.pendingPrice = false,
    this.imageUrl,
    this.thumbnailSize = 48,
    this.showThumbnailFallback = false,
    this.maxNameLines = 2,
    this.stackedMaxNameLines,
    this.nameStyle,
    this.priceStyle,
    this.namePriceSpacing = 4,
    this.trailing,
    this.stackTrailingOnNarrow = false,
  });

  final String name;
  final String? priceLabel;

  /// Menggeser gaya harga default ke tampilan "harga menunggu nota".
  /// Diabaikan jika [priceStyle] diberikan.
  final bool pendingPrice;
  final String? imageUrl;
  final double thumbnailSize;

  /// true: gambar gagal dimuat menampilkan placeholder ikon;
  /// false: gagal dimuat menghilang tanpa jejak.
  final bool showThumbnailFallback;
  final int maxNameLines;

  /// maxLines nama saat layout sempit menumpuk trailing di bawah detail.
  final int? stackedMaxNameLines;
  final TextStyle? nameStyle;
  final TextStyle? priceStyle;
  final double namePriceSpacing;
  final Widget? trailing;

  /// true: pada lebar < 340 trailing pindah ke bawah detail (pola chatbot).
  final bool stackTrailingOnNarrow;

  @override
  Widget build(BuildContext context) {
    final trimmedPrice = (priceLabel ?? '').trim();
    final trimmedImage = (imageUrl ?? '').trim();

    final resolvedNameStyle =
        nameStyle ??
        TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppTextScaling.adaptive(context, normal: 13, large: 12.4),
          fontWeight: FontWeight.w800,
          height: 1.24,
        );
    final resolvedPriceStyle =
        priceStyle ??
        TextStyle(
          color: pendingPrice ? AppColors.textSecondary : AppColors.primary,
          fontSize: AppTextScaling.adaptive(context, normal: 12, large: 11.4),
          fontWeight: pendingPrice ? FontWeight.w600 : FontWeight.w700,
        );

    Widget details(int nameLines) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: nameLines,
            overflow: TextOverflow.ellipsis,
            style: resolvedNameStyle,
          ),
          if (trimmedPrice.isNotEmpty) ...[
            SizedBox(height: namePriceSpacing),
            Text(
              trimmedPrice,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolvedPriceStyle,
            ),
          ],
        ],
      );
    }

    Widget? thumbnail;
    if (trimmedImage.isNotEmpty) {
      thumbnail = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox.square(
          dimension: thumbnailSize,
          child: Image.network(
            trimmedImage,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              if (!showThumbnailFallback) {
                return const SizedBox.shrink();
              }
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
      );
    }

    Widget inlineRow() {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (thumbnail != null) ...[thumbnail, const SizedBox(width: 12)],
          Expanded(child: details(maxNameLines)),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      );
    }

    if (!stackTrailingOnNarrow) {
      return inlineRow();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 340) {
          return inlineRow();
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thumbnail != null) ...[thumbnail, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  details(stackedMaxNameLines ?? maxNameLines),
                  const SizedBox(height: 10),
                  if (trailing != null)
                    Align(alignment: Alignment.centerRight, child: trailing!),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
