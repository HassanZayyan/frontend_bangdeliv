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
    this.subtitle,
    this.icon = Icons.request_quote_outlined,
    this.isEnabled = true,
    this.approveLoading = false,
    this.counterLoading = false,
    this.cancelLoading = false,
    this.previousAmount,
    this.amountLabel = 'Nominal baru',
    this.previousAmountLabel = 'Nominal sebelumnya',
    this.reasonLabel = 'Alasan driver',
    this.reason,
    this.supportingText,
    this.statusLabel = 'Menunggu',
    this.approveLabel = 'Setujui',
    this.counterLabel = 'Tawar',
    this.cancelLabel = 'Batalkan pesanan',
    this.counterIsDestructive = false,
    this.showCounterAction = true,
    this.showCancelAction = true,
    this.cancelAsFooter = true,
    this.showIcon = true,
    this.embedded = false,
  });

  final String label;
  final String? subtitle;
  final double amount;
  final IconData icon;
  final VoidCallback onApprove;
  final VoidCallback onCounter;
  final VoidCallback onCancel;
  final bool isEnabled;
  final bool approveLoading;
  final bool counterLoading;
  final bool cancelLoading;
  final double? previousAmount;
  final String amountLabel;
  final String previousAmountLabel;
  final String reasonLabel;
  final String? reason;
  final String? supportingText;
  final String statusLabel;
  final String approveLabel;
  final String counterLabel;
  final String cancelLabel;
  final bool counterIsDestructive;
  final bool showCounterAction;
  final bool showCancelAction;
  final bool cancelAsFooter;
  final bool showIcon;
  final bool embedded;

  bool get _hasLoading => approveLoading || counterLoading || cancelLoading;

  @override
  Widget build(BuildContext context) {
    final normalizedReason = (reason ?? '').trim();
    final normalizedSubtitle = (subtitle ?? '').trim();
    final normalizedSupportingText = (supportingText ?? '').trim();
    final hasPreviousAmount =
        previousAmount != null &&
        previousAmount! > 0 &&
        previousAmount!.round() != amount.round();

    return Semantics(
      container: true,
      label: '$label, ${formatCurrency(amount)}',
      child: Container(
        padding: embedded
            ? const EdgeInsets.only(top: 12)
            : const EdgeInsets.all(12),
        decoration: embedded
            ? const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              )
            : BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showIcon) ...[
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, color: AppColors.primaryDark, size: 17),
                  ),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: embedded ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                      if (normalizedSubtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          normalizedSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(label: statusLabel),
              ],
            ),
            const SizedBox(height: 12),
            _AmountRow(
              label: amountLabel,
              value: formatCurrency(amount),
              emphasized: true,
            ),
            if (hasPreviousAmount) ...[
              const SizedBox(height: 6),
              _AmountRow(
                label: previousAmountLabel,
                value: formatCurrency(previousAmount!),
                valueEmphasized: true,
              ),
            ],
            if (normalizedReason.isNotEmpty) ...[
              const SizedBox(height: 6),
              _AmountRow(
                label: reasonLabel,
                value: normalizedReason,
                valueEmphasized: true,
              ),
            ],
            if (normalizedSupportingText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                normalizedSupportingText,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (showCounterAction) ...[
                  Expanded(
                    child: BangActionButton(
                      label: counterLabel,
                      variant: BangActionButtonVariant.outlined,
                      isEnabled: isEnabled && (!_hasLoading || counterLoading),
                      isLoading: counterLoading,
                      progressColor: counterIsDestructive
                          ? AppColors.error
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: counterIsDestructive
                            ? AppColors.error
                            : AppColors.primaryDark,
                        side: BorderSide(
                          color:
                              (counterIsDestructive
                                      ? AppColors.error
                                      : AppColors.border)
                                  .withValues(alpha: 0.75),
                        ),
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: onCounter,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: BangActionButton(
                    label: approveLabel,
                    isEnabled: isEnabled && (!_hasLoading || approveLoading),
                    isLoading: approveLoading,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: onApprove,
                  ),
                ),
              ],
            ),
            if (showCancelAction && cancelAsFooter) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: isEnabled && (!_hasLoading || cancelLoading)
                      ? onCancel
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: cancelLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(cancelLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardYellow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.valueEmphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;
  final bool valueEmphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: emphasized ? 12.5 : 12,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: emphasized || valueEmphasized
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontSize: emphasized ? 15 : (valueEmphasized ? 13 : 12),
              fontWeight: emphasized
                  ? FontWeight.w900
                  : (valueEmphasized ? FontWeight.w800 : FontWeight.w700),
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}
