import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../models/driver_order_model.dart';
import '../../../../utils/courier_package_formatter.dart';
import '../../../../utils/currency_formatter.dart';
import '../../../../utils/service_type.dart';
import 'driver_active_order_fee_widgets.dart';

// --- Helper for consistent card styling ---
Widget _buildDriverCard({required Widget child}) {
  return Container(
    width: double.infinity,
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
    child: child,
  );
}

// ---------------------------------------------------------------------------
// 1. DriverOrderCustomerCard
// ---------------------------------------------------------------------------
class DriverOrderCustomerCard extends StatelessWidget {
  final DriverOrderModel order;

  const DriverOrderCustomerCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final serviceLabel = serviceTypeLabel(order.serviceTypeCode);

    return _buildDriverCard(
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
                        fontSize: 16,
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
              _pill(serviceLabel, AppColors.surfaceAlt, AppColors.textPrimary),
              _pill(
                order.statusDisplayName ?? order.statusCode,
                AppColors.surfaceAlt,
                AppColors.success,
              ),
              if (order.paymentStatus.isNotEmpty)
                _pill(
                  '${order.paymentMethod.toUpperCase()} ${order.paymentStatus.toUpperCase()}',
                  AppColors.surfaceAlt,
                  AppColors.textSecondary,
                ),
            ],
          ),
        ],
      ),
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
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class DriverOrderMetaCard extends StatelessWidget {
  final DriverOrderModel order;

  const DriverOrderMetaCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return DriverOrderCustomerCard(order: order);
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
  final bool showDriverAdminFeeBreakdown;

  const DriverOrderPricingCard({
    super.key,
    required this.order,
    this.isProcessing = false,
    this.onEditDeliveryFee,
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
              'Pendapatan Bruto',
              _formatCurrency(order.driverIncomeGross.round()),
            ),
            const SizedBox(height: 8),
          ] else if (fee != total) ...[
            _pricingLine('Fee Driver', _formatCurrency(fee)),
            const SizedBox(height: 8),
          ],
          if (showAdminFee) ...[
            _pricingLine(
              'Biaya Admin ${_formatPercent(order.driverAdminFeePercent)}',
              _formatCurrency(order.driverAdminFee.round()),
            ),
            const SizedBox(height: 8),
            _pricingLine(
              'Pendapatan Bersih',
              _formatCurrency(order.driverIncomeNet.round()),
              valueColor: AppColors.primaryDark,
              valueSize: 15,
            ),
            const SizedBox(height: 8),
          ],
          if (order.deliveryFee != null && order.deliveryFee! > 0) ...[
            _pricingLine('Ongkir', formatRupiah(order.deliveryFee!)),
            const SizedBox(height: 8),
          ],
          if (deliveryFeeSourceLabel.isNotEmpty) ...[
            _pricingLine('Sumber', deliveryFeeSourceLabel),
            const SizedBox(height: 8),
          ],
          _pricingLine(
            'Total Pembayaran',
            _formatCurrency(total),
            valueColor: AppColors.primaryDark,
            valueSize: 17,
          ),
        ],
      ),
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
