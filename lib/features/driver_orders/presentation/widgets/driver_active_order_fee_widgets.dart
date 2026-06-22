import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../models/driver_order_model.dart';
import 'driver_active_order_widget_helpers.dart';

Future<void> showDriverManualDeliveryFeeEditDialog(
  BuildContext context, {
  required DriverOrderModel order,
  required Future<String?> Function({
    required double amount,
    required String reason,
  })
  onSave,
}) async {
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
      content: Text(error ?? 'Ongkir manual berhasil disimpan.'),
      backgroundColor: error == null ? null : AppColors.error,
    ),
  );
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
  String? _amountErrorText;
  String? _reasonErrorText;

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
                        errorText: _amountErrorText,
                      ),
                      onChanged: (_) {
                        if (_amountErrorText != null) {
                          setState(() => _amountErrorText = null);
                        }
                      },
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
