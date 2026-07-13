import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../core/widgets/bang_swipe_action_button.dart';
import '../../../../models/driver_order_model.dart';
import '../../../../utils/courier_package_formatter.dart';
import '../../../../utils/currency_formatter.dart';
import '../../../../utils/order_ui_helpers.dart';
import '../../../../utils/service_type.dart';
import '../../../../widgets/profile_avatar.dart';
import 'driver_active_order_fee_widgets.dart';

// --- Helper for consistent card styling ---
Widget _buildDriverCard({required Widget child}) {
  return Container(
    width: double.infinity,
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
    child: child,
  );
}

// ---------------------------------------------------------------------------
// 1. DriverOrderCustomerCard
// ---------------------------------------------------------------------------
class DriverOrderCustomerCard extends StatelessWidget {
  final DriverOrderModel order;
  final bool showOrderIdLabel;

  const DriverOrderCustomerCard({
    super.key,
    required this.order,
    this.showOrderIdLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final serviceLabel = serviceTypeLabel(order.serviceTypeCode);
    final orderNumber = order.orderNumber.isEmpty
        ? order.id
        : order.orderNumber;

    return _buildDriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _serviceTypeLabel(order.serviceTypeCode, serviceLabel),
              ),
              const SizedBox(width: 12),
              _orderNumberText(
                showOrderIdLabel ? 'Order ID: $orderNumber' : orderNumber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CustomerAvatar(
                name: order.customerName,
                avatarUrl: order.customerAvatarUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    _metadataText(
                      order.statusDisplayName ?? order.statusCode,
                      AppColors.success,
                    ),
                    if (order.paymentStatus.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _metadataText(
                        '${paymentMethodLabel(order.paymentMethod)} - ${paymentStatusLabel(order.paymentStatus)}',
                        AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orderNumberText(String label) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _serviceTypeLabel(String serviceTypeCode, String label) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            serviceTypeLeadingIcon(serviceTypeCode),
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metadataText(
    String text,
    Color color, {
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 12.5,
        fontWeight: fontWeight,
        height: 1.2,
      ),
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _CustomerAvatar({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return ProfileAvatar(
      name: name,
      avatarUrl: avatarUrl,
      size: 42,
      imageScale: 1.12,
    );
  }
}

class DriverOrderMetaCard extends StatelessWidget {
  final DriverOrderModel order;
  final bool showOrderIdLabel;

  const DriverOrderMetaCard({
    super.key,
    required this.order,
    this.showOrderIdLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return DriverOrderCustomerCard(
      order: order,
      showOrderIdLabel: showOrderIdLabel,
    );
  }
}

// ---------------------------------------------------------------------------
// 2. DriverOrderRouteCard
// ---------------------------------------------------------------------------
class DriverOrderRouteCard extends StatelessWidget {
  final DriverOrderModel order;

  const DriverOrderRouteCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return _buildDriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rute Pesanan',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _routeVisualizer(order),
        ],
      ),
    );
  }

  Widget _routeVisualizer(DriverOrderModel order) {
    final activeStops = order.shoppingStops
        .where((stop) => stop.isActive)
        .toList(growable: false);
    final pickupStops = activeStops.isNotEmpty
        ? activeStops
        : <DriverShoppingStopModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pickupStops.isEmpty)
          _routeStop(
            icon: Icons.radio_button_checked,
            iconColor: AppColors.primary,
            title: 'Jemput',
            value: order.pickupAddress,
          )
        else
          ...pickupStops.map((stop) {
            final sequence = stop.sequenceNo <= 0 ? 1 : stop.sequenceNo;
            final address = (stop.merchant.address ?? '').trim();
            final status = stop.isFailed
                ? 'Tutup/gagal pickup'
                : stop.isSkipped
                ? 'Dilewati'
                : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _routeStop(
                icon: Icons.radio_button_checked,
                iconColor: stop.isFailed ? AppColors.error : AppColors.primary,
                title: 'Tempat $sequence',
                value: [
                  stop.merchant.name,
                  if (address.isNotEmpty) address,
                  ?status,
                ].join('\n'),
                emphasizeFirstValueLine: true,
              ),
            );
          }),
        const SizedBox(height: 8),
        _routeStop(
          icon: Icons.location_on_rounded,
          iconColor: const Color(0xFF2563EB),
          title: 'Tujuan',
          value: order.dropoffAddress,
        ),
      ],
    );
  }

  Widget _routeStop({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    bool emphasizeFirstValueLine = false,
  }) {
    final valueLines = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 20,
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              if (emphasizeFirstValueLine && valueLines.isNotEmpty)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: valueLines.first,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (valueLines.length > 1)
                        TextSpan(
                          text: '\n${valueLines.skip(1).join('\n')}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                )
              else
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. DriverOrderPackageCard
// ---------------------------------------------------------------------------
class DriverOrderPackageCard extends StatelessWidget {
  final DriverOrderModel order;

  const DriverOrderPackageCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final packageDetails = buildCourierPackageDetails(order);

    if (!packageDetails.isCourier || packageDetails.description.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildDriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detail Barang',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                width: 58,
                child: Text(
                  'Barang',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Text(
                ':',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  packageDetails.description,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. DriverOrderPricingCard
// ---------------------------------------------------------------------------
class DriverOrderPricingCard extends StatelessWidget {
  final DriverOrderModel order;
  final bool isProcessing;
  final Future<String?> Function({
    required double amount,
    required String reason,
  })?
  onEditDeliveryFee;
  final Future<void> Function()? onAcceptDeliveryFeeCounter;
  final Future<void> Function()? onBypassDeliveryFee;
  final bool isAcceptingDeliveryFeeCounter;
  final bool isBypassingDeliveryFee;
  final bool showDriverAdminFeeBreakdown;

  const DriverOrderPricingCard({
    super.key,
    required this.order,
    this.isProcessing = false,
    this.onEditDeliveryFee,
    this.onAcceptDeliveryFeeCounter,
    this.onBypassDeliveryFee,
    this.isAcceptingDeliveryFeeCounter = false,
    this.isBypassingDeliveryFee = false,
    this.showDriverAdminFeeBreakdown = false,
  });

  @override
  Widget build(BuildContext context) {
    final fee = order.fee;
    final total = order.totalPrice.round();
    final deliveryFeeSource = (order.deliveryFeeSource ?? '')
        .trim()
        .toLowerCase();
    final deliveryFeeSourceLabel = deliveryFeeSource == 'driver_manual'
        ? 'manual driver'
        : deliveryFeeSource;
    final showAdminFee =
        showDriverAdminFeeBreakdown &&
        order.driverAdminFee > 0 &&
        order.driverIncomeGross > order.driverIncomeNet;
    final deliveryFeeNegotiation = order.deliveryFeeNegotiation;
    final isShoppingTotalTransport =
        deliveryFeeNegotiation?.isActiveShoppingTotalTransport == true;
    final counterAmount = deliveryFeeNegotiation?.counterAmount ?? 0;
    final showCounterOffer =
        onAcceptDeliveryFeeCounter != null &&
        deliveryFeeNegotiation?.canDriverAcceptCounter == true &&
        counterAmount > 0;
    final pendingCustomerAmount = deliveryFeeNegotiation?.quotedAmount ?? 0;
    final showBypassDeliveryFee =
        onBypassDeliveryFee != null &&
        deliveryFeeNegotiation?.isPendingCustomer == true &&
        pendingCustomerAmount > 0;

    return _buildDriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Pembayaran',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onEditDeliveryFee != null)
                TextButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => showDriverManualDeliveryFeeEditDialog(
                          context,
                          order: order,
                          onSave: onEditDeliveryFee!,
                        ),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primaryDark,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (showDriverAdminFeeBreakdown && order.driverIncomeGross > 0) ...[
            _pricingLine(
              'Pendapatan bruto',
              _formatCurrency(order.driverIncomeGross.round()),
            ),
            const SizedBox(height: 8),
          ],
          if (showAdminFee) ...[
            _pricingLine(
              'Biaya admin ${_formatPercent(order.driverAdminFeePercent)}',
              _formatCurrency(order.driverAdminFee.round()),
            ),
            const SizedBox(height: 8),
            _pricingLine(
              'Pendapatan bersih',
              _formatCurrency(order.driverIncomeNet.round()),
              valueColor: AppColors.primaryDark,
              valueSize: 15,
            ),
            const SizedBox(height: 8),
          ],
          if (!showDriverAdminFeeBreakdown &&
              order.deliveryFee != null &&
              order.deliveryFee! > 0) ...[
            _pricingLine(
              isShoppingTotalTransport ? 'Total ongkir Nitip' : 'Ongkir aktif',
              formatRupiah(order.deliveryFee!),
            ),
            const SizedBox(height: 8),
          ],
          if (!showDriverAdminFeeBreakdown &&
              !isShoppingTotalTransport &&
              (order.shoppingPricing?.failedTripCompensation ?? 0) > 0) ...[
            _pricingLine(
              'Kompensasi perjalanan gagal (50%)',
              formatRupiah(order.shoppingPricing!.failedTripCompensation),
            ),
            const SizedBox(height: 8),
          ],
          if (!showDriverAdminFeeBreakdown &&
              fee > 0 &&
              order.deliveryFee != null &&
              (fee - order.deliveryFee!).abs() >= 1) ...[
            _pricingLine('Pendapatan transport', _formatCurrency(fee)),
            const SizedBox(height: 8),
          ],
          if (deliveryFeeSourceLabel.isNotEmpty) ...[
            _pricingLine('Sumber', deliveryFeeSourceLabel),
            const SizedBox(height: 8),
          ],
          _pricingLine(
            'Total pembayaran customer',
            _formatCurrency(total),
            valueColor: AppColors.primaryDark,
            valueSize: 17,
          ),
          if (showCounterOffer) ...[
            const SizedBox(height: 14),
            _buildDeliveryFeeCounterOffer(counterAmount),
          ],
          if (showBypassDeliveryFee) ...[
            const SizedBox(height: 14),
            _buildDeliveryFeeBypassAction(pendingCustomerAmount),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryFeeBypassAction(double quotedAmount) {
    final negotiation = order.deliveryFeeNegotiation;
    final isShoppingTotalTransport =
        negotiation?.isShoppingTotalTransport == true;
    final currentAmount = isShoppingTotalTransport
        ? negotiation?.previousTotalTransport
        : order.deliveryFee ?? negotiation?.oldDeliveryFee;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isShoppingTotalTransport
                ? 'Menunggu persetujuan total ongkir Nitip'
                : 'Menunggu persetujuan ongkir customer',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _counterDetailLine(
            isShoppingTotalTransport ? 'Total usulan driver' : 'Revisi driver',
            formatRupiah(quotedAmount),
          ),
          if (currentAmount != null && currentAmount > 0) ...[
            const SizedBox(height: 6),
            _counterDetailLine(
              isShoppingTotalTransport
                  ? 'Total transport sebelumnya'
                  : 'Ongkir saat ini',
              formatRupiah(currentAmount),
            ),
          ],
          const SizedBox(height: 10),
          BangSwipeActionButton(
            label: isShoppingTotalTransport
                ? 'Geser untuk bypass total ongkir'
                : 'Geser untuk bypass ongkir',
            loadingLabel: 'Memproses bypass...',
            isLoading: isBypassingDeliveryFee,
            isEnabled: !isProcessing && !isBypassingDeliveryFee,
            onSubmit: onBypassDeliveryFee,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryFeeCounterOffer(double counterAmount) {
    final negotiation = order.deliveryFeeNegotiation;
    final isShoppingTotalTransport =
        negotiation?.isShoppingTotalTransport == true;
    final quotedAmount = negotiation?.quotedAmount;
    final currentAmount = isShoppingTotalTransport
        ? negotiation?.previousTotalTransport
        : order.deliveryFee ?? negotiation?.oldDeliveryFee;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
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
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                ),
                child: const Icon(
                  Icons.local_offer_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isShoppingTotalTransport
                          ? 'Tawaran total ongkir customer'
                          : 'Tawaran ongkir customer',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatRupiah(counterAmount),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (quotedAmount != null && quotedAmount > 0) ...[
            _counterDetailLine(
              isShoppingTotalTransport
                  ? 'Total usulan driver'
                  : 'Revisi driver',
              formatRupiah(quotedAmount),
            ),
            const SizedBox(height: 6),
          ],
          if (currentAmount != null && currentAmount > 0) ...[
            _counterDetailLine(
              isShoppingTotalTransport
                  ? 'Total transport sebelumnya'
                  : 'Ongkir saat ini',
              formatRupiah(currentAmount),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isProcessing || isAcceptingDeliveryFeeCounter
                  ? null
                  : () => unawaited(onAcceptDeliveryFeeCounter!()),
              child: isAcceptingDeliveryFeeCounter
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Text('Terima Tawaran'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _counterDetailLine(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _pricingLine(
    String label,
    String value, {
    String? note,
    Color valueColor = AppColors.textPrimary,
    double valueSize = 14,
  }) {
    final hasNote = note != null && note.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (hasNote) ...[
              Text(
                note,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontSize: valueSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatCurrency(int amount) {
    return formatRupiah(amount);
  }

  String _formatPercent(double percent) {
    final fixed = percent.toStringAsFixed(2);
    return '${fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')}%';
  }
}
