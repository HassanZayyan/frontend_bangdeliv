import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final DriverOrderModel? activeOrder = ref.watch(driverActiveOrderProvider);
    final session = ref.watch(authSessionProvider);
    final stats = session.profile?.stats;
    final totalPaid = stats?.totalPaid ?? 0;
    final totalOrders = stats?.totalOrders ?? 0;
    final rating = stats?.rating ?? 0;
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _availabilityLabel(availabilityStatus),
                        style: TextStyle(
                          color: _availabilityColor(availabilityStatus),
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
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
            onOpenDetail: activeOrder == null
                ? null
                : () {
                    if (!_isServerOrderId(activeOrder.id)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'ID order dari server tidak valid. Refresh daftar order dan coba lagi.',
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
  final VoidCallback? onOpenDetail;

  const _ActiveOrderCard({this.activeOrder, this.onOpenDetail});

  @override
  Widget build(BuildContext context) {
    if (activeOrder == null) {
      return Container(
        padding: const EdgeInsets.all(24),
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
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  foregroundColor: AppColors.primaryDark,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
                onPressed: () => context.go(AppRoutes.driverOrders),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Lihat Orderan Masuk'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delivery_dining, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Order Aktif',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '#${activeOrder!.id}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.storefront_rounded, size: 14, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          activeOrder!.pickupAddress,
                          style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary, fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 11),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        children: List.generate(3, (index) => Container(
                          width: 2,
                          height: 3,
                          margin: const EdgeInsets.symmetric(vertical: 1.5),
                          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(1)),
                        )),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          activeOrder!.dropoffAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary, fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onOpenDetail,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
