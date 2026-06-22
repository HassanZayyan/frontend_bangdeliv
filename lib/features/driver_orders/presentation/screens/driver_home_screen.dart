import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../models/driver_order_model.dart';
import '../../../auth/application/auth_session_provider.dart';
import '../../../navigation/presentation/widgets/bang_floating_bottom_nav_bar.dart';
import '../../application/driver_order_providers.dart';
import '../../../../utils/order_formatters.dart';
import '../../../../utils/service_type.dart';

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOrder = ref.watch(driverActiveOrderProvider);
    final session = ref.watch(authSessionProvider);
    final stats = session.profile?.stats;
    final totalPaid = stats?.totalPaid ?? 0;
    final totalOrders = stats?.totalOrders ?? 0;
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(driverOrdersProvider);
          ref.invalidate(driverAvailabilityProvider);
          try {
            await Future.wait([
              ref.read(driverOrdersProvider.future),
              ref.read(driverAvailabilityProvider.future),
            ]);
          } catch (_) {
            // Provider states render errors independently.
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(
            16,
            14,
            16,
            BangFloatingBottomNavBar.scrollClearance,
          ),
          children: [
            _AvailabilityCard(
              status: availabilityStatus,
              isOnline: isOnline,
              isUpdating: isUpdatingAvailability,
              hasSyncIssue: hasAvailabilitySyncIssue,
              syncIssueMessage: availabilitySyncIssueMessage,
              onChanged: (value) => _setAvailability(context, ref, value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Pendapatan',
                    value: formatCurrency(totalPaid),
                    icon: Icons.payments_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'Order selesai',
                    value: totalOrders.toString(),
                    icon: Icons.task_alt_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ActiveOrderSection(
              activeOrder: activeOrder,
              onOpenDetail: activeOrder == null
                  ? null
                  : () => _openActiveOrder(context, activeOrder),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _setAvailability(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final error = await ref
        .read(driverAvailabilityProvider.notifier)
        .setOnline(value);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error ??
                (value
                    ? 'Status kerja diubah ke online.'
                    : 'Status kerja diubah ke offline.'),
          ),
          backgroundColor: error == null ? AppColors.success : AppColors.error,
        ),
      );
  }

  static void _openActiveOrder(BuildContext context, DriverOrderModel order) {
    if (!_isServerOrderId(order.id)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
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

    context.push(AppRoutes.driverOrderActivePath(order.id));
  }

  static bool _isServerOrderId(String orderId) {
    return RegExp(r'^\d+$').hasMatch(orderId.trim());
  }

  static Color availabilityColor(String status) {
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

  static String availabilityLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'available':
      case 'online':
        return 'Online';
      case 'busy':
        return 'Sedang mengantar';
      default:
        return 'Offline';
    }
  }

  static String? availabilityDescription(String status) {
    switch (status.trim().toLowerCase()) {
      case 'available':
      case 'online':
        return 'Siap menerima order masuk';
      case 'busy':
        return null;
      default:
        return 'Aktifkan untuk menerima order';
    }
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.status,
    required this.isOnline,
    required this.isUpdating,
    required this.hasSyncIssue,
    required this.syncIssueMessage,
    required this.onChanged,
  });

  final String status;
  final bool isOnline;
  final bool isUpdating;
  final bool hasSyncIssue;
  final String syncIssueMessage;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final statusColor = DriverHomeScreen.availabilityColor(status);
    final description = DriverHomeScreen.availabilityDescription(status);
    final supportingText = hasSyncIssue ? syncIssueMessage : description;

    return _DriverSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status kerja',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        DriverHomeScreen.availabilityLabel(status),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: AppTextScaling.adaptive(
                            context,
                            normal: 16,
                            large: 15,
                          ),
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ),
                    if (isUpdating) ...[
                      const SizedBox(width: 8),
                      const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                if ((supportingText ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    supportingText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasSyncIssue
                          ? AppColors.error
                          : AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: isOnline,
            onChanged: isUpdating ? null : onChanged,
            activeThumbColor: AppColors.success,
            inactiveThumbColor: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _DriverSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppTextScaling.adaptive(
                context,
                normal: 16,
                large: 14.5,
              ),
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveOrderSection extends StatelessWidget {
  const _ActiveOrderSection({this.activeOrder, this.onOpenDetail});

  final DriverOrderModel? activeOrder;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final order = activeOrder;
    if (order == null) {
      return _DriverSurface(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Order aktif'),
            const SizedBox(height: 12),
            const Text(
              'Belum ada order berjalan.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Order baru akan muncul di menu Orderan saat status kerja aktif.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go(AppRoutes.driverOrders),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Lihat Orderan'),
              ),
            ),
          ],
        ),
      );
    }

    return _DriverSurface(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.primary.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Order aktif',
            trailing: '#${order.id}',
            trailingColor: AppColors.primaryDark,
          ),
          const SizedBox(height: 10),
          _ServiceLabelPill(label: serviceTypeLabel(order.serviceTypeCode)),
          const SizedBox(height: 12),
          _RouteSummary(order: order),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onOpenDetail,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              child: const Text('Buka Detail Order'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.order});

  final DriverOrderModel order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _AddressLine(
            icon: Icons.radio_button_checked,
            color: AppColors.primary,
            text: order.pickupAddress,
            maxLines: 2,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 9),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(width: 1, height: 14, color: AppColors.border),
            ),
          ),
          _AddressLine(
            icon: Icons.location_on_rounded,
            color: const Color(0xFF2563EB),
            text: order.dropoffAddress,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _ServiceLabelPill extends StatelessWidget {
  const _ServiceLabelPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({
    required this.icon,
    required this.color,
    required this.text,
    required this.maxLines,
  });

  final IconData icon;
  final Color color;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.trailingColor = AppColors.textSecondary,
  });

  final String title;
  final String? trailing;
  final Color trailingColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          AppTextScaling.clampForCompactComponent(
            context: context,
            maxScaleFactor: AppTextScaling.denseComponentMaxScaleFactor,
            child: Text(
              trailing!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: trailingColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DriverSurface extends StatelessWidget {
  const _DriverSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
