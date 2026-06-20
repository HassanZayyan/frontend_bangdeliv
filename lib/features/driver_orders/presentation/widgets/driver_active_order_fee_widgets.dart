import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../core/widgets/bang_action_button.dart';
import '../../../../core/widgets/bang_negotiation_status_panel.dart';
import '../../../../models/delivery_fee_negotiation_model.dart';
import '../../../../models/driver_order_model.dart';
import '../../../../utils/currency_formatter.dart';
import 'driver_active_order_widget_helpers.dart';

class DriverManualDeliveryFeeCard extends StatelessWidget {
  const DriverManualDeliveryFeeCard({
    super.key,
    required this.order,
    required this.isOrderBusy,
    required this.isSubmittingQuote,
    required this.isAcceptingCounter,
    required this.onSave,
    required this.onAcceptCounter,
  });

  final DriverOrderModel order;
  final bool isOrderBusy;
  final bool isSubmittingQuote;
  final bool isAcceptingCounter;
  final Future<String?> Function({
    required double amount,
    required String reason,
  })
  onSave;
  final Future<String?> Function() onAcceptCounter;

  @override
  Widget build(BuildContext context) {
    final deliveryFeeSource = (order.deliveryFeeSource ?? '')
        .trim()
        .toLowerCase();
    final deliveryFeeSourceLabel = deliveryFeeSource == 'driver_manual'
        ? 'manual driver'
        : deliveryFeeSource;
    final negotiation = order.deliveryFeeNegotiation;
    final canSubmitQuote = negotiation?.canDriverSubmitQuote ?? true;
    final canAcceptCounter = negotiation?.canDriverAcceptCounter ?? false;
    final counterAmount = negotiation?.counterAmount;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_road_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Revisi Ongkir',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isSubmittingQuote) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
              ],
              TextButton.icon(
                onPressed: isOrderBusy || isSubmittingQuote || !canSubmitQuote
                    ? null
                    : () => _openDialog(context),
                icon: const Icon(Icons.edit, size: 16),
                label: Text(
                  negotiation?.isPendingDriver == true
                      ? 'Kirim Harga Baru'
                      : 'Edit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip(
                'Jarak',
                order.deliveryDistanceLabel.isEmpty
                    ? '-'
                    : order.deliveryDistanceLabel,
              ),
              _summaryChip(
                'Ongkir final',
                order.deliveryFee == null
                    ? '-'
                    : formatRupiah(order.deliveryFee!),
              ),
              if (deliveryFeeSourceLabel.isNotEmpty)
                _summaryChip('Sumber', deliveryFeeSourceLabel),
            ],
          ),
          if (negotiation != null && negotiation.hasQuote) ...[
            const SizedBox(height: 10),
            _buildNegotiationStatus(negotiation),
          ],
          if (canAcceptCounter && counterAmount != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: BangActionButton(
                label: 'Setujui Tawaran Ongkir',
                icon: Icons.check_circle_outline,
                isLoading: isAcceptingCounter,
                isEnabled: !isOrderBusy || isAcceptingCounter,
                onPressed: () => _acceptCounter(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNegotiationStatus(DeliveryFeeNegotiationModel negotiation) {
    final amount = negotiation.displayAmount;
    final status = negotiation.status;
    final label = switch (status) {
      'PENDING_CUSTOMER' => 'Menunggu persetujuan customer',
      'PENDING_DRIVER' => 'Customer menawar',
      'APPROVED' => 'Disetujui',
      _ => 'Revisi ongkir',
    };

    return BangNegotiationStatusPanel(
      icon: status == 'APPROVED'
          ? Icons.verified_outlined
          : status == 'PENDING_DRIVER'
          ? Icons.handshake_outlined
          : Icons.schedule_outlined,
      label: label,
      amountText: amount == null ? null : formatRupiah(amount),
      color: status == 'APPROVED' ? AppColors.success : AppColors.primary,
      compact: true,
    );
  }

  Widget _summaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _openDialog(BuildContext context) async {
    final result = await showDialog<_ManualDeliveryFeeInput>(
      context: context,
      builder: (context) => _ManualDeliveryFeeDialog(
        initialAmount: order.deliveryFee,
        initialReason: '',
      ),
    );

    if (result == null) {
      return;
    }

    final error = await onSave(amount: result.amount, reason: result.reason);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Proposal revisi ongkir berhasil dikirim.'),
        backgroundColor: error == null ? null : AppColors.error,
      ),
    );
  }

  Future<void> _acceptCounter(BuildContext context) async {
    final error = await onAcceptCounter();
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Tawaran ongkir customer disetujui.'),
        backgroundColor: error == null ? null : AppColors.error,
      ),
    );
  }
}

class _ManualDeliveryFeeDialog extends StatefulWidget {
  const _ManualDeliveryFeeDialog({
    required this.initialAmount,
    required this.initialReason,
  });

  final double? initialAmount;
  final String initialReason;

  @override
  State<_ManualDeliveryFeeDialog> createState() =>
      _ManualDeliveryFeeDialogState();
}

class _ManualDeliveryFeeDialogState extends State<_ManualDeliveryFeeDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    final initialAmount = widget.initialAmount ?? 0;
    _amountController = TextEditingController(
      text: initialAmount > 0 ? initialAmount.round().toString() : '',
    );
    _reasonController = TextEditingController(text: widget.initialReason);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: viewInsets.bottom + 16,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit Ongkir Manual',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: driverDialogInputDecoration(
                        labelText: 'Ongkir dasar manual',
                        prefixText: 'Rp ',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _reasonController,
                      minLines: 2,
                      maxLines: 3,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: driverDialogInputDecoration(
                        labelText: 'Alasan edit',
                        hintText: 'Contoh: rute sistem kurang akurat',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _close,
                          child: const Text('Batal'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _submit,
                          child: const Text('Simpan'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _close() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop();
  }

  void _submit() {
    final amount = parseDriverCurrencyInput(_amountController.text);
    final reason = _reasonController.text.trim();
    if (amount <= 0 || reason.isEmpty) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(
      context,
    ).pop(_ManualDeliveryFeeInput(amount: amount, reason: reason));
  }
}

class _ManualDeliveryFeeInput {
  const _ManualDeliveryFeeInput({required this.amount, required this.reason});

  final double amount;
  final String reason;
}
