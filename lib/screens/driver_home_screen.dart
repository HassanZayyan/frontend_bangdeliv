import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/driver_order_model.dart';
import '../providers/auth_session_provider.dart';
import '../providers/driver_order_providers.dart';
import '../utils/order_formatters.dart';

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersState = ref.watch(driverOrdersProvider);
    final DriverOrderModel? activeOrder = ref.watch(driverActiveOrderProvider);
    final session = ref.watch(authSessionProvider);
    final stats = session.profile?.stats;
    final totalPaid = stats?.totalPaid ?? 0;
    final totalOrders = stats?.totalOrders ?? 0;
    final rating = stats?.rating ?? 0;
    final isMockOrderData = ordersState.maybeWhen(
      data: (value) => value.isMockData,
      orElse: () => false,
    );
    final availabilityAsync = ref.watch(driverAvailabilityProvider);
    final availability = availabilityAsync.asData?.value;
    final availabilityStatus = availability?.status ?? 'offline';
    final isOnline = availability?.isOnline ?? false;
    final isUpdatingAvailability =
        (availability?.isUpdating ?? false) || availabilityAsync.isLoading;
    final hasAvailabilitySyncIssue =
        (availability?.hasSyncIssue ?? false) || availabilityAsync.hasError;
    final availabilitySyncIssueMessage =
        availability?.syncIssueMessage ?? 'Gagal sinkronkan status kerja.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Beranda Driver',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status Kerja',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _availabilityLabel(availabilityStatus),
                        style: TextStyle(
                          color: _availabilityColor(availabilityStatus),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (hasAvailabilitySyncIssue)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            availabilitySyncIssueMessage,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: isOnline,
                  onChanged: isUpdatingAvailability
                      ? null
                      : (value) async {
                          final error = await ref
                              .read(driverAvailabilityProvider.notifier)
                              .setOnline(value);

                          if (!context.mounted) {
                            return;
                          }

                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(error),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? 'Status kerja diubah ke online.'
                                    : 'Status kerja diubah ke offline.',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                  activeThumbColor: AppColors.success,
                  inactiveThumbColor: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  title: 'Total Pendapatan',
                  value: formatCurrency(totalPaid),
                  icon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  title: 'Total Order Selesai',
                  value: totalOrders.toString(),
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  title: 'Rating',
                  value: rating <= 0 ? '-' : '${rating.toStringAsFixed(1)}*',
                  icon: Icons.star_border,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ActiveOrderCard(
            activeOrder: activeOrder,
            isMockData: isMockOrderData,
            onOpenDetail: activeOrder == null
                ? null
                : () {
                    if (isMockOrderData || !_isServerOrderId(activeOrder.id)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Order ini berasal dari mode demo atau ID belum valid di server.',
                          ),
                          backgroundColor: AppColors.primaryDark,
                        ),
                      );
                      context.go(AppRoutes.driverOrders);
                      return;
                    }

                    context.push(
                      AppRoutes.driverOrderActivePath(activeOrder.id),
                    );
                  },
          ),
        ],
      ),
    );
  }

  static bool _isServerOrderId(String orderId) {
    return RegExp(r'^\d+$').hasMatch(orderId.trim());
  }

  static Color _availabilityColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'available':
      case 'online':
        return AppColors.success;
      case 'busy':
        return AppColors.primaryDark;
      default:
        return AppColors.textSecondary;
    }
  }

  static String _availabilityLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'available':
      case 'online':
        return 'Online - Siap Terima Order';
      case 'busy':
        return 'Sedang Mengantar';
      default:
        return 'Offline';
    }
  }
}

class _ActiveOrderCard extends StatelessWidget {
  final DriverOrderModel? activeOrder;
  final bool isMockData;
  final VoidCallback? onOpenDetail;

  const _ActiveOrderCard({
    this.activeOrder,
    required this.isMockData,
    this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    if (activeOrder == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 48,
              color: AppColors.textSecondary.withAlpha(128),
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum Ada Order Aktif',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Aktifkan status kerja untuk menerima order masuk.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go(AppRoutes.driverOrders),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Lihat Orderan Masuk'),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Order Aktif',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '#${activeOrder!.id}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (isMockData)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Data order sedang memakai mode demo.',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeOrder!.pickupAddress,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.navigation, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeOrder!.dropoffAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onOpenDetail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Buka Detail Order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
