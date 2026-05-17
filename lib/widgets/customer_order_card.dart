import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../models/customer_order_model.dart';
import '../utils/order_formatters.dart';
import '../utils/order_ui_helpers.dart';
import '../utils/service_type.dart';

class CustomerOrderCard extends StatelessWidget {
  const CustomerOrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.onTrack,
    this.onCancel,
    this.onReorder,
    this.isCancelling = false,
    this.showTrackAction = false,
    this.showCancelAction = false,
    this.showReorderAction = false,
    this.showDetailHint = false,
  });

  final CustomerOrderSummaryModel order;
  final VoidCallback? onTap;
  final VoidCallback? onTrack;
  final VoidCallback? onCancel;
  final VoidCallback? onReorder;
  final bool isCancelling;
  final bool showTrackAction;
  final bool showCancelAction;
  final bool showReorderAction;
  final bool showDetailHint;

  @override
  Widget build(BuildContext context) {
    final statusColor = orderStatusColor(order.statusCode);
    final serviceCode = normalizeServiceTypeCode(order.serviceTypeCode);
    final hideItemsSummary =
        serviceCode == 'RIDE' &&
        order.itemsSummary.trim().toLowerCase() == 'tanpa item';

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.orderNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(statusColor),
                  ],
                ),
                const SizedBox(height: 10),
                _buildServiceTypeChip(order),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(
                        serviceTypeLeadingIcon(serviceCode),
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.restaurantName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (!hideItemsSummary) ...[
                            const SizedBox(height: 4),
                            Text(
                              order.itemsSummary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: AppColors.border, height: 1),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final shouldStackActions =
                        _hasAnyAction && constraints.maxWidth < 380;

                    if (shouldStackActions) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildOrderMeta(),
                          const SizedBox(height: 10),
                          _buildActionButtons(
                            context: context,
                            horizontal: _actionCount == 2,
                            compact: true,
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildOrderMeta()),
                        if (_hasAnyAction) ...[
                          const SizedBox(width: 12),
                          _buildActionButtons(context: context, compact: true),
                        ],
                      ],
                    );
                  },
                ),
                if (showDetailHint && onTap != null) ...[
                  const SizedBox(height: 10),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Ketuk kartu untuk lihat detail transaksi',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasAnyAction {
    return (showTrackAction && onTrack != null) ||
        (showCancelAction && onCancel != null) ||
        (showReorderAction && onReorder != null);
  }

  int get _actionCount {
    var count = 0;
    if (showTrackAction && onTrack != null) count++;
    if (showCancelAction && onCancel != null) count++;
    if (showReorderAction && onReorder != null) count++;
    return count;
  }

  Widget _buildOrderMeta() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatCurrency(order.totalAmount),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatDateTime(order.createdAt),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          '${paymentMethodLabel(order.paymentMethod)} - ${paymentStatusLabel(order.paymentStatus)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons({
    required BuildContext context,
    bool compact = false,
    bool horizontal = false,
  }) {
    final buttons = <Widget>[];
    final buttonHeight = compact ? 40.0 : 44.0;
    final buttonTextStyle = GoogleFonts.poppins(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
    final trackTextStyle = buttonTextStyle.copyWith(color: AppColors.primary);
    final dangerTextStyle = buttonTextStyle.copyWith(color: AppColors.white);
    final neutralTextStyle = buttonTextStyle.copyWith(
      color: AppColors.textSecondary,
    );

    if (showTrackAction && onTrack != null) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: onTrack,
          icon: const Icon(Icons.location_on, size: 14),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Lacak',
              maxLines: 1,
              softWrap: false,
              style: trackTextStyle,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            minimumSize: Size(0, buttonHeight),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (showCancelAction && onCancel != null) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: isCancelling ? null : onCancel,
          icon: isCancelling
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : const Icon(Icons.close, size: 14),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              isCancelling ? 'Proses' : 'Batalkan',
              maxLines: 1,
              softWrap: false,
              style: dangerTextStyle,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.white,
            minimumSize: Size(0, buttonHeight),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (showReorderAction && onReorder != null) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: onReorder,
          icon: const Icon(Icons.refresh, size: 14),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Pesan Lagi',
              maxLines: 1,
              softWrap: false,
              style: neutralTextStyle,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.textSecondary),
            minimumSize: Size(0, buttonHeight),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (horizontal && buttons.length > 1) {
      return Row(
        children: [
          for (int i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: buttons[i]),
          ],
        ],
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: compact ? 120 : 150,
        maxWidth: compact ? 150 : 190,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            buttons[i],
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(Color statusColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(orderStatusIcon(order.statusCode), size: 12, color: statusColor),
          const SizedBox(width: 4),
          Text(
            order.statusLabel,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTypeChip(CustomerOrderSummaryModel order) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(serviceTypeIcon(order.serviceTypeCode), size: 14),
          const SizedBox(width: 6),
          Text(
            order.serviceTypeLabel,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
