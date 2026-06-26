import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../services/customer_order_api_service.dart';
import 'shopping_inline_info_panel.dart';
import 'shopping_widget_helpers.dart';

class ShoppingMerchantSearchSection extends StatelessWidget {
  const ShoppingMerchantSearchSection({
    super.key,
    required this.controller,
    required this.canSearch,
    required this.isLoading,
    required this.merchants,
    required this.selectedMerchant,
    required this.onSearch,
    this.onOpenMapPicker,
    required this.onSelect,
  });

  final TextEditingController controller;
  final bool canSearch;
  final bool isLoading;
  final List<ShoppingMerchantOption> merchants;
  final ShoppingMerchantOption? selectedMerchant;
  final VoidCallback onSearch;
  final VoidCallback? onOpenMapPicker;
  final ValueChanged<ShoppingMerchantOption> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShoppingSectionTitle(
          title: 'Pilih Toko/Resto',
          subtitle: 'Tentukan tempat pembelian item tambahan.',
        ),
        const SizedBox(height: 10),
        if (canSearch) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Cari toko, resto, atau minimarket',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 46,
                height: 46,
                child: IconButton.filled(
                  tooltip: 'Cari toko/resto',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isLoading ? null : onSearch,
                  icon: isLoading
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Icon(Icons.search_rounded, size: 20),
                ),
              ),
              if (onOpenMapPicker != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 46,
                  height: 46,
                  child: IconButton.outlined(
                    tooltip: 'Pilih lewat peta',
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isLoading ? null : onOpenMapPicker,
                    icon: const Icon(Icons.map_outlined, size: 20),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (isLoading && merchants.isEmpty)
          const ShoppingInlineInfoPanel(
            icon: Icons.storefront_outlined,
            text: 'Memuat toko/resto...',
          )
        else if (merchants.isEmpty)
          const ShoppingEmptyPanel(text: 'Toko/resto tidak ditemukan.')
        else
          Column(
            children: [
              for (final merchant in merchants) ...[
                _MerchantOptionCard(
                  merchant: merchant,
                  selected: _isSameMerchantOption(selectedMerchant, merchant),
                  onTap: () => onSelect(merchant),
                ),
                if (merchant != merchants.last) const SizedBox(height: 8),
              ],
            ],
          ),
      ],
    );
  }
}

bool _isSameMerchantOption(
  ShoppingMerchantOption? selected,
  ShoppingMerchantOption merchant,
) {
  if (selected == null) {
    return false;
  }

  if (selected.id > 0 || merchant.id > 0) {
    return selected.id == merchant.id;
  }

  return selected.name.trim().toLowerCase() ==
          merchant.name.trim().toLowerCase() &&
      selected.address?.trim().toLowerCase() ==
          merchant.address?.trim().toLowerCase();
}

class _MerchantOptionCard extends StatelessWidget {
  const _MerchantOptionCard({
    required this.merchant,
    required this.selected,
    required this.onTap,
  });

  final ShoppingMerchantOption merchant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryLight
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  shoppingMerchantIcon(merchant.merchantType),
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            merchant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ShoppingTypeBadge(type: merchant.merchantType),
                      ],
                    ),
                    if ((merchant.address ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        merchant.address!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.check_rounded,
                  color: AppColors.primary,
                  size: 19,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
