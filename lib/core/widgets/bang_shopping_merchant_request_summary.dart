import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../models/shopping_order_capability_model.dart';

class BangShoppingMerchantRequestSummary extends StatelessWidget {
  const BangShoppingMerchantRequestSummary({
    super.key,
    required this.request,
    this.compact = false,
  });

  final ShoppingItemChangeRequestModel request;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final stops = request.requestedStops;
    if (stops.isEmpty) {
      return _fallbackItems(request.items);
    }

    return Column(
      children: stops
          .map(
            (stop) => Padding(
              padding: EdgeInsets.only(bottom: stop == stops.last ? 0 : 10),
              child: _stopCard(stop),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _stopCard(ShoppingItemChangeRequestStopModel stop) {
    final requestLabel = _requestLabel(stop.requestKind ?? request.requestKind);
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.merchantName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        height: 1.2,
                      ),
                    ),
                    if ((stop.merchantAddress ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        stop.merchantAddress!.trim(),
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _chip(requestLabel),
            ],
          ),
          if (stop.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...stop.items.map(_itemRow),
          ],
        ],
      ),
    );
  }

  Widget _fallbackItems(List<ShoppingItemChangeRequestItemModel> items) {
    if (items.isEmpty) {
      return const Text(
        'Perubahan item menunggu keputusan driver.',
        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map(_itemRow).toList(growable: false),
    );
  }

  Widget _itemRow(ShoppingItemChangeRequestItemModel item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Icon(Icons.circle, size: 5, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${item.quantity <= 0 ? 1 : item.quantity}x ${item.name}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _requestLabel(String? rawKind) {
    final kind = (rawKind ?? '').trim().toUpperCase();
    if (kind == 'EDIT_UNAVAILABLE') {
      return 'Edit tempat';
    }

    return 'Tambah tempat';
  }
}
