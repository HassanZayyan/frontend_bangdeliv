import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../models/driver_order_model.dart';
import '../../../../utils/order_formatters.dart';
import '../../../../utils/rupiah_input_formatter.dart';
import '../../../../utils/service_type.dart';
import 'driver_active_order_widget_helpers.dart';

typedef DriverShoppingCancellationInput = ({
  double baseDeliveryFee,
  String reason,
});

Future<DriverShoppingCancellationInput?> showDriverShoppingCancelWithFeeDialog(
  BuildContext context, {
  required DriverOrderModel order,
}) {
  final pricing = order.shoppingPricing;
  final automaticPenalty = pricing == null
      ? 0.0
      : pricing.cancellationPenalty > pricing.failedTripCompensation
      ? pricing.cancellationPenalty
      : pricing.failedTripCompensation;
  final initialBase = (pricing?.cancellationPenaltyBaseDeliveryFee ?? 0) > 0
      ? pricing!.cancellationPenaltyBaseDeliveryFee
      : (order.deliveryFee ?? 0) > 0
      ? order.deliveryFee!
      : automaticPenalty * 2;
  final percent = (pricing?.cancellationPenaltyPercent ?? 0) > 0
      ? pricing!.cancellationPenaltyPercent
      : 50.0;

  return showDialog<DriverShoppingCancellationInput>(
    context: context,
    builder: (_) => _ShoppingCancelWithFeeDialog(
      initialBaseDeliveryFee: initialBase,
      cancellationPercent: percent,
    ),
  );
}

class _ShoppingCancelWithFeeDialog extends StatefulWidget {
  const _ShoppingCancelWithFeeDialog({
    required this.initialBaseDeliveryFee,
    required this.cancellationPercent,
  });

  final double initialBaseDeliveryFee;
  final double cancellationPercent;

  @override
  State<_ShoppingCancelWithFeeDialog> createState() =>
      _ShoppingCancelWithFeeDialogState();
}

class _ShoppingCancelWithFeeDialogState
    extends State<_ShoppingCancelWithFeeDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _reasonController;
  String? _amountErrorText;
  String? _reasonErrorText;

  double get _baseDeliveryFee =>
      parseDriverCurrencyInput(_amountController.text);

  double get _cancellationFee =>
      (_baseDeliveryFee * widget.cancellationPercent / 100).roundToDouble();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialBaseDeliveryFee > 0
          ? formatRupiahInputAmount(widget.initialBaseDeliveryFee)
          : '',
    );
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Batalkan Order dengan Fee 50%'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Periksa ongkir penuh berdasarkan perjalanan aktual. Customer hanya akan ditagih 50% dari nominal ini.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: const [RupiahInputFormatter()],
                decoration: driverDialogInputDecoration(
                  labelText: 'Ongkir penuh',
                  prefixText: 'Rp ',
                  errorText: _amountErrorText,
                ),
                onChanged: (_) => setState(() => _amountErrorText = null),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Fee pembatalan (50%)',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      formatCurrency(_cancellationFee),
                      key: const ValueKey('shopping-cancellation-fee-preview'),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                minLines: 2,
                maxLines: 3,
                decoration: driverDialogInputDecoration(
                  labelText: 'Alasan koreksi',
                  hintText: 'Contoh: rute aktual lebih jauh dari estimasi',
                  errorText: _reasonErrorText,
                ),
                onChanged: (_) {
                  if (_reasonErrorText != null) {
                    setState(() => _reasonErrorText = null);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kembali'),
        ),
        FilledButton(
          key: const ValueKey('confirm-shopping-cancellation-fee'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: _submit,
          child: const Text('Batalkan & Tagih 50%'),
        ),
      ],
    );
  }

  void _submit() {
    final baseDeliveryFee = _baseDeliveryFee;
    final reason = _reasonController.text.trim();
    final amountError = baseDeliveryFee <= 0
        ? 'Ongkir penuh wajib lebih dari Rp 0.'
        : null;
    final reasonError = reason.isEmpty
        ? 'Alasan koreksi ongkir wajib diisi.'
        : null;
    if (amountError != null || reasonError != null) {
      setState(() {
        _amountErrorText = amountError;
        _reasonErrorText = reasonError;
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(
      context,
    ).pop((baseDeliveryFee: baseDeliveryFee, reason: reason));
  }
}

Future<void> showDriverManualDeliveryFeeEditDialog(
  BuildContext context, {
  required DriverOrderModel order,
  required Future<String?> Function({
    required double amount,
    required String reason,
  })
  onSave,
}) async {
  final isShopping =
      normalizeServiceTypeCode(order.serviceTypeCode) ==
      ServiceTypeCodes.shopping;
  final initialAmount = isShopping
      ? (order.deliveryFee ?? 0) +
            (order.shoppingPricing?.failedTripCompensation ?? 0)
      : order.deliveryFee;
  final result = await showDialog<_ManualDeliveryFeeInput>(
    context: context,
    builder: (context) => _ManualDeliveryFeeDialog(
      initialAmount: initialAmount,
      initialReason: '',
      isShoppingTotalTransport: isShopping,
    ),
  );

  if (result == null) {
    return;
  }

  final error = await onSave(amount: result.amount, reason: result.reason);

  if (!context.mounted) {
    return;
  }

  showDriverActiveOrderSnackBar(
    context,
    message:
        error ??
        (isShopping
            ? 'Total ongkir Nitip berhasil diajukan.'
            : 'Ongkir manual berhasil disimpan.'),
    isError: error != null,
  );
}

class _ManualDeliveryFeeDialog extends StatefulWidget {
  const _ManualDeliveryFeeDialog({
    required this.initialAmount,
    required this.initialReason,
    required this.isShoppingTotalTransport,
  });

  final double? initialAmount;
  final String initialReason;
  final bool isShoppingTotalTransport;

  @override
  State<_ManualDeliveryFeeDialog> createState() =>
      _ManualDeliveryFeeDialogState();
}

class _ManualDeliveryFeeDialogState extends State<_ManualDeliveryFeeDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _reasonController;
  String? _amountErrorText;
  String? _reasonErrorText;

  @override
  void initState() {
    super.initState();
    final initialAmount = widget.initialAmount ?? 0;
    _amountController = TextEditingController(
      text: formatRupiahInputAmount(initialAmount),
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
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isShoppingTotalTransport
                          ? 'Edit Total Ongkir Nitip'
                          : 'Edit Ongkir Manual',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [RupiahInputFormatter()],
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: driverDialogInputDecoration(
                        labelText: widget.isShoppingTotalTransport
                            ? 'Total ongkir Nitip'
                            : 'Ongkir dasar manual',
                        prefixText: 'Rp ',
                        errorText: _amountErrorText,
                      ),
                      onChanged: (_) {
                        if (_amountErrorText != null) {
                          setState(() => _amountErrorText = null);
                        }
                      },
                    ),
                    if (widget.isShoppingTotalTransport) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Nominal ini mencakup ongkir aktif dan kompensasi perjalanan gagal.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
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
                        errorText: _reasonErrorText,
                      ),
                      onChanged: (_) {
                        if (_reasonErrorText != null) {
                          setState(() => _reasonErrorText = null);
                        }
                      },
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

    final amountError = amount <= 0 ? 'Nominal ongkir wajib diisi.' : null;
    final reasonError = reason.isEmpty
        ? 'Alasan edit ongkir wajib diisi.'
        : null;
    if (amountError != null || reasonError != null) {
      setState(() {
        _amountErrorText = amountError;
        _reasonErrorText = reasonError;
      });
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
