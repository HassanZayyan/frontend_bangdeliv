import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../config/app_text_scaling.dart';
import '../models/customer_order_model.dart';
import '../utils/order_formatters.dart';
import '../utils/order_ui_helpers.dart';
import '../utils/service_type.dart';
import 'service_visual_icon.dart';

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
    this.showPaymentInfo = true,
    this.showInlinePrice = false,
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
  final bool showPaymentInfo;
  final bool showInlinePrice;

  @override
  Widget build(BuildContext context) {
    final statusColor = orderStatusColor(order.effectiveStatusCode);
    final serviceCode = normalizeServiceTypeCode(order.serviceTypeCode);
    final hideItemsSummary =
        serviceCode == 'RIDE' &&
        order.itemsSummary.trim().toLowerCase() == 'tanpa item';
    final titleFontSize = AppTextScaling.adaptive(
      context,
      normal: 14.5,
      large: 13.6,
    );
    final metaFontSize = AppTextScaling.adaptive(
      context,
      normal: 13,
      large: 12.4,
    );
    final showCardNavigationCue =
        showDetailHint && onTap != null && !showTrackAction;

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusChip(context, statusColor),
                    AppTextScaling.clampForCompactComponent(
                      context: context,
                      maxScaleFactor:
                          AppTextScaling.denseComponentMaxScaleFactor,
                      child: Text(
                        formatDateMonthTime(order.createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ServiceVisualIcon(
                      serviceCode: serviceCode,
                      width: 54,
                      height: 50,
                      frameSize: 42,
                      iconWidth: 58,
                      iconHeight: 46,
                      frameRadius: 10,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  order.restaurantName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: titleFontSize,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (showCardNavigationCue) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                          if (!hideItemsSummary) ...[
                            const SizedBox(height: 4),
                            Text(
                              order.itemsSummary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: metaFontSize,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (showInlinePrice) ...[
                      const SizedBox(width: 12),
                      Text(
                        formatCurrency(order.totalAmount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontSize: titleFontSize,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (!showInlinePrice) ...[
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
                            _buildOrderMeta(context),
                            const SizedBox(height: 10),
                            _buildActionButtons(
                              context: context,
                              horizontal: true,
                              compact: true,
                            ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildOrderMeta(context)),
                          if (_hasAnyAction) ...[
                            const SizedBox(width: 12),
                            _buildActionButtons(
                              context: context,
                              compact: true,
                            ),
                          ],
                        ],
                      );
                    },
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

  Widget _buildOrderMeta(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatCurrency(order.totalAmount),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        if (showPaymentInfo) ...[
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
      ],
    );
  }

  Widget _buildActionButtons({
    required BuildContext context,
    bool compact = false,
    bool horizontal = false,
  }) {
    final buttons = <Widget>[];
    final buttonHeight = AppTextScaling.adaptive(
      context,
      normal: compact ? 40.0 : 44.0,
      large: compact ? 44.0 : 48.0,
    );
    final trackButtonHeight = AppTextScaling.adaptive(
      context,
      normal: compact ? 34.0 : 38.0,
      large: compact ? 38.0 : 42.0,
    );
    final buttonFontSize = AppTextScaling.adaptive(
      context,
      normal: 15,
      large: 14,
    );
    final trackFontSize = AppTextScaling.adaptive(
      context,
      normal: 13,
      large: 12.5,
    );
    final buttonTextStyle = GoogleFonts.inter(
      fontSize: buttonFontSize,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
    final trackTextStyle = GoogleFonts.inter(
      color: AppColors.primary,
      fontSize: trackFontSize,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
    final dangerTextStyle = trackTextStyle.copyWith(color: AppColors.error);
    final neutralTextStyle = buttonTextStyle.copyWith(
      color: AppColors.textSecondary,
    );

    if (showTrackAction && onTrack != null) {
      buttons.add(
        OutlinedButton(
          onPressed: onTrack,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            minimumSize: Size(0, trackButtonHeight),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Lacak',
              maxLines: 1,
              softWrap: false,
              style: trackTextStyle,
            ),
          ),
        ),
      );
    }

    if (showCancelAction && onCancel != null) {
      buttons.add(
        OutlinedButton(
          onPressed: isCancelling ? null : onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            disabledForegroundColor: AppColors.textMuted,
            side: BorderSide(
              color: isCancelling
                  ? AppColors.border
                  : AppColors.error.withValues(alpha: 0.55),
            ),
            minimumSize: Size(0, buttonHeight),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: isCancelling
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.error,
                  ),
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Batalkan',
                    maxLines: 1,
                    softWrap: false,
                    style: dangerTextStyle,
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
              borderRadius: BorderRadius.circular(10),
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

    if (horizontal && buttons.length == 1) {
      return SizedBox(width: double.infinity, child: buttons.first);
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: buttons.length == 1 && showTrackAction
            ? compact
                  ? 86
                  : 108
            : compact
            ? 120
            : 150,
        maxWidth: buttons.length == 1 && showTrackAction
            ? compact
                  ? 108
                  : 130
            : compact
            ? 150
            : 190,
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

  Widget _buildStatusChip(BuildContext context, Color statusColor) {
    return AppTextScaling.clampForCompactComponent(
      context: context,
      maxScaleFactor: AppTextScaling.denseComponentMaxScaleFactor,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              order.effectiveStatusLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: statusColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
