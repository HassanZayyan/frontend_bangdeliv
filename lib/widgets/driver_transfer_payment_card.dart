import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../core/widgets/bang_action_button.dart';
import '../models/driver_order_model.dart';
import '../utils/currency_formatter.dart';
import '../utils/currency_input_parser.dart';
import '../utils/order_formatters.dart';
import '../utils/order_ui_helpers.dart';
import '../utils/rupiah_input_formatter.dart';

typedef DriverTransferPaymentCallback =
    Future<void> Function({required double amount});
typedef DriverTransferRejectCallback =
    Future<void> Function({required String reason});

class DriverTransferPaymentCard extends StatelessWidget {
  const DriverTransferPaymentCard({
    super.key,
    required this.order,
    required this.isOrderBusy,
    required this.isConfirmingQris,
    this.isRejectingQris = false,
    required this.onConfirmTransfer,
    this.onRejectTransfer,
  });

  final DriverOrderModel order;
  final bool isOrderBusy;
  final bool isConfirmingQris;
  final bool isRejectingQris;
  final DriverTransferPaymentCallback? onConfirmTransfer;
  final DriverTransferRejectCallback? onRejectTransfer;

  static bool shouldShow(DriverOrderModel order) {
    final method = order.paymentMethod.trim().toUpperCase();
    return method == 'TRANSFER' ||
        _hasTransferProof(order) ||
        order.paymentProofFeedback?.isRejected == true;
  }

  @override
  Widget build(BuildContext context) {
    final proof = _transferProof(order);
    final isPaid = isPaymentPaid(order.paymentStatus);
    final hasProof = proof != null && (proof.photoUrl ?? '').trim().isNotEmpty;
    final hasPendingProof =
        hasProof && (proof.status ?? '').trim().toLowerCase() == 'pending';
    final isRejectedWithoutNewProof =
        !isPaid &&
        order.paymentProofFeedback?.isRejected == true &&
        !hasPendingProof;

    if (!shouldShow(order)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bukti QRIS Customer',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _statusMessage(
                  isPaid: isPaid,
                  hasProof: hasProof,
                  isRejectedWithoutNewProof: isRejectedWithoutNewProof,
                ),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
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
                paymentMethodLabel(order.paymentMethod),
                foreground: AppColors.primaryDark,
                background: AppColors.primary.withValues(alpha: 0.08),
                borderColor: AppColors.primary.withValues(alpha: 0.16),
              ),
              _chip(
                isRejectedWithoutNewProof
                    ? 'Ditolak'
                    : paymentStatusLabel(order.paymentStatus),
                foreground: _statusColor(
                  isRejectedWithoutNewProof: isRejectedWithoutNewProof,
                ),
                background: _statusColor(
                  isRejectedWithoutNewProof: isRejectedWithoutNewProof,
                ).withValues(alpha: 0.08),
                borderColor: _statusColor(
                  isRejectedWithoutNewProof: isRejectedWithoutNewProof,
                ).withValues(alpha: 0.14),
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
          if (isRejectedWithoutNewProof)
            _RejectedProofState(
              reason: order.paymentProofFeedback?.displayReason,
            )
          else if (hasProof)
            _proofPreview(context, proof)
          else
            const _WaitingProofState(),
          if (!isPaid && !isRejectedWithoutNewProof) ...[
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
        child: BangActionButton(
          label: 'Verifikasi QRIS',
          isLoading: isConfirmingQris || isRejectingQris,
          isEnabled: !isOrderBusy || isConfirmingQris || isRejectingQris,
          onPressed: onConfirmTransfer == null
              ? null
              : () => _openReviewDialog(context),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: BangActionButton(
        label: 'Catat Pembayaran QRIS Manual',
        variant: BangActionButtonVariant.outlined,
        isLoading: isConfirmingQris,
        isEnabled: !isOrderBusy || isConfirmingQris,
        onPressed: onConfirmTransfer == null
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

                await onConfirmTransfer?.call(amount: input.amount);
              },
      ),
    );
  }

  Future<void> _openReviewDialog(BuildContext context) async {
    final proof = _transferProof(order);
    if (proof == null) {
      return;
    }

    final decision = await showDialog<_TransferProofReviewDecision>(
      context: context,
      builder: (context) => _TransferProofReviewDialog(
        proof: proof,
        amount: order.totalPrice,
        canReject: onRejectTransfer != null,
      ),
    );
    if (decision == null) {
      return;
    }

    if (decision.isApproved) {
      await onConfirmTransfer?.call(amount: order.totalPrice);
      return;
    }

    final reason = decision.rejectionReason?.trim() ?? '';
    if (reason.isEmpty) {
      return;
    }
    await onRejectTransfer?.call(reason: reason);
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
        borderRadius: BorderRadius.circular(10),
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

  Color _statusColor({required bool isRejectedWithoutNewProof}) {
    if (isPaymentPaid(order.paymentStatus)) {
      return AppColors.success;
    }

    return isRejectedWithoutNewProof ? AppColors.error : AppColors.primaryDark;
  }

  String _statusMessage({
    required bool isPaid,
    required bool hasProof,
    required bool isRejectedWithoutNewProof,
  }) {
    if (isPaid) {
      return 'Pembayaran QRIS sudah diverifikasi.';
    }

    if (isRejectedWithoutNewProof) {
      return 'Bukti QRIS ditolak. Menunggu customer mengirim bukti baru.';
    }

    if (hasProof) {
      return 'Cek bukti dari customer sebelum verifikasi pembayaran.';
    }

    return 'Bukti QRIS belum diunggah.';
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
          borderRadius: BorderRadius.circular(10),
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

class _TransferProofReviewDecision {
  const _TransferProofReviewDecision.approve()
    : isApproved = true,
      rejectionReason = null;

  const _TransferProofReviewDecision.reject(this.rejectionReason)
    : isApproved = false;

  final bool isApproved;
  final String? rejectionReason;
}

class _TransferProofReviewDialog extends StatefulWidget {
  const _TransferProofReviewDialog({
    required this.proof,
    required this.amount,
    required this.canReject,
  });

  final DriverOrderProofModel proof;
  final double amount;
  final bool canReject;

  @override
  State<_TransferProofReviewDialog> createState() =>
      _TransferProofReviewDialogState();
}

class _TransferProofReviewDialogState
    extends State<_TransferProofReviewDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isRejecting = false;
  String? _reasonError;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verifikasi Bukti QRIS',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pastikan nominal dan bukti pembayaran sudah sesuai.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              _reviewSummary(context),
              if (_isRejecting) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _reasonController,
                  maxLength: 1000,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: _transferDialogInputDecoration(
                    labelText: 'Alasan penolakan',
                  ).copyWith(errorText: _reasonError, alignLabelWithHint: true),
                  onChanged: (_) {
                    if (_reasonError != null) {
                      setState(() => _reasonError = null);
                    }
                  },
                ),
              ],
              const SizedBox(height: 16),
              _actions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewSummary(BuildContext context) {
    final url = widget.proof.photoUrl;
    final note = widget.proof.note?.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (url != null && url.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                width: 58,
                height: 58,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 58,
                  height: 58,
                  color: AppColors.background,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          if (url != null && url.isNotEmpty) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryLine('Nominal', formatRupiah(widget.amount)),
                const SizedBox(height: 4),
                _summaryLine(
                  'Upload',
                  formatDateMonthTime(widget.proof.createdAt),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value) {
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

  Widget _actions(BuildContext context) {
    if (_isRejecting) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() {
                _isRejecting = false;
                _reasonError = null;
              }),
              child: const Text('Kembali'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: _submitReject,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Tolak Bukti'),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        if (widget.canReject) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _isRejecting = true),
              child: const Text('Tolak'),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(const _TransferProofReviewDecision.approve()),
            child: const Text('Setujui'),
          ),
        ),
      ],
    );
  }

  void _submitReject() {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _reasonError = 'Alasan penolakan wajib diisi.');
      return;
    }

    Navigator.of(context).pop(_TransferProofReviewDecision.reject(reason));
  }
}

class _WaitingProofState extends StatelessWidget {
  const _WaitingProofState();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Menunggu bukti QRIS dari customer.',
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
    );
  }
}

class _RejectedProofState extends StatelessWidget {
  const _RejectedProofState({required this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final cleanReason = reason?.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Menunggu customer mengirim bukti baru.',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          if (cleanReason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              cleanReason,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

InputDecoration _transferDialogInputDecoration({
  String? labelText,
  String? prefixText,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AppColors.border),
  );

  return InputDecoration(
    labelText: labelText,
    prefixText: prefixText,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    labelStyle: const TextStyle(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    ),
    prefixStyle: const TextStyle(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    ),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
    ),
  );
}

class _TransferPaymentInput {
  const _TransferPaymentInput({required this.amount});

  final double amount;
}

class _TransferPaymentDialog extends StatefulWidget {
  const _TransferPaymentDialog({required this.initialAmount});

  final double initialAmount;

  @override
  State<_TransferPaymentDialog> createState() => _TransferPaymentDialogState();
}

class _TransferPaymentDialogState extends State<_TransferPaymentDialog> {
  late final TextEditingController _amountController;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmount > 0
          ? formatRupiahInputAmount(widget.initialAmount)
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Catat Pembayaran QRIS',
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
                inputFormatters: const [RupiahInputFormatter()],
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                decoration: _transferDialogInputDecoration(
                  labelText: 'Nominal QRIS',
                  prefixText: 'Rp ',
                ).copyWith(errorText: _amountError),
                onChanged: (_) {
                  if (_amountError != null) {
                    setState(() => _amountError = null);
                  }
                },
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
                  FilledButton(onPressed: _submit, child: const Text('Catat')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final amount = parseCurrencyInput(_amountController.text);
    if (amount <= 0) {
      setState(() => _amountError = 'Nominal QRIS wajib diisi.');
      return;
    }

    Navigator.of(context).pop(_TransferPaymentInput(amount: amount));
  }
}
