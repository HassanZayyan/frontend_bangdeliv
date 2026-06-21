import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../services/customer_order_api_service.dart';
import '../../../../utils/order_formatters.dart';
import '../../application/shopping_item_draft.dart';
import 'shopping_widget_helpers.dart';

class ShoppingDraftItemsSection extends StatelessWidget {
  const ShoppingDraftItemsSection({
    super.key,
    required this.items,
    required this.onDecrement,
    required this.onIncrement,
  });

  final List<ShoppingItemDraft> items;
  final ValueChanged<ShoppingItemDraft> onDecrement;
  final ValueChanged<ShoppingItemDraft> onIncrement;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<ShoppingItemDraft>>{};
    final merchantsByKey = <String, ShoppingMerchantOption>{};
    for (final item in items) {
      final merchantKey = _merchantGroupKey(item);
      groups.putIfAbsent(merchantKey, () => <ShoppingItemDraft>[]).add(item);
      merchantsByKey[merchantKey] = item.merchant;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShoppingSectionTitle(
          title: 'Daftar Item',
          subtitle: 'Ringkasan item yang akan ditambahkan.',
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const ShoppingEmptyPanel(text: 'Belum ada item yang ditambahkan.')
        else
          ...groups.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DraftMerchantGroup(
                merchant: merchantsByKey[entry.key]!,
                items: entry.value,
                onDecrement: onDecrement,
                onIncrement: onIncrement,
              ),
            ),
          ),
      ],
    );
  }
}

String _merchantGroupKey(ShoppingItemDraft item) {
  final merchantId = item.merchant.id;
  if (merchantId > 0) {
    return 'merchant:$merchantId';
  }

  final place = item.merchantPlace;
  final placeId = place?.placeId?.trim();
  if (placeId != null && placeId.isNotEmpty) {
    return 'place:$placeId';
  }

  return 'external:${item.merchant.name}:${item.merchant.latitude}:${item.merchant.longitude}';
}

class _DraftMerchantGroup extends StatelessWidget {
  const _DraftMerchantGroup({
    required this.merchant,
    required this.items,
    required this.onDecrement,
    required this.onIncrement,
  });

  final ShoppingMerchantOption merchant;
  final List<ShoppingItemDraft> items;
  final ValueChanged<ShoppingItemDraft> onDecrement;
  final ValueChanged<ShoppingItemDraft> onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
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
          const SizedBox(height: 8),
          ...items.map(
            (item) => _DraftItemTile(
              item: item,
              onDecrement: () => onDecrement(item),
              onIncrement: () => onIncrement(item),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftItemTile extends StatelessWidget {
  const _DraftItemTile({
    required this.item,
    required this.onDecrement,
    required this.onIncrement,
  });

  final ShoppingItemDraft item;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final notes = (item.notes ?? '').trim();
    final unitPrice = item.unitPrice ?? 0;
    final hasReferencePrice = item.isFromMenu && unitPrice > 0;
    final priceLabel = item.isFromMenu
        ? hasReferencePrice
              ? 'Referensi ${formatCurrency(unitPrice)}'
              : 'Harga belum tersedia'
        : 'Harga menunggu input driver';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.isFromMenu) ...[
                  const SizedBox(height: 2),
                  Text(
                    priceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (!item.isFromMenu) ...[
                  const SizedBox(height: 2),
                  Text(
                    priceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    notes,
                    maxLines: 2,
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
          const SizedBox(width: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QuantityActionButton(
                icon: Icons.remove_rounded,
                tooltip: 'Kurangi item',
                onPressed: onDecrement,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _QuantityActionButton(
                icon: Icons.add_rounded,
                tooltip: 'Tambah item',
                onPressed: onIncrement,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityActionButton extends StatelessWidget {
  const _QuantityActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Material(
        color: AppColors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: Tooltip(
              message: tooltip,
              child: Icon(icon, color: AppColors.primary, size: 15),
            ),
          ),
        ),
      ),
    );
  }
}
