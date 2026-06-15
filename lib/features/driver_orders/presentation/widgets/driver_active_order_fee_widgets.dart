import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../models/driver_order_model.dart';
import '../../../../utils/currency_formatter.dart';
import '../../../../utils/service_type.dart';
import 'driver_active_order_widget_helpers.dart';

class DriverManualDeliveryFeeCard extends StatelessWidget {
  const DriverManualDeliveryFeeCard({
    super.key,
    required this.order,
    required this.isOrderBusy,
    required this.onSave,
  });

  final DriverOrderModel order;
  final bool isOrderBusy;
  final Future<String?> Function({
    required double amount,
    required String reason,
    required bool carefulCarryRequired,
  })
  onSave;

  @override
  Widget build(BuildContext context) {
    final supportsCarefulCarry = serviceTypeSupportsCarefulCarry(
      order.serviceTypeCode,
    );
    final deliveryFeeSource = (order.deliveryFeeSource ?? '')
        .trim()
        .toLowerCase();
    final deliveryFeeSourceLabel = deliveryFeeSource == 'driver_manual'
        ? 'manual driver'
        : deliveryFeeSource;

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
                  'Ongkir Driver',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: isOrderBusy ? null : () => _openDialog(context),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit'),
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
              if (supportsCarefulCarry && order.carefulCarryRequired)
                _summaryChip('Perlu 2 orang', 'aktif'),
            ],
          ),
        ],
      ),
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
    final supportsCarefulCarry = serviceTypeSupportsCarefulCarry(
      order.serviceTypeCode,
    );

    final result = await showDialog<_ManualDeliveryFeeInput>(
      context: context,
      builder: (context) => _ManualDeliveryFeeDialog(
        initialAmount: order.deliveryFee,
        initialReason: '',
        initialCarefulCarryRequired:
            supportsCarefulCarry && order.carefulCarryRequired,
        supportsCarefulCarry: supportsCarefulCarry,
        systemDeliveryFee: order.deliveryFee,
      ),
    );

    if (result == null) {
      return;
    }

    final error = await onSave(
      amount: result.amount,
      reason: result.reason,
      carefulCarryRequired: result.carefulCarryRequired,
    );

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
}

class _ManualDeliveryFeeDialog extends StatefulWidget {
  const _ManualDeliveryFeeDialog({
    required this.initialAmount,
    required this.initialReason,
    required this.initialCarefulCarryRequired,
    required this.supportsCarefulCarry,
    required this.systemDeliveryFee,
  });

  final double? initialAmount;
  final String initialReason;
  final bool initialCarefulCarryRequired;
  final bool supportsCarefulCarry;
  final double? systemDeliveryFee;

  @override
  State<_ManualDeliveryFeeDialog> createState() =>
      _ManualDeliveryFeeDialogState();
}

class _ManualDeliveryFeeDialogState extends State<_ManualDeliveryFeeDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _reasonController;
  late bool _carefulCarryRequired;
  bool _amountTouchedByUser = false;

  @override
  void initState() {
    super.initState();
    final initialAmount = widget.initialAmount ?? 0;
    _amountController = TextEditingController(
      text: initialAmount > 0 ? initialAmount.round().toString() : '',
    );
    _reasonController = TextEditingController(text: widget.initialReason);
    _carefulCarryRequired =
        widget.supportsCarefulCarry && widget.initialCarefulCarryRequired;
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
                      onChanged: (_) => _amountTouchedByUser = true,
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
                    if (widget.supportsCarefulCarry) ...[
                      const SizedBox(height: 6),
                      CheckboxListTile(
                        value: _carefulCarryRequired,
                        onChanged: _handleCarefulCarryChanged,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Perlu 2 orang / hati-hati'),
                      ),
                    ],
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

  void _handleCarefulCarryChanged(bool? value) {
    setState(() {
      _carefulCarryRequired = value ?? false;
      final systemDeliveryFee = widget.systemDeliveryFee;
      if (_carefulCarryRequired &&
          !_amountTouchedByUser &&
          systemDeliveryFee != null &&
          systemDeliveryFee > 0) {
        _amountController.text = systemDeliveryFee.round().toString();
      }

      if (_carefulCarryRequired && _reasonController.text.trim().isEmpty) {
        _reasonController.text = 'Perlu 2 orang / barang harus hati-hati';
      }
    });
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
    Navigator.of(context).pop(
      _ManualDeliveryFeeInput(
        amount: amount,
        reason: reason,
        carefulCarryRequired:
            widget.supportsCarefulCarry && _carefulCarryRequired,
      ),
    );
  }
}

class _ManualDeliveryFeeInput {
  const _ManualDeliveryFeeInput({
    required this.amount,
    required this.reason,
    required this.carefulCarryRequired,
  });

  final double amount;
  final String reason;
  final bool carefulCarryRequired;
}
