import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import 'order_status.dart';
import 'service_type.dart';

Color orderStatusColor(String code) {
  final normalizedCode = normalizeOrderStatusCode(code);
  if (normalizedCode == OrderStatusCodes.completed ||
      normalizedCode == OrderStatusCodes.delivered) {
    return AppColors.success;
  }

  if (isCancelledOrderStatus(code)) {
    return AppColors.error;
  }

  return AppColors.primary;
}

IconData orderStatusIcon(String code) {
  final normalizedCode = normalizeOrderStatusCode(code);
  if (normalizedCode == OrderStatusCodes.completed ||
      normalizedCode == OrderStatusCodes.delivered) {
    return Icons.check;
  }

  if (isCancelledOrderStatus(code)) {
    return Icons.close;
  }

  return Icons.two_wheeler_outlined;
}

IconData serviceTypeIcon(String code) {
  switch (normalizeServiceTypeCode(code)) {
    case ServiceTypeCodes.ride:
      return Icons.route;
    case ServiceTypeCodes.courier:
      return Icons.local_shipping_outlined;
    case ServiceTypeCodes.shopping:
      return Icons.shopping_bag_outlined;
    default:
      return Icons.widgets_outlined;
  }
}

IconData serviceTypeLeadingIcon(String code) {
  switch (normalizeServiceTypeCode(code)) {
    case ServiceTypeCodes.ride:
      return Icons.two_wheeler_outlined;
    case ServiceTypeCodes.courier:
      return Icons.local_shipping_outlined;
    case ServiceTypeCodes.shopping:
      return Icons.shopping_bag_outlined;
    default:
      return Icons.widgets_outlined;
  }
}

Color serviceTypeColor(String code) {
  switch (normalizeServiceTypeCode(code)) {
    case ServiceTypeCodes.ride:
      return Colors.blue.shade700;
    case ServiceTypeCodes.courier:
      return Colors.orange.shade700;
    case ServiceTypeCodes.shopping:
      return Colors.green.shade700;
    default:
      return AppColors.primary;
  }
}

bool isPaymentPaid(String? status) {
  return (status ?? '').trim().toLowerCase() == 'paid';
}

String paymentStatusLabel(String? status) {
  return isPaymentPaid(status) ? 'Sudah dibayar' : 'Belum dibayar';
}

String paymentMethodLabel(String? method) {
  final normalized = (method ?? 'COD').trim().toUpperCase();
  if (normalized == 'TRANSFER') {
    return 'QRIS';
  }

  return normalized.isEmpty ? 'COD' : normalized;
}
