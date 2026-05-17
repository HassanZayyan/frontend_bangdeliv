import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../utils/order_formatters.dart';

class ShoppingFeeBreakdownItem {
  const ShoppingFeeBreakdownItem({
    required this.label,
    required this.description,
    required this.amount,
  });

  final String label;
  final String description;
  final double amount;
}

class ShoppingFeeBreakdown extends StatelessWidget {
  const ShoppingFeeBreakdown({super.key, required this.items});

  final List<ShoppingFeeBreakdownItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        dense: true,
        initiallyExpanded: items.length == 1,
        title: const Text(
          'Rincian service fee',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (item.description.trim().isNotEmpty)
                          Text(
                            item.description.trim(),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatCurrency(item.amount),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
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
