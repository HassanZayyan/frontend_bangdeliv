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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatCurrency(amount),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: isEnabled && (!_hasLoading || cancelLoading)
                  ? onCancel
                  : null,
              child: cancelLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Batal',
                      style: TextStyle(color: AppColors.error),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
