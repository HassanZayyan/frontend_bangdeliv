import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../models/driver_order_model.dart';
import '../../../../utils/courier_package_formatter.dart';
import '../../../../utils/currency_formatter.dart';
import '../../../../utils/service_type.dart';
import '../../../../widgets/shopping_fee_breakdown.dart';

class DriverOrderMetaCard extends StatelessWidget {
  final DriverOrderModel order;

  const DriverOrderMetaCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final serviceLabel = serviceTypeLabel(order.serviceTypeCode);
    final packageDetails = buildCourierPackageDetails(order);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(order.customerName),
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
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Order ID: ${order.orderNumber.isEmpty ? order.id : order.orderNumber}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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
              _pill(
                serviceLabel,
                AppColors.primary.withValues(alpha: 0.1),
                AppColors.primaryDark,
              ),
              _pill(
                order.statusDisplayName ?? order.statusCode,
                AppColors.success.withValues(alpha: 0.12),
                AppColors.success,
              ),
              if (order.paymentStatus.isNotEmpty)
                _pill(
                  '${order.paymentMethod.toUpperCase()} ${order.paymentStatus.toUpperCase()}',
                  AppColors.darkBlue.withValues(alpha: 0.08),
                  AppColors.darkBlue,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _routeVisualizer(order),
          if (order.deliveryDistanceLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            _row('Jarak', order.deliveryDistanceLabel),
          ],
          ..._buildCourierPackageRows(packageDetails),
          const SizedBox(height: 14),
          _buildPricingSummary(),
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pickupStops.isEmpty)
            _routeStop(
              icon: Icons.storefront_rounded,
              iconColor: AppColors.primary,
              title: 'Jemput',
              value: order.pickupAddress,
            )
          else
            ...pickupStops.map((stop) {
              final sequence = stop.sequenceNo <= 0 ? 1 : stop.sequenceNo;
              final address = (stop.merchant.address ?? '').trim();
              final status = stop.isFailed
                  ? 'Resto tutup/order batal'
                  : stop.isSkipped
                  ? 'Dilewati'
                  : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _routeStop(
                  icon: Icons.storefront_rounded,
                  iconColor: stop.isFailed
                      ? AppColors.error
                      : AppColors.primary,
                  title: 'Merchant $sequence',
                  value: [
                    stop.merchant.name,
                    if (address.isNotEmpty) address,
                    ?status,
                  ].join('\n'),
                ),
              );
            }),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                  5,
                  (index) => Container(
                    width: 2,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _routeStop(
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFF2563EB),
            title: 'Tujuan',
            value: order.dropoffAddress,
          ),
        ],
      ),
    );
  }

  Widget _routeStop({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: iconColor),
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

  Widget _buildAvatar(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.isEmpty || parts.first.isEmpty
        ? '?'
        : parts.length == 1
        ? parts.first.characters.first.toUpperCase()
        : '${parts.first.characters.first}${parts.last.characters.first}'
              .toUpperCase();

    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryLight,
            AppColors.primary.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _row(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 58,
          child: Text(
            title,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
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
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCourierPackageRows(CourierPackageDetails details) {
    if (!details.isCourier) {
      return const [];
    }

    final rows = <Widget>[];

    void addRow(String title, String value) {
      if (value.isEmpty) {
        return;
      }

      rows
        ..add(const SizedBox(height: 6))
        ..add(_row(title, value));
    }

    addRow('Barang', details.description);

    return rows;
  }

  Widget _buildPricingSummary() {
    final fee = order.fee;
    final total = order.totalPrice.round();
    final pricing = order.shoppingPricing;
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.cardYellow,
            AppColors.primaryLight.withValues(alpha: 0.3),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fee != total) ...[
                  const Text(
                    'Fee Driver',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _formatCurrency(fee),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (order.deliveryFee != null && order.deliveryFee! > 0) ...[
                  const Text(
                    'Ongkir',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    formatRupiah(order.deliveryFee!),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (deliveryFeeSourceLabel.isNotEmpty ||
                      (supportsCarefulCarry && order.carefulCarryRequired))
                    Text(
                      [
                        if (deliveryFeeSourceLabel.isNotEmpty)
                          deliveryFeeSourceLabel,
                        if (supportsCarefulCarry && order.carefulCarryRequired)
                          'perlu 2 orang',
                      ].join(' - '),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'Total Pembayaran',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatCurrency(total),
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (pricing != null && pricing.feeBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ShoppingFeeBreakdown(
                    items: pricing.feeBreakdown
                        .map(
                          (item) => ShoppingFeeBreakdownItem(
                            label: item.label,
                            description: item.description,
                            amount: item.amount,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ] else if (order.feeBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ShoppingFeeBreakdown(
                    items: order.feeBreakdown
                        .map(
                          (item) => ShoppingFeeBreakdownItem(
                            label: item.label,
                            description: item.description,
                            amount: item.amount,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.payments_rounded,
              color: AppColors.primaryDark.withValues(alpha: 0.8),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(int amount) {
    return formatRupiah(amount);
  }
}
