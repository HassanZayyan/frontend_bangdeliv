import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/app_colors.dart';
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
        borderRadius: BorderRadius.circular(14),
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
                              borderRadius: BorderRadius.circular(2),
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
        borderRadius: BorderRadius.circular(14),
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
  final Future<void> Function(DriverOrderActionModel action) onTapAction;

  const DriverOrderStickyActionBar({
    super.key,
    required this.order,
    required this.isProcessing,
    required this.onTapAction,
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
          padding: const EdgeInsets.fromLTRB(
            16,
            10,
            16,
            BangFloatingBottomNavBar.scrollClearance - 42,
          ),
          child: _DriverOrderActionControls(
            order: order,
            isProcessing: isProcessing,
            onTapAction: onTapAction,
            showEmptyState: false,
          ),
        ),
      ),
    );
  }

  bool _hasVisibleContent() {
    if (order.availableActions.isNotEmpty) {
      return true;
    }

    return _shouldShowShoppingClosureFeeHint(order);
  }
}

class _DriverOrderActionControls extends StatelessWidget {
  final DriverOrderModel order;
  final bool isProcessing;
  final Future<void> Function(DriverOrderActionModel action) onTapAction;
  final bool showEmptyState;

  const _DriverOrderActionControls({
    required this.order,
    required this.isProcessing,
    required this.onTapAction,
    required this.showEmptyState,
  });

  @override
  Widget build(BuildContext context) {
    final actions = order.availableActions;
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showShoppingClosureFeeHint && pricing != null) ...[
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
        if (hasCodCollection) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
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
        if (actions.isEmpty)
          if (showEmptyState)
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
        else
          ...actions.map(
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
                      borderRadius: BorderRadius.circular(12),
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
        if (actions.any((action) => action.blocked))
          Text(
            actions.firstWhere((action) => action.blocked).blockedReason ??
                'Aksi masih terkunci.',
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
      ],
    );
  }
}

bool _shouldShowShoppingClosureFeeHint(DriverOrderModel order) {
  if (normalizeServiceTypeCode(order.serviceTypeCode) !=
          ServiceTypeCodes.shopping ||
      order.shoppingStops.where((stop) => stop.isActive).isEmpty ||
      order.shoppingPricing == null) {
    return false;
  }

  final status = normalizeOrderStatusCode(order.statusCode);
  return status == OrderStatusCodes.driverAssigned ||
      status == OrderStatusCodes.arrivedMerchant;
}

String _shoppingClosureFeeHint(DriverShoppingPricingModel pricing) {
  final attempts =
      '${pricing.failedAttemptCount}/${pricing.failedAttemptThreshold}';
  if (pricing.canCancelWithFee) {
    return 'Tempat tutup/order batal $attempts. Tagihan customer 50% ongkir sudah aktif.';
  }

  return 'Tempat tutup/order batal $attempts. Tagihan customer 50% ongkir aktif setelah batas tercapai.';
}
