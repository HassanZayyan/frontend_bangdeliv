import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/app_colors.dart';
import '../../../../models/driver_order_model.dart';
import '../../../../utils/currency_formatter.dart';
import '../../../../utils/order_formatters.dart' show formatTime;
import '../../../../utils/order_status.dart';
import '../../../../utils/order_ui_helpers.dart';
import '../../../../utils/service_type.dart';
import 'driver_active_order_widget_helpers.dart';

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
            children: [
              Icon(Icons.history_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
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
                                ? AppColors.white
                                : AppColors.textSecondary.withValues(
                                    alpha: 0.2,
                                  ),
                            border: isLast
                                ? Border.all(color: AppColors.primary, width: 4)
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
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 12,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeText,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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
  final Future<void> Function({
    required int pickupLocationId,
    required String reason,
    required XFile storeClosedPhoto,
  })?
  onReportPickupFailed;
  final Future<void> Function(DriverOrderActionModel action) onTapAction;

  const DriverOrderActionCard({
    super.key,
    required this.order,
    required this.isProcessing,
    required this.onReportPickupFailed,
    required this.onTapAction,
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
    final canReportPickupFailed = _canReportPickupFailed();

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
            children: [
              Icon(Icons.touch_app_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Aksi Driver',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (canReportPickupFailed) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isProcessing || onReportPickupFailed == null
                    ? null
                    : () async {
                        final report = await _showFailedPickupDialog(context);
                        if (report == null) {
                          return;
                        }
                        await onReportPickupFailed?.call(
                          pickupLocationId: report.pickupLocationId,
                          reason: report.reason,
                          storeClosedPhoto: report.storeClosedPhoto,
                        );
                      },
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('Merchant Tutup / Gagal Pickup'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
            if (pricing != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 10),
                child: Text(
                  'Percobaan gagal ${pricing.failedAttemptCount}/${pricing.failedAttemptThreshold}. Fee cancel aktif setelah batas tercapai.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              const SizedBox(height: 10),
          ],
          if (hasCodCollection) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.16),
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
            ...actions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: GoogleFonts.nunitoSans(
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
      ),
    );
  }

  bool _canReportPickupFailed() {
    if (onReportPickupFailed == null ||
        normalizeServiceTypeCode(order.serviceTypeCode) !=
            ServiceTypeCodes.shopping ||
        order.shoppingStops.where((stop) => stop.isActive).isEmpty ||
        order.shoppingPricing?.canCancelWithFee == true) {
      return false;
    }

    final status = normalizeOrderStatusCode(order.statusCode);
    return status == OrderStatusCodes.driverAssigned ||
        status == OrderStatusCodes.arrivedMerchant;
  }

  Future<_FailedPickupReport?> _showFailedPickupDialog(BuildContext context) {
    return showDialog<_FailedPickupReport>(
      context: context,
      builder: (context) => _FailedPickupDialog(
        stops: order.shoppingStops
            .where((stop) => stop.isActive)
            .toList(growable: false),
      ),
    );
  }
}

class _FailedPickupReport {
  const _FailedPickupReport({
    required this.pickupLocationId,
    required this.reason,
    required this.storeClosedPhoto,
  });

  final int pickupLocationId;
  final String reason;
  final XFile storeClosedPhoto;
}

class _FailedPickupDialog extends StatefulWidget {
  const _FailedPickupDialog({required this.stops});

  final List<DriverShoppingStopModel> stops;

  @override
  State<_FailedPickupDialog> createState() => _FailedPickupDialogState();
}

class _FailedPickupDialogState extends State<_FailedPickupDialog> {
  final TextEditingController _reasonController = TextEditingController(
    text: 'Merchant tutup saat driver tiba.',
  );
  late int _selectedPickupLocationId;
  XFile? _storeClosedPhoto;

  @override
  void initState() {
    super.initState();
    _selectedPickupLocationId = widget.stops.first.pickupLocationId;
  }

  @override
  void dispose() {
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
                      'Merchant Tutup',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedPickupLocationId,
                      isExpanded: true,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: driverDialogInputDecoration(
                        labelText: 'Merchant',
                      ),
                      items: widget.stops
                          .map(
                            (stop) => DropdownMenuItem<int>(
                              value: stop.pickupLocationId,
                              child: Text(
                                '${stop.sequenceNo <= 0 ? 1 : stop.sequenceNo}. ${stop.merchant.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _selectedPickupLocationId = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reasonController,
                      minLines: 2,
                      maxLines: 4,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: driverDialogInputDecoration(
                        labelText: 'Alasan',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final photo = await pickDriverOrderImage(context);
                        if (photo == null || !mounted) {
                          return;
                        }
                        setState(() => _storeClosedPhoto = photo);
                      },
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: Text(
                        _storeClosedPhoto == null
                            ? 'Upload Foto Toko Tutup'
                            : 'Foto Toko Siap',
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
                          onPressed: () {
                            final reason = _reasonController.text.trim();
                            if (reason.isEmpty) {
                              return;
                            }
                            final photo = _storeClosedPhoto;
                            if (photo == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Foto toko tutup wajib diupload.',
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              return;
                            }
                            Navigator.of(context).pop(
                              _FailedPickupReport(
                                pickupLocationId: _selectedPickupLocationId,
                                reason: reason,
                                storeClosedPhoto: photo,
                              ),
                            );
                          },
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
    );
  }
}
