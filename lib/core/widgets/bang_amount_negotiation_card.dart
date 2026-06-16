import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../utils/order_formatters.dart';
import 'bang_action_button.dart';

class BangAmountNegotiationCard extends StatelessWidget {
  const BangAmountNegotiationCard({
    super.key,
    required this.label,
    required this.amount,
    required this.onApprove,
    required this.onCounter,
    required this.onCancel,
    this.icon = Icons.request_quote_outlined,
    this.isEnabled = true,
    this.approveLoading = false,
    this.counterLoading = false,
    this.cancelLoading = false,
  });

  final String label;
  final double amount;
  final IconData icon;
  final VoidCallback onApprove;
  final VoidCallback onCounter;
  final VoidCallback onCancel;
  final bool isEnabled;
  final bool approveLoading;
  final bool counterLoading;
  final bool cancelLoading;

  bool get _hasLoading => approveLoading || counterLoading || cancelLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$label: ${formatCurrency(amount)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: BangActionButton(
                  label: 'OK',
                  isEnabled: isEnabled && (!_hasLoading || approveLoading),
                  isLoading: approveLoading,
                  onPressed: onApprove,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BangActionButton(
                  label: 'Tawar',
                  variant: BangActionButtonVariant.outlined,
                  isEnabled: isEnabled && (!_hasLoading || counterLoading),
                  isLoading: counterLoading,
                  onPressed: onCounter,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BangActionButton(
                  label: 'Batal',
                  variant: BangActionButtonVariant.outlined,
                  isEnabled: isEnabled && (!_hasLoading || cancelLoading),
                  isLoading: cancelLoading,
                  onPressed: onCancel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
