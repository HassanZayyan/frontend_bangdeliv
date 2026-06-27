import '../../../models/driver_order_model.dart';

class DriverEarningsSummary {
  const DriverEarningsSummary({
    required this.completedCount,
    required this.netIncomeTotal,
  });

  final int completedCount;
  final int netIncomeTotal;

  static DriverEarningsSummary fromHistory(
    Iterable<DriverHistoryOrderModel> orders,
  ) {
    final completed = orders
        .where(isCompletedHistoryOrder)
        .toList(growable: false);

    return DriverEarningsSummary(
      completedCount: completed.length,
      netIncomeTotal: orders
          .where(isIncomeEligibleHistoryOrder)
          .fold<int>(0, (total, order) => total + order.netIncomeRounded),
    );
  }

  static bool isCompletedHistoryOrder(DriverHistoryOrderModel order) {
    return order.status.trim().toLowerCase() == 'selesai';
  }

  static bool isIncomeEligibleHistoryOrder(DriverHistoryOrderModel order) {
    return isCompletedHistoryOrder(order) ||
        order.statusCode == 'CANCELLED_WITH_FEE';
  }
}
