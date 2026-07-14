import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/app_colors.dart';
import '../../../../core/widgets/bang_swipe_action_button.dart';
import '../../../../models/driver_order_model.dart';
import '../../../../utils/currency_formatter.dart';
import '../../../../utils/order_formatters.dart' show formatTime;
import '../../../../utils/order_status.dart';
import '../../../../utils/order_ui_helpers.dart';
import '../../../../utils/service_type.dart';
import '../../../navigation/presentation/widgets/bang_floating_bottom_nav_bar.dart';

class DriverOrderTimelineCard extends StatelessWidget {
  final List<DriverOrderTimelineItemModel> timeline;

  const DriverOrderTimelineCard({super.key, required this.timeline});

  @override
  Widget build(BuildContext context) {
    final statusTimeline = timeline
        .where((item) => item.eventType.toUpperCase() == 'STATUS_CHANGE')
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Riwayat Status',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (statusTimeline.isEmpty)
            const Text(
              'Belum ada histori status.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            ...List.generate(statusTimeline.length, (index) {
              final item = statusTimeline[index];
              final isLast = index == statusTimeline.length - 1;
              final statusText = item.statusDisplayName ?? item.statusCode;
              final timeText = item.createdAt == null
                  ? 'Waktu belum tersedia'
                  : formatTime(item.createdAt);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    child: Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: isLast
                                ? AppColors.primary
                                : AppColors.textSecondary.withValues(
                                    alpha: 0.2,
                                  ),
                            border: isLast
                                ? Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.18,
                                    ),
                                    width: 3,
                                  )
                                : null,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 34,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusText,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: isLast
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeText,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class DriverOrderActionCard extends StatelessWidget {
  final DriverOrderModel order;
  final bool isProcessing;
  final Future<void> Function(DriverOrderActionModel action) onTapAction;

  const DriverOrderActionCard({
    super.key,
    required this.order,
    required this.isProcessing,
    required this.onTapAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aksi Driver',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _DriverOrderActionControls(
            order: order,
            isProcessing: isProcessing,
            onTapAction: onTapAction,
            showEmptyState: true,
          ),
        ],
      ),
    );
  }
}

class DriverOrderStickyActionBar extends StatelessWidget {
  final DriverOrderModel order;
  final bool isProcessing;
  final bool isSavingShoppingCheckout;
  final bool isResolvingTransferPayment;
  final bool isResolvingProof;
  final bool isUpdatingDeliveryFee;
  final bool isAcceptingDeliveryFeeCounter;
  final bool isBypassingDeliveryFee;
  final Future<void> Function()? onSaveShoppingCheckout;
  final Future<void> Function()? onResolveTransferPayment;
  final Future<void> Function(String proofType)? onResolveProof;
  final Future<void> Function()? onEditDeliveryFee;
  final Future<void> Function()? onAcceptDeliveryFeeCounter;
  final Future<void> Function()? onBypassDeliveryFee;
  final Future<void> Function(DriverOrderActionModel action) onTapAction;
  final bool compactForSheet;
  final bool singlePrimaryAction;

  const DriverOrderStickyActionBar({
    super.key,
    required this.order,
    required this.isProcessing,
    this.isSavingShoppingCheckout = false,
    this.isResolvingTransferPayment = false,
    this.isResolvingProof = false,
    this.isUpdatingDeliveryFee = false,
    this.isAcceptingDeliveryFeeCounter = false,
    this.isBypassingDeliveryFee = false,
    this.onSaveShoppingCheckout,
    this.onResolveTransferPayment,
    this.onResolveProof,
    this.onEditDeliveryFee,
    this.onAcceptDeliveryFeeCounter,
    this.onBypassDeliveryFee,
    required this.onTapAction,
    this.compactForSheet = false,
    this.singlePrimaryAction = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!_hasVisibleContent()) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            compactForSheet ? 8 : BangFloatingBottomNavBar.scrollClearance - 42,
          ),
          child: _DriverOrderActionControls(
            order: order,
            isProcessing: isProcessing,
            isSavingShoppingCheckout: isSavingShoppingCheckout,
            isResolvingTransferPayment: isResolvingTransferPayment,
            isResolvingProof: isResolvingProof,
            isUpdatingDeliveryFee: isUpdatingDeliveryFee,
            isAcceptingDeliveryFeeCounter: isAcceptingDeliveryFeeCounter,
            isBypassingDeliveryFee: isBypassingDeliveryFee,
            onSaveShoppingCheckout: onSaveShoppingCheckout,
            onResolveTransferPayment: onResolveTransferPayment,
            onResolveProof: onResolveProof,
            onEditDeliveryFee: onEditDeliveryFee,
            onAcceptDeliveryFeeCounter: onAcceptDeliveryFeeCounter,
            onBypassDeliveryFee: onBypassDeliveryFee,
            onTapAction: onTapAction,
            showEmptyState: false,
            singlePrimaryAction: singlePrimaryAction,
            compact: compactForSheet,
          ),
        ),
      ),
    );
  }

  bool _hasVisibleContent() {
    return hasDriverOrderStickyActionBarContent(order);
  }
}

bool hasDriverOrderStickyActionBarContent(DriverOrderModel order) {
  if (order.availableActions.isNotEmpty) {
    return true;
  }

  return _shouldShowShoppingCheckoutAction(order) ||
      _shouldShowShoppingClosureFeeHint(order) ||
      _shouldShowDeliveryFeeShortcut(order);
}

Future<bool> showDriverDeliveryFeeBypassConfirmation(
  BuildContext context, {
  required DriverOrderModel order,
}) async {
  final negotiation = order.deliveryFeeNegotiation;
  final proposedAmount = negotiation?.quotedAmount ?? 0;
  if (negotiation == null || proposedAmount <= 0) {
    return false;
  }

  final isShoppingTotalTransport = negotiation.isShoppingTotalTransport;
  final previousAmount = isShoppingTotalTransport
      ? negotiation.previousTotalTransport
      : negotiation.oldDeliveryFee ?? order.deliveryFee;
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lanjut tanpa persetujuan?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Customer belum merespons revisi ongkir. Periksa nominal sebelum melanjutkan checkout.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  if (previousAmount != null && previousAmount > 0) ...[
                    _BypassAmountRow(
                      label: isShoppingTotalTransport
                          ? 'Total transport sebelumnya'
                          : 'Ongkir sebelumnya',
                      amount: previousAmount,
                    ),
                    const SizedBox(height: 10),
                  ],
                  _BypassAmountRow(
                    label: isShoppingTotalTransport
                        ? 'Total usulan driver'
                        : 'Ongkir usulan driver',
                    amount: proposedAmount,
                    emphasized: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.45),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warningDark,
                    size: 20,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Nominal usulan akan menjadi ongkir aktif dan customer akan diberi tahu.',
                      style: TextStyle(
                        color: AppColors.warningDark,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            BangSwipeActionButton(
              label: 'Geser untuk lanjut',
              loadingLabel: 'Memproses...',
              onSubmit: () async {
                Navigator.of(sheetContext).pop(true);
              },
            ),
          ],
        ),
      );
    },
  );

  return confirmed ?? false;
}

class _BypassAmountRow extends StatelessWidget {
  const _BypassAmountRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final double amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          formatRupiah(amount),
          style: TextStyle(
            color: emphasized ? AppColors.primaryDark : AppColors.textPrimary,
            fontSize: emphasized ? 15 : 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DriverOrderActionControls extends StatelessWidget {
  final DriverOrderModel order;
  final bool isProcessing;
  final bool isSavingShoppingCheckout;
  final bool isResolvingTransferPayment;
  final bool isResolvingProof;
  final bool isUpdatingDeliveryFee;
  final bool isAcceptingDeliveryFeeCounter;
  final bool isBypassingDeliveryFee;
  final Future<void> Function()? onSaveShoppingCheckout;
  final Future<void> Function()? onResolveTransferPayment;
  final Future<void> Function(String proofType)? onResolveProof;
  final Future<void> Function()? onEditDeliveryFee;
  final Future<void> Function()? onAcceptDeliveryFeeCounter;
  final Future<void> Function()? onBypassDeliveryFee;
  final Future<void> Function(DriverOrderActionModel action) onTapAction;
  final bool showEmptyState;
  final bool singlePrimaryAction;
  final bool compact;

  const _DriverOrderActionControls({
    required this.order,
    required this.isProcessing,
    this.isSavingShoppingCheckout = false,
    this.isResolvingTransferPayment = false,
    this.isResolvingProof = false,
    this.isUpdatingDeliveryFee = false,
    this.isAcceptingDeliveryFeeCounter = false,
    this.isBypassingDeliveryFee = false,
    this.onSaveShoppingCheckout,
    this.onResolveTransferPayment,
    this.onResolveProof,
    this.onEditDeliveryFee,
    this.onAcceptDeliveryFeeCounter,
    this.onBypassDeliveryFee,
    required this.onTapAction,
    required this.showEmptyState,
    this.singlePrimaryAction = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isShoppingOrder = _isShoppingOrder(order);
    final showSaveShoppingCheckout =
        _shouldShowShoppingCheckoutAction(order) &&
        onSaveShoppingCheckout != null;
    final availableActions = showSaveShoppingCheckout
        ? order.availableActions
              .where((action) => action.actionCode != 'CONFIRM_PICKED_UP')
              .toList(growable: false)
        : order.availableActions;
    final actions = singlePrimaryAction
        ? _singlePrimaryActions(order, availableActions)
        : availableActions;
    final transferResolution = _transferPaymentResolutionFor(order, actions);
    final proofResolution = _proofResolutionFor(order, actions);
    final deliveryFeeResolution = _deliveryFeeResolutionFor(
      order,
      actions,
      canEdit: onEditDeliveryFee != null,
      canAcceptCounter: onAcceptDeliveryFeeCounter != null,
      canBypass: onBypassDeliveryFee != null,
    );
    final visibleProofResolution = proofResolution;
    final visibleTransferResolution = compact && visibleProofResolution != null
        ? null
        : transferResolution;
    final visibleDeliveryFeeResolution =
        compact &&
            (visibleProofResolution != null ||
                visibleTransferResolution != null)
        ? null
        : deliveryFeeResolution;
    final renderedActions = actions
        .where((action) {
          if (transferResolution != null &&
              _isTransferPaymentBlockedAction(action)) {
            return false;
          }
          if (proofResolution != null && _isProofBlockedAction(action)) {
            return false;
          }
          if (deliveryFeeResolution?.blocksProgress == true &&
              _isDeliveryFeeBlockedAction(action)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    final hasCodCollection = actions.any((action) => action.isCodCollection);
    final isCancelledWithFee =
        normalizeOrderStatusCode(order.statusCode) ==
        OrderStatusCodes.cancelledWithFee;
    final isWaitingCancellationFeePayment =
        isCancelledWithFee && !isPaymentPaid(order.paymentStatus);
    final isCourier =
        normalizeServiceTypeCode(order.serviceTypeCode) ==
        ServiceTypeCodes.courier;
    final codMessage = isCourier
        ? 'Cek barang lebih dulu, lalu tagih ${formatRupiah(order.totalPrice)} saat pickup sebelum menekan Paket Diambil.'
        : 'Tagih COD sebesar ${formatRupiah(order.totalPrice)} sebelum menyelesaikan order.';
    final pricing = order.shoppingPricing;
    final showShoppingClosureFeeHint = _shouldShowShoppingClosureFeeHint(order);
    final useCompactDeliveryFeeActionRow =
        compact &&
        visibleDeliveryFeeResolution != null &&
        !visibleDeliveryFeeResolution.blocksProgress &&
        visibleTransferResolution == null &&
        visibleProofResolution == null &&
        !showSaveShoppingCheckout &&
        renderedActions.length == 1;
    final useCompactShoppingCheckoutActionRow =
        compact &&
        isShoppingOrder &&
        showSaveShoppingCheckout &&
        visibleDeliveryFeeResolution != null &&
        !visibleDeliveryFeeResolution.blocksProgress &&
        visibleTransferResolution == null &&
        visibleProofResolution == null &&
        renderedActions.isEmpty;
    final deliveryFeeBlocksShoppingCheckout =
        isShoppingOrder &&
        showSaveShoppingCheckout &&
        deliveryFeeResolution?.blocksProgress == true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact && showShoppingClosureFeeHint && pricing != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _shoppingClosureFeeHint(pricing),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
        if (!compact && hasCodCollection) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              codMessage,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (showSaveShoppingCheckout &&
            !deliveryFeeBlocksShoppingCheckout &&
            !useCompactShoppingCheckoutActionRow) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                onPressed: isProcessing ? null : onSaveShoppingCheckout,
                icon: isSavingShoppingCheckout
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.receipt_long_outlined),
                label: const Text('Simpan Checkout Nitip'),
              ),
            ),
          ),
        ],
        if (visibleTransferResolution != null) ...[
          _TransferPaymentResolutionPrompt(
            resolution: visibleTransferResolution,
            compact: compact,
            isLoading: isResolvingTransferPayment,
            onPressed: onResolveTransferPayment,
          ),
          if (visibleProofResolution == null && renderedActions.isNotEmpty)
            const SizedBox(height: 8),
        ],
        if (visibleProofResolution != null) ...[
          if (visibleTransferResolution != null) const SizedBox(height: 8),
          _ProofResolutionPrompt(
            resolution: visibleProofResolution,
            compact: compact,
            isLoading: isResolvingProof,
            onPressed: onResolveProof == null
                ? null
                : () => onResolveProof!(visibleProofResolution.proofType),
          ),
          if (renderedActions.isNotEmpty) const SizedBox(height: 8),
        ],
        if (visibleDeliveryFeeResolution != null &&
            !useCompactDeliveryFeeActionRow &&
            !useCompactShoppingCheckoutActionRow) ...[
          if (visibleTransferResolution != null ||
              visibleProofResolution != null)
            const SizedBox(height: 8),
          _DeliveryFeeResolutionPrompt(
            resolution: visibleDeliveryFeeResolution,
            compact: compact,
            isLoading: _isDeliveryFeeResolutionLoading(
              visibleDeliveryFeeResolution,
              isUpdatingDeliveryFee: isUpdatingDeliveryFee,
              isAcceptingCounter: isAcceptingDeliveryFeeCounter,
              isBypassing: isBypassingDeliveryFee,
            ),
            onPressed: _deliveryFeeResolutionCallback(
              visibleDeliveryFeeResolution,
              onEdit: onEditDeliveryFee,
              onAcceptCounter: onAcceptDeliveryFeeCounter,
              onBypass: onBypassDeliveryFee,
            ),
          ),
          if (renderedActions.isNotEmpty) const SizedBox(height: 8),
        ],
        if (useCompactShoppingCheckoutActionRow)
          _CompactShoppingCheckoutActionRow(
            deliveryFeeResolution: visibleDeliveryFeeResolution,
            isDeliveryFeeLoading: _isDeliveryFeeResolutionLoading(
              visibleDeliveryFeeResolution,
              isUpdatingDeliveryFee: isUpdatingDeliveryFee,
              isAcceptingCounter: isAcceptingDeliveryFeeCounter,
              isBypassing: isBypassingDeliveryFee,
            ),
            onDeliveryFeePressed: _deliveryFeeResolutionCallback(
              visibleDeliveryFeeResolution,
              onEdit: onEditDeliveryFee,
              onAcceptCounter: onAcceptDeliveryFeeCounter,
              onBypass: onBypassDeliveryFee,
            ),
            isProcessing: isProcessing,
            isSavingCheckout: isSavingShoppingCheckout,
            onSaveCheckout: onSaveShoppingCheckout,
          )
        else if (renderedActions.isEmpty)
          if (showEmptyState &&
              !showSaveShoppingCheckout &&
              visibleTransferResolution == null &&
              visibleProofResolution == null &&
              visibleDeliveryFeeResolution == null)
            Text(
              isWaitingCancellationFeePayment
                  ? 'Menunggu pembayaran biaya pembatalan dari customer. Verifikasi transfer dulu, lalu selesaikan order.'
                  : 'Tidak ada aksi yang tersedia pada status ini.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            )
          else
            const SizedBox.shrink()
        else if (useCompactDeliveryFeeActionRow)
          _CompactDeliveryFeeActionRow(
            deliveryFeeResolution: visibleDeliveryFeeResolution,
            isDeliveryFeeLoading: _isDeliveryFeeResolutionLoading(
              visibleDeliveryFeeResolution,
              isUpdatingDeliveryFee: isUpdatingDeliveryFee,
              isAcceptingCounter: isAcceptingDeliveryFeeCounter,
              isBypassing: isBypassingDeliveryFee,
            ),
            onDeliveryFeePressed: _deliveryFeeResolutionCallback(
              visibleDeliveryFeeResolution,
              onEdit: onEditDeliveryFee,
              onAcceptCounter: onAcceptDeliveryFeeCounter,
              onBypass: onBypassDeliveryFee,
            ),
            primaryAction: renderedActions.first,
            isPrimaryLoading: isProcessing,
            onTapPrimaryAction: onTapAction,
          )
        else
          ...renderedActions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  onPressed: isProcessing || action.blocked
                      ? null
                      : () async {
                          await onTapAction(action);
                        },
                  child: isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : Text(action.label),
                ),
              ),
            ),
          ),
        if (!compact &&
            actions.any(
              (action) =>
                  action.blocked &&
                  (transferResolution == null ||
                      !_isTransferPaymentBlockedAction(action)) &&
                  (proofResolution == null || !_isProofBlockedAction(action)) &&
                  (deliveryFeeResolution?.blocksProgress != true ||
                      !_isDeliveryFeeBlockedAction(action)),
            ))
          Text(
            actions
                    .firstWhere(
                      (action) =>
                          action.blocked &&
                          (transferResolution == null ||
                              !_isTransferPaymentBlockedAction(action)) &&
                          (proofResolution == null ||
                              !_isProofBlockedAction(action)) &&
                          (deliveryFeeResolution?.blocksProgress != true ||
                              !_isDeliveryFeeBlockedAction(action)),
                    )
                    .blockedReason ??
                'Aksi masih terkunci.',
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
      ],
    );
  }
}

List<DriverOrderActionModel> _singlePrimaryActions(
  DriverOrderModel order,
  List<DriverOrderActionModel> availableActions,
) {
  if (availableActions.isEmpty) {
    return const <DriverOrderActionModel>[];
  }

  for (final action in availableActions) {
    if (_isProofBlockedAction(action)) {
      return <DriverOrderActionModel>[action];
    }
  }

  for (final action in availableActions) {
    if (action.isCodCollection) {
      return <DriverOrderActionModel>[action];
    }
  }

  return <DriverOrderActionModel>[availableActions.first];
}

class _ProofResolution {
  const _ProofResolution({
    required this.proofType,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.icon,
  });

  final String proofType;
  final String title;
  final String message;
  final String buttonLabel;
  final IconData icon;
}

class _CompactShoppingCheckoutActionRow extends StatelessWidget {
  const _CompactShoppingCheckoutActionRow({
    required this.deliveryFeeResolution,
    required this.isDeliveryFeeLoading,
    required this.onDeliveryFeePressed,
    required this.isProcessing,
    required this.isSavingCheckout,
    required this.onSaveCheckout,
  });

  final _DeliveryFeeResolution deliveryFeeResolution;
  final bool isDeliveryFeeLoading;
  final Future<void> Function()? onDeliveryFeePressed;
  final bool isProcessing;
  final bool isSavingCheckout;
  final Future<void> Function()? onSaveCheckout;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showIcons =
            constraints.maxWidth >= 300 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.3;

        return SizedBox(
          height: 52,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  onPressed:
                      isProcessing ||
                          isDeliveryFeeLoading ||
                          onDeliveryFeePressed == null
                      ? null
                      : () {
                          onDeliveryFeePressed!();
                        },
                  child: _CompactActionLabel(
                    label: deliveryFeeResolution.buttonLabel,
                    icon: isDeliveryFeeLoading
                        ? null
                        : deliveryFeeResolution.icon,
                    showIcon: showIcons,
                    loading: isDeliveryFeeLoading,
                    loadingColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 6,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: isProcessing ? null : onSaveCheckout,
                  child: _CompactActionLabel(
                    label: 'Simpan checkout',
                    icon: Icons.receipt_long_outlined,
                    showIcon: showIcons,
                    loading: isSavingCheckout,
                    loadingColor: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactActionLabel extends StatelessWidget {
  const _CompactActionLabel({
    required this.label,
    required this.icon,
    required this.showIcon,
    required this.loading,
    required this.loadingColor,
  });

  final String label;
  final IconData? icon;
  final bool showIcon;
  final bool loading;
  final Color loadingColor;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: loadingColor),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon && icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _CompactDeliveryFeeActionRow extends StatelessWidget {
  const _CompactDeliveryFeeActionRow({
    required this.deliveryFeeResolution,
    required this.isDeliveryFeeLoading,
    required this.onDeliveryFeePressed,
    required this.primaryAction,
    required this.isPrimaryLoading,
    required this.onTapPrimaryAction,
  });

  final _DeliveryFeeResolution deliveryFeeResolution;
  final bool isDeliveryFeeLoading;
  final Future<void> Function()? onDeliveryFeePressed;
  final DriverOrderActionModel primaryAction;
  final bool isPrimaryLoading;
  final Future<void> Function(DriverOrderActionModel action) onTapPrimaryAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 4,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
              onPressed: isDeliveryFeeLoading || onDeliveryFeePressed == null
                  ? null
                  : () {
                      onDeliveryFeePressed!();
                    },
              icon: isDeliveryFeeLoading
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(deliveryFeeResolution.icon, size: 18),
              label: Text(
                deliveryFeeResolution.buttonLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              onPressed: isPrimaryLoading || primaryAction.blocked
                  ? null
                  : () async {
                      await onTapPrimaryAction(primaryAction);
                    },
              child: isPrimaryLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(
                      primaryAction.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProofResolutionPrompt extends StatelessWidget {
  const _ProofResolutionPrompt({
    required this.resolution,
    required this.compact,
    required this.isLoading,
    required this.onPressed,
  });

  final _ProofResolution resolution;
  final bool compact;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      resolution.title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        height: 1.25,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.75),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(resolution.icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 3),
                      Text(
                        resolution.message,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ] else
          Padding(padding: const EdgeInsets.only(bottom: 6), child: title),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : Icon(resolution.icon),
            label: Text(resolution.buttonLabel),
          ),
        ),
      ],
    );
  }
}

class _DeliveryFeeResolution {
  const _DeliveryFeeResolution({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.icon,
    required this.action,
    required this.blocksProgress,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final IconData icon;
  final _DeliveryFeeResolutionAction action;
  final bool blocksProgress;
}

enum _DeliveryFeeResolutionAction { edit, acceptCounter, bypass }

class _DeliveryFeeResolutionPrompt extends StatelessWidget {
  const _DeliveryFeeResolutionPrompt({
    required this.resolution,
    required this.compact,
    required this.isLoading,
    required this.onPressed,
  });

  final _DeliveryFeeResolution resolution;
  final bool compact;
  final bool isLoading;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      resolution.title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        height: 1.25,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.75),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(resolution.icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 3),
                      Text(
                        resolution.message,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ] else
          Padding(padding: const EdgeInsets.only(bottom: 6), child: title),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
            onPressed: isLoading || onPressed == null
                ? null
                : () {
                    onPressed!();
                  },
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(resolution.icon),
            label: Text(resolution.buttonLabel),
          ),
        ),
      ],
    );
  }
}

class _TransferPaymentResolution {
  const _TransferPaymentResolution({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.icon,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final IconData icon;
}

class _TransferPaymentResolutionPrompt extends StatelessWidget {
  const _TransferPaymentResolutionPrompt({
    required this.resolution,
    required this.compact,
    required this.isLoading,
    required this.onPressed,
  });

  final _TransferPaymentResolution resolution;
  final bool compact;
  final bool isLoading;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final textContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          resolution.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 3),
          Text(
            resolution.message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(resolution.icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(child: textContent),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: textContent,
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            onPressed: isLoading || onPressed == null
                ? null
                : () {
                    onPressed!();
                  },
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : Icon(resolution.icon),
            label: Text(resolution.buttonLabel),
          ),
        ),
      ],
    );
  }
}

_TransferPaymentResolution? _transferPaymentResolutionFor(
  DriverOrderModel order,
  List<DriverOrderActionModel> actions,
) {
  if (!_isTransferPayment(order) || isPaymentPaid(order.paymentStatus)) {
    return null;
  }

  final hasPaymentBlockedAction = actions.any((action) {
    return _isTransferPaymentBlockedAction(action);
  });
  if (!hasPaymentBlockedAction) {
    return null;
  }

  final proof = _latestTransferProof(order);
  final hasProof = proof != null && (proof.photoUrl ?? '').trim().isNotEmpty;
  final hasPendingProof =
      hasProof && (proof.status ?? '').trim().toLowerCase() == 'pending';
  final isRejectedWithoutNewProof =
      order.paymentProofFeedback?.isRejected == true && !hasPendingProof;

  if (isRejectedWithoutNewProof) {
    return const _TransferPaymentResolution(
      title: 'Bukti QRIS ditolak',
      message: 'Minta customer mengirim bukti baru sebelum order diselesaikan.',
      buttonLabel: 'Lihat Status QRIS',
      icon: Icons.error_outline,
    );
  }

  if (hasProof) {
    return const _TransferPaymentResolution(
      title: 'Bukti QRIS menunggu verifikasi',
      message: 'Cek bukti pembayaran dulu, lalu selesaikan order.',
      buttonLabel: 'Verifikasi QRIS',
      icon: Icons.verified_outlined,
    );
  }

  return const _TransferPaymentResolution(
    title: 'Pembayaran QRIS belum selesai',
    message: 'Catat pembayaran manual jika customer sudah membayar.',
    buttonLabel: 'Catat Pembayaran QRIS Manual',
    icon: Icons.payments_outlined,
  );
}

_ProofResolution? _proofResolutionFor(
  DriverOrderModel order,
  List<DriverOrderActionModel> actions,
) {
  if (normalizeServiceTypeCode(order.serviceTypeCode) !=
      ServiceTypeCodes.courier) {
    return null;
  }

  final hasPickupBlock = actions.any(_isPickupProofBlockedAction);
  if (hasPickupBlock && !order.hasProof('pickup')) {
    return const _ProofResolution(
      proofType: 'pickup',
      title: 'Bukti pengambilan belum ada',
      message: 'Ambil foto barang saat diterima dari pengirim.',
      buttonLabel: 'Ambil Foto Pengambilan',
      icon: Icons.photo_camera_outlined,
    );
  }

  final hasDeliveryBlock = actions.any(_isDeliveryProofBlockedAction);
  if (hasDeliveryBlock && !order.hasProof('delivery')) {
    return const _ProofResolution(
      proofType: 'delivery',
      title: 'Bukti diterima belum ada',
      message: 'Ambil foto serah terima paket sebelum order diselesaikan.',
      buttonLabel: 'Ambil Foto Diterima',
      icon: Icons.photo_camera_outlined,
    );
  }

  return null;
}

_DeliveryFeeResolution? _deliveryFeeResolutionFor(
  DriverOrderModel order,
  List<DriverOrderActionModel> actions, {
  required bool canEdit,
  required bool canAcceptCounter,
  required bool canBypass,
}) {
  final negotiation = order.deliveryFeeNegotiation;
  if (negotiation == null) {
    return null;
  }

  final blocksProgress =
      actions.any(_isDeliveryFeeBlockedAction) ||
      (_shouldShowShoppingCheckoutAction(order) && negotiation.isPending);
  final counterAmount = negotiation.counterAmount ?? 0;
  if (blocksProgress &&
      negotiation.canDriverAcceptCounter &&
      canAcceptCounter &&
      counterAmount > 0) {
    return _DeliveryFeeResolution(
      title: 'Customer mengajukan ongkir',
      message:
          'Tawaran customer ${formatRupiah(counterAmount)} bisa diterima dari sini.',
      buttonLabel: 'Terima Tawaran Customer',
      icon: Icons.handshake_outlined,
      action: _DeliveryFeeResolutionAction.acceptCounter,
      blocksProgress: true,
    );
  }

  if (blocksProgress && negotiation.isPendingCustomer) {
    final quotedAmount = negotiation.quotedAmount ?? 0;
    return _DeliveryFeeResolution(
      title: 'Ongkir menunggu persetujuan',
      message: canBypass
          ? '${quotedAmount > 0 ? '${formatRupiah(quotedAmount)} ' : ''}belum disetujui customer. Checkout belum dapat disimpan.'
          : 'Customer belum menyetujui ongkir terbaru.',
      buttonLabel: canBypass ? 'Lanjut Tanpa Persetujuan' : 'Menunggu Customer',
      icon: Icons.payments_outlined,
      action: _DeliveryFeeResolutionAction.bypass,
      blocksProgress: true,
    );
  }

  if (negotiation.canDriverSubmitQuote && canEdit) {
    return const _DeliveryFeeResolution(
      title: 'Ongkir perlu disesuaikan?',
      message: 'Ubah ongkir dari task aktif tanpa kembali ke Ringkasan.',
      buttonLabel: 'Ubah Ongkir',
      icon: Icons.edit_outlined,
      action: _DeliveryFeeResolutionAction.edit,
      blocksProgress: false,
    );
  }

  return null;
}

bool _isDeliveryFeeResolutionLoading(
  _DeliveryFeeResolution resolution, {
  required bool isUpdatingDeliveryFee,
  required bool isAcceptingCounter,
  required bool isBypassing,
}) {
  return switch (resolution.action) {
    _DeliveryFeeResolutionAction.edit => isUpdatingDeliveryFee,
    _DeliveryFeeResolutionAction.acceptCounter => isAcceptingCounter,
    _DeliveryFeeResolutionAction.bypass => isBypassing,
  };
}

Future<void> Function()? _deliveryFeeResolutionCallback(
  _DeliveryFeeResolution resolution, {
  required Future<void> Function()? onEdit,
  required Future<void> Function()? onAcceptCounter,
  required Future<void> Function()? onBypass,
}) {
  return switch (resolution.action) {
    _DeliveryFeeResolutionAction.edit => onEdit,
    _DeliveryFeeResolutionAction.acceptCounter => onAcceptCounter,
    _DeliveryFeeResolutionAction.bypass => onBypass,
  };
}

bool _isTransferPaymentBlockedAction(DriverOrderActionModel action) {
  final reason = action.blockedReason?.toLowerCase() ?? '';
  return action.blocked &&
      (reason.contains('pembayaran') ||
          reason.contains('qris') ||
          reason.contains('transfer'));
}

bool _isProofBlockedAction(DriverOrderActionModel action) {
  return _isPickupProofBlockedAction(action) ||
      _isDeliveryProofBlockedAction(action);
}

bool _isDeliveryFeeBlockedAction(DriverOrderActionModel action) {
  final reason = action.blockedReason?.toLowerCase() ?? '';
  return action.blocked &&
      reason.contains('revisi') &&
      reason.contains('ongkir');
}

bool _isPickupProofBlockedAction(DriverOrderActionModel action) {
  final reason = action.blockedReason?.toLowerCase() ?? '';
  return action.blocked &&
      reason.contains('bukti') &&
      reason.contains('foto') &&
      reason.contains('pickup');
}

bool _isDeliveryProofBlockedAction(DriverOrderActionModel action) {
  final reason = action.blockedReason?.toLowerCase() ?? '';
  return action.blocked &&
      reason.contains('bukti') &&
      reason.contains('foto') &&
      (reason.contains('pengantaran') ||
          reason.contains('delivery') ||
          reason.contains('diterima'));
}

bool _isTransferPayment(DriverOrderModel order) {
  final method = order.paymentMethod.trim().toUpperCase();
  return method == 'TRANSFER';
}

DriverOrderProofModel? _latestTransferProof(DriverOrderModel order) {
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

bool _shouldShowShoppingClosureFeeHint(DriverOrderModel order) {
  final pricing = order.shoppingPricing;
  if (normalizeServiceTypeCode(order.serviceTypeCode) !=
          ServiceTypeCodes.shopping ||
      order.shoppingStops.where((stop) => stop.isActive).isEmpty ||
      pricing == null) {
    return false;
  }

  final shoppingStopCount = order.shoppingStops
      .where((stop) => !stop.isReplaced)
      .length;
  if (shoppingStopCount < pricing.failedAttemptThreshold) {
    return false;
  }

  final status = normalizeOrderStatusCode(order.statusCode);
  return status == OrderStatusCodes.driverAssigned ||
      status == OrderStatusCodes.arrivedMerchant;
}

bool _shouldShowShoppingCheckoutAction(DriverOrderModel order) {
  return _isShoppingOrder(order) &&
      order.shoppingCapabilities.canDriverUploadReceipt &&
      !order.shoppingCapabilities.hasCheckoutSaved &&
      !order.shoppingCapabilities.hasPendingItemChangeRequest &&
      (order.shoppingNegotiation?.checkoutAllowed ?? false);
}

bool _isShoppingOrder(DriverOrderModel order) {
  return normalizeServiceTypeCode(order.serviceTypeCode) ==
      ServiceTypeCodes.shopping;
}

bool _shouldShowDeliveryFeeShortcut(DriverOrderModel order) {
  final negotiation = order.deliveryFeeNegotiation;
  return negotiation?.canDriverSubmitQuote == true ||
      negotiation?.canDriverAcceptCounter == true ||
      negotiation?.isPendingCustomer == true;
}

String _shoppingClosureFeeHint(DriverShoppingPricingModel pricing) {
  final attempts =
      '${pricing.failedAttemptCount}/${pricing.failedAttemptThreshold}';
  if (pricing.canCancelWithFee) {
    return 'Tempat tutup/order batal $attempts. Tagihan customer 50% ongkir sudah aktif.';
  }

  return 'Tempat tutup/order batal $attempts. Tagihan customer 50% ongkir aktif setelah batas tercapai.';
}
