import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/customer_order_model.dart';
import '../utils/order_formatters.dart';
import '../utils/order_ui_helpers.dart';
import '../utils/service_type.dart';

class CustomerOrderCard extends StatelessWidget {
  const CustomerOrderCard({
    super.key,
    required this.order,
    this.onTrack,
    this.onCancel,
    this.onReorder,
    this.isCancelling = false,
    this.showTrackAction = false,
    this.showCancelAction = false,
    this.showReorderAction = false,
  });

  final CustomerOrderSummaryModel order;
  final VoidCallback? onTrack;
  final VoidCallback? onCancel;
  final VoidCallback? onReorder;
  final bool isCancelling;
  final bool showTrackAction;
  final bool showCancelAction;
  final bool showReorderAction;

  @override
  Widget build(BuildContext context) {
    final statusColor = orderStatusColor(order.statusCode);
    final serviceCode = normalizeServiceTypeCode(order.serviceTypeCode);
    final hideItemsSummary =
        serviceCode == 'RIDE' &&
        order.itemsSummary.trim().toLowerCase() == 'tanpa item';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardYellow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatCurrency(order.totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDateTime(order.createdAt),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      if (showTrackAction && onTrack != null)
                        OutlinedButton.icon(
                          onPressed: onTrack,
                          icon: const Icon(Icons.location_on, size: 16),
                          label: const Text('Lacak'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      if (showCancelAction && onCancel != null)
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
                              : const Icon(Icons.close, size: 16),
                          label: Text(isCancelling ? 'Proses' : 'Batalkan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: AppColors.white,
                          ),
                        ),
                      if (showReorderAction && onReorder != null)
                        OutlinedButton.icon(
                          onPressed: onReorder,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Pesan Lagi'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(
                              color: AppColors.textSecondary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
        color: AppColors.white,
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
