import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_text_scaling.dart';

class ShoppingSubmitBar extends StatelessWidget {
  const ShoppingSubmitBar({
    super.key,
    required this.itemCount,
    required this.totalQuantity,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final int itemCount;
  final int totalQuantity;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final canSubmit = itemCount > 0;
    final title = itemCount == 0
        ? 'Belum ada item'
        : '$itemCount item ditambahkan';
    final quantityLabel = canSubmit ? '$totalQuantity total qty' : '-';
    final detailText = !canSubmit
        ? 'Tambahkan item dulu untuk menyimpan'
        : 'Harga akhir diinput driver';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  quantityLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detailText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: AppTextScaling.adaptive(
                context,
                normal: 44,
                large: 50,
              ),
            ),
            child: ElevatedButton(
              onPressed: isSubmitting || !canSubmit ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Text(
                      'Simpan Item',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
