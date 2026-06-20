import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_colors.dart';
import '../models/driver_order_model.dart';
import '../utils/currency_formatter.dart';
import '../utils/order_formatters.dart';
import '../utils/order_ui_helpers.dart';

typedef DriverTransferPaymentCallback =
    Future<void> Function({required double amount, required String? note});

class DriverTransferPaymentCard extends StatelessWidget {
  const DriverTransferPaymentCard({
    super.key,
    required this.order,
    required this.isProcessing,
    required this.onConfirmTransfer,
  });

  final DriverOrderModel order;
  final bool isProcessing;
  final DriverTransferPaymentCallback? onConfirmTransfer;

  static bool shouldShow(DriverOrderModel order) {
    final method = order.paymentMethod.trim().toUpperCase();
    return method == 'TRANSFER' || _hasTransferProof(order);
  }

  @override
  Widget build(BuildContext context) {
    final proof = _transferProof(order);
    final isPaid = isPaymentPaid(order.paymentStatus);
    final hasProof = proof != null && (proof.photoUrl ?? '').trim().isNotEmpty;

    if (!shouldShow(order)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bukti Transfer Customer',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _statusMessage(isPaid: isPaid, hasProof: hasProof),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                order.paymentMethod.trim().isEmpty
                    ? 'TRANSFER'
                    : order.paymentMethod.toUpperCase(),
                foreground: AppColors.textPrimary,
                background: AppColors.surfaceAlt,
                borderColor: AppColors.border,
              ),
              _chip(
                paymentStatusLabel(order.paymentStatus),
                foreground: _statusColor(),
                background: AppColors.surfaceAlt,
                borderColor: AppColors.border,
              ),
              _chip(
                formatRupiah(order.totalPrice),
                foreground: AppColors.textPrimary,
                background: AppColors.surfaceAlt,
                borderColor: AppColors.border,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasProof)
            _proofPreview(context, proof)
          else
            const _WaitingProofState(),
          if (!isPaid) ...[
            const SizedBox(height: 14),
            _actions(context, hasProof: hasProof),
          ],
        ],
      ),
    );
  }

  Widget _proofPreview(BuildContext context, DriverOrderProofModel proof) {
    final url = proof.photoUrl!;
    final note = proof.note?.trim() ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _showProofPreview(context, proof),
          borderRadius: BorderRadius.circular(10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url,
              width: 84,
              height: 84,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 84,
                height: 84,
                color: AppColors.background,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _metaLine('Status bukti', _proofStatusLabel(proof.status)),
              const SizedBox(height: 5),
              _metaLine('Upload', formatDateMonthTime(proof.createdAt)),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _showProofPreview(context, proof),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('Lihat Bukti'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actions(BuildContext context, {required bool hasProof}) {
    if (hasProof) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: isProcessing || onConfirmTransfer == null
              ? null
              : () => onConfirmTransfer?.call(
                  amount: order.totalPrice,
                  note: 'Verifikasi bukti transfer customer dari app driver.',
                ),
          child: const Text('Verifikasi Transfer'),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isProcessing || onConfirmTransfer == null
            ? null
            : () async {
                final input = await showDialog<_TransferPaymentInput>(
                  context: context,
                  builder: (context) =>
                      _TransferPaymentDialog(initialAmount: order.totalPrice),
                );
                if (input == null) {
                  return;
                }

                await onConfirmTransfer?.call(
                  amount: input.amount,
                  note: input.note,
                );
              },
        child: const Text('Catat Transfer Manual'),
      ),
    );
  }

  Widget _chip(
    String text, {
    required Color foreground,
    required Color background,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _metaLine(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor() {
    return isPaymentPaid(order.paymentStatus)
        ? AppColors.success
        : AppColors.primaryDark;
  }

  String _statusMessage({required bool isPaid, required bool hasProof}) {
    if (isPaid) {
      return 'Pembayaran transfer sudah diverifikasi.';
    }

    if (hasProof) {
      return 'Cek bukti dari customer sebelum verifikasi pembayaran.';
    }

    return 'Bukti transfer belum diunggah.';
  }

  String _proofStatusLabel(String? status) {
    final normalized = (status ?? '').trim().toLowerCase();
    return switch (normalized) {
      'approved' || 'verified' || 'paid' => 'Terverifikasi',
      'rejected' || 'failed' => 'Ditolak',
      'pending' || '' => 'Menunggu verifikasi',
      _ => normalized.toUpperCase(),
    };
  }

  void _showProofPreview(BuildContext context, DriverOrderProofModel proof) {
    final url = proof.photoUrl;
    if (url == null || url.isEmpty) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Gambar bukti belum bisa dimuat.'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static DriverOrderProofModel? _transferProof(DriverOrderModel order) {
    final proofs = order.proofs
        .where(
          (proof) =>
              proof.type == 'payment_transfer' &&
              (proof.photoUrl ?? '').trim().isNotEmpty,
        )
        .toList(growable: false);
    if (proofs.isEmpty) {
      return null;
    }

    proofs.sort((a, b) {
      final aCreated = a.createdAt;
      final bCreated = b.createdAt;
      if (aCreated == null && bCreated == null) {
        return 0;
      }
      if (aCreated == null) {
        return 1;
      }
      if (bCreated == null) {
        return -1;
      }

      return bCreated.compareTo(aCreated);
    });
    return proofs.first;
  }

  static bool _hasTransferProof(DriverOrderModel order) {
    return order.proofs.any((proof) => proof.type == 'payment_transfer');
  }
}

class _WaitingProofState extends StatelessWidget {
  const _WaitingProofState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'Menunggu bukti transfer dari customer.',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
}

InputDecoration _transferDialogInputDecoration({
  String? labelText,
  String? prefixText,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.border),
  );

  return InputDecoration(
    labelText: labelText,
    prefixText: prefixText,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    labelStyle: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );
}

class _TransferPaymentInput {
  const _TransferPaymentInput({required this.amount, required this.note});

  final double amount;
  final String? note;
}

class _TransferPaymentDialog extends StatefulWidget {
  const _TransferPaymentDialog({required this.initialAmount});

  final double initialAmount;

  @override
  State<_TransferPaymentDialog> createState() => _TransferPaymentDialogState();
}

class _TransferPaymentDialogState extends State<_TransferPaymentDialog> {
  late final TextEditingController _amountController;
  final TextEditingController _noteController = TextEditingController(
    text: 'Pembayaran transfer dicatat dari app driver.',
  );
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmount > 0
          ? widget.initialAmount.round().toString()
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
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
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Catat Pembayaran Transfer',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: _transferDialogInputDecoration(
                          labelText: 'Nominal transfer',
                          prefixText: 'Rp ',
                        ).copyWith(errorText: _amountError),
                        onChanged: (_) {
                          if (_amountError != null) {
                            setState(() => _amountError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _noteController,
                        minLines: 2,
                        maxLines: 3,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: _transferDialogInputDecoration(
                          labelText: 'Catatan',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Batal'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _submit,
                            child: const Text('Catat'),
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
      ),
    );
  }

  void _submit() {
    final amount = _parseCurrencyInput(_amountController.text);
    if (amount <= 0) {
      setState(() => _amountError = 'Nominal transfer wajib diisi.');
      return;
    }

    Navigator.of(context).pop(
      _TransferPaymentInput(amount: amount, note: _noteController.text.trim()),
    );
  }
}

double _parseCurrencyInput(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleaned.isEmpty) {
    return 0;
  }

  return double.tryParse(cleaned) ?? 0;
}
