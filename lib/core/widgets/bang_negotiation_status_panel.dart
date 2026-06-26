import 'package:flutter/material.dart';

import '../../config/app_colors.dart';

class BangNegotiationStatusPanel extends StatelessWidget {
  const BangNegotiationStatusPanel({
    super.key,
    required this.icon,
    required this.label,
    required this.amountText,
    this.color = AppColors.primary,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String? amountText;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final amount = amountText?.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: compact
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: compact ? 12.5 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (amount.isNotEmpty)
            Text(
              amount,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}
