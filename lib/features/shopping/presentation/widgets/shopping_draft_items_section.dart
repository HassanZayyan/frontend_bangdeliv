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
    required this.onEdit,
    required this.onRemove,
  });

  final List<ShoppingItemDraft> items;
  final ValueChanged<ShoppingItemDraft> onEdit;
  final ValueChanged<ShoppingItemDraft> onRemove;

  @override
  Widget build(BuildContext context) {
    final groups = <int, List<ShoppingItemDraft>>{};
    final merchantsById = <int, ShoppingMerchantOption>{};
    for (final item in items) {
      final merchantId = item.merchant.id;
      groups.putIfAbsent(merchantId, () => <ShoppingItemDraft>[]).add(item);
      merchantsById[merchantId] = item.merchant;
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
                merchant: merchantsById[entry.key]!,
                items: entry.value,
                onEdit: onEdit,
                onRemove: onRemove,
              ),
            ),
          ),
      ],
    );
  }
}

class _DraftMerchantGroup extends StatelessWidget {
  const _DraftMerchantGroup({
    required this.merchant,
    required this.items,
    required this.onEdit,
    required this.onRemove,
  });

  final ShoppingMerchantOption merchant;
  final List<ShoppingItemDraft> items;
  final ValueChanged<ShoppingItemDraft> onEdit;
  final ValueChanged<ShoppingItemDraft> onRemove;

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
              onEdit: item.isFromMenu ? null : () => onEdit(item),
              onRemove: () => onRemove(item),
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
    required this.onEdit,
    required this.onRemove,
  });

  final ShoppingItemDraft item;
  final VoidCallback? onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final notes = (item.notes ?? '').trim();
    final unitPrice = item.unitPrice ?? 0;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '${item.quantity}x',
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
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
                if (item.isFromMenu && unitPrice > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Harga menu: ${formatCurrency(unitPrice)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
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
          if (onEdit != null)
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                tooltip: 'Edit item',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 17),
              ),
            ),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              tooltip: 'Hapus item',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}
