import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../core/widgets/bang_async_state.dart';
import '../../../../models/driver_order_model.dart';
import '../../../navigation/presentation/widgets/bang_floating_bottom_nav_bar.dart';
import '../../application/driver_order_providers.dart';
import '../widgets/driver_distance_badge.dart';
import '../../../../utils/courier_package_formatter.dart';
import '../../../../utils/order_formatters.dart';
import '../../../../utils/service_type.dart';

class DriverOrdersScreen extends ConsumerWidget {
  const DriverOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersState = ref.watch(driverOrdersProvider);
    final availabilityState = ref.watch(driverAvailabilityProvider);
    final availabilityStatus =
        availabilityState.asData?.value.status ?? 'offline';
    final canReceiveIncomingOrders = _canReceiveIncomingOrders(
      availabilityStatus,
    );
    final activeOrder = ordersState.asData?.value.running.firstOrNull;
    if (activeOrder != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(AppRoutes.driverOrderActivePath(activeOrder.id));
        }
      });

      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Orderan Driver',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        automaticallyImplyLeading: false,
      ),
      body: ordersState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          return BangErrorState(
            message: error.toString(),
            onRetry: () {
              ref.read(driverOrdersProvider.notifier).refresh();
            },
          );
        },
        data: (data) {
          return _IncomingOrdersList(
            orders: data.incoming,
            processingOrderIds: data.processingOrderIds,
            canReceiveIncomingOrders: canReceiveIncomingOrders,
            availabilityStatus: availabilityStatus,
          );
        },
      ),
    );
  }

  bool _canReceiveIncomingOrders(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'available' || normalized == 'online';
  }
}

class _IncomingOrdersList extends ConsumerWidget {
  final List<DriverOrderModel> orders;
  final Set<String> processingOrderIds;
  final bool canReceiveIncomingOrders;
  final String availabilityStatus;

  const _IncomingOrdersList({
    required this.orders,
    required this.processingOrderIds,
    required this.canReceiveIncomingOrders,
    required this.availabilityStatus,
  });

  bool _isServerOrderId(String orderId) {
    return RegExp(r'^\d+$').hasMatch(orderId.trim());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      final normalizedStatus = availabilityStatus.trim().toLowerCase();
      final isBusy = normalizedStatus == 'busy';

      return _EmptyOrderState(
        icon: canReceiveIncomingOrders
            ? Icons.inbox_outlined
            : (isBusy ? Icons.delivery_dining : Icons.power_settings_new),
        title: canReceiveIncomingOrders
            ? 'Belum ada orderan masuk'
            : (isBusy ? 'Sedang menjalankan order' : 'Status kerja offline'),
        subtitle: canReceiveIncomingOrders
            ? 'Order baru akan tampil di sini saat driver sedang aktif.'
            : (isBusy
                  ? 'Selesaikan order berjalan sebelum menerima order baru.'
                  : 'Aktifkan status kerja untuk menerima order masuk.'),
        action: canReceiveIncomingOrders || isBusy
            ? null
            : FilledButton.icon(
                onPressed: () => context.go(AppRoutes.driverHome),
                icon: const Icon(Icons.toggle_on_outlined, size: 18),
                label: const Text('Atur Status Kerja'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(driverOrdersProvider.notifier).refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          BangFloatingBottomNavBar.scrollClearance,
        ),
        itemCount: orders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final order = orders[index];
          final isProcessing = processingOrderIds.contains(order.id);

          return _OrderCard(
            order: order,
            isProcessing: isProcessing,
            onAccept: isProcessing
                ? null
                : () async {
                    final result = await ref
                        .read(driverOrdersProvider.notifier)
                        .acceptOrder(order.id);

                    if (!context.mounted) {
                      return;
                    }

                    if (result.isSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order diterima.')),
                      );
                      final acceptedOrderId = result.order?.id ?? order.id;
                      if (_isServerOrderId(acceptedOrderId)) {
                        context.go(
                          AppRoutes.driverOrderActivePath(acceptedOrderId),
                        );
                      } else {
                        await ref.read(driverOrdersProvider.notifier).refresh();
                        final activeOrder = ref.read(driverActiveOrderProvider);
                        if (!context.mounted) {
                          return;
                        }
                        if (activeOrder != null &&
                            _isServerOrderId(activeOrder.id)) {
                          context.go(
                            AppRoutes.driverOrderActivePath(activeOrder.id),
                          );
                        }
                      }
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.error ?? 'Gagal menerima order.'),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  },
            onReject: isProcessing
                ? null
                : () async {
                    final error = await ref
                        .read(driverOrdersProvider.notifier)
                        .rejectOrder(order.id);

                    if (!context.mounted) {
                      return;
                    }

                    if (error == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order ditolak.')),
                      );
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  },
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final DriverOrderModel order;
  final bool isProcessing;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _OrderCard({
    required this.order,
    this.isProcessing = false,
    this.onAccept,
    this.onReject,
  });

  String get _displayOrderId {
    final number = order.orderNumber.trim();
    if (number.isNotEmpty) {
      return number.startsWith('#') ? number : '#$number';
    }
    return '#${order.id}';
  }

  String get _etaLabel {
    if (order.etaMinutes <= 0) {
      return 'Order baru';
    }
    return 'Estimasi ${order.etaMinutes} menit';
  }

  @override
  Widget build(BuildContext context) {
    final serviceLabel = serviceTypeLabel(order.serviceTypeCode);
    final packageDetails = buildCourierPackageDetails(order);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        _displayOrderId,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    _StatusPill(
                      label: _etaLabel,
                      background: AppColors.surfaceAlt,
                      foreground: AppColors.textSecondary,
                      icon: Icons.schedule_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _CustomerAvatar(name: order.customerName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${order.itemCount} item',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (order.serviceTypeCode.isNotEmpty ||
                    order.statusCode.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (order.serviceTypeCode.isNotEmpty)
                        _metaChip(
                          serviceLabel,
                          AppColors.surfaceAlt,
                          AppColors.textPrimary,
                        ),
                      if (order.statusCode.isNotEmpty)
                        _metaChip(
                          order.statusDisplayName ?? order.statusCode,
                          AppColors.surfaceAlt,
                          AppColors.success,
                        ),
                      DriverDistanceBadge(dispatch: order.dispatch),
                    ],
                  ),
                ],
                if (packageDetails.isCourier) ...[
                  const SizedBox(height: 12),
                  _CourierPackageSection(packageDetails: packageDetails),
                ],
                const SizedBox(height: 14),
                _OrderRouteSection(
                  pickupAddress: order.pickupAddress,
                  dropoffAddress: order.dropoffAddress,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Fee driver',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  formatCurrency(order.fee),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: isProcessing ? null : onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Text('Terima Order'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  final String name;

  const _CustomerAvatar({required this.name});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        _initials,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;

  const _StatusPill({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderRouteSection extends StatefulWidget {
  final String pickupAddress;
  final String dropoffAddress;

  const _OrderRouteSection({
    required this.pickupAddress,
    required this.dropoffAddress,
  });

  @override
  State<_OrderRouteSection> createState() => _OrderRouteSectionState();
}

class _OrderRouteSectionState extends State<_OrderRouteSection> {
  bool _expanded = false;

  static const int _collapsedMaxLines = 2;

  bool get _needsExpansion {
    return widget.pickupAddress.length > 80 ||
        widget.dropoffAddress.length > 80;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _routeStop(
            icon: Icons.radio_button_checked,
            iconColor: AppColors.primary,
            label: 'Jemput',
            address: widget.pickupAddress,
          ),
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
            label: 'Antar',
            address: widget.dropoffAddress,
          ),
          if (_needsExpansion) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                ),
                label: Text(
                  _expanded ? 'Tutup alamat' : 'Lihat alamat lengkap',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _routeStop({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
                maxLines: _expanded ? null : _collapsedMaxLines,
                overflow: _expanded ? null : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourierPackageSection extends StatelessWidget {
  final CourierPackageDetails packageDetails;

  const _CourierPackageSection({required this.packageDetails});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              const Text(
                'Detail Barang',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!packageDetails.hasDetails)
            const Text(
              'Detail barang belum tersedia.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          if (packageDetails.description.isNotEmpty)
            _courierInfoLine('Barang', packageDetails.description),
        ],
      ),
    );
  }

  Widget _courierInfoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrderState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _EmptyOrderState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
