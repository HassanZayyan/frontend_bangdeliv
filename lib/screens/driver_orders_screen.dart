import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/driver_order_model.dart';
import '../providers/driver_order_providers.dart';
import '../utils/courier_package_formatter.dart';
import '../utils/order_formatters.dart';
import '../utils/service_type.dart';

class DriverOrdersScreen extends ConsumerStatefulWidget {
  const DriverOrdersScreen({super.key});

  @override
  ConsumerState<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends ConsumerState<DriverOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _didResolveInitialTab = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _goToRunningTab() {
    if (!_tabController.indexIsChanging && _tabController.index != 1) {
      _tabController.animateTo(1);
    }
  }

  void _syncInitialTab(DriverOrdersState data) {
    if (_didResolveInitialTab) {
      return;
    }

    _didResolveInitialTab = true;
    final targetIndex = data.running.isNotEmpty ? 1 : 0;
    if (_tabController.index != targetIndex) {
      _tabController.index = targetIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(driverOrdersProvider);
    final availabilityState = ref.watch(driverAvailabilityProvider);
    final availabilityStatus =
        availabilityState.asData?.value.status ?? 'offline';
    final canReceiveIncomingOrders = _canReceiveIncomingOrders(
      availabilityStatus,
    );

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
        bottom: ordersState.maybeWhen(
          data: (data) => _DriverOrdersTabBar(
            controller: _tabController,
            incomingCount: data.incoming.length,
            runningCount: data.running.length,
          ),
          orElse: () => _DriverOrdersTabBar(
            controller: _tabController,
            incomingCount: 0,
            runningCount: 0,
          ),
        ),
      ),
      body: ordersState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          return _ErrorState(
            message: error.toString(),
            onRetry: () {
              ref.read(driverOrdersProvider.notifier).refresh();
            },
          );
        },
        data: (data) {
          _syncInitialTab(data);
          return TabBarView(
            controller: _tabController,
            children: [
              _IncomingOrdersTab(
                orders: data.incoming,
                processingOrderIds: data.processingOrderIds,
                canReceiveIncomingOrders: canReceiveIncomingOrders,
                availabilityStatus: availabilityStatus,
                onAcceptSuccess: _goToRunningTab,
              ),
              _RunningOrdersTab(orders: data.running),
            ],
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

class _DriverOrdersTabBar extends StatelessWidget
    implements PreferredSizeWidget {
  final TabController controller;
  final int incomingCount;
  final int runningCount;

  const _DriverOrdersTabBar({
    required this.controller,
    required this.incomingCount,
    required this.runningCount,
  });

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.primary,
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      tabs: [
        _TabWithBadge(label: 'Masuk', count: incomingCount),
        _TabWithBadge(label: 'Berjalan', count: runningCount),
      ],
    );
  }
}

class _TabWithBadge extends StatelessWidget {
  final String label;
  final int count;

  const _TabWithBadge({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IncomingOrdersTab extends ConsumerWidget {
  final List<DriverOrderModel> orders;
  final Set<String> processingOrderIds;
  final bool canReceiveIncomingOrders;
  final String availabilityStatus;
  final VoidCallback onAcceptSuccess;

  const _IncomingOrdersTab({
    required this.orders,
    required this.processingOrderIds,
    required this.canReceiveIncomingOrders,
    required this.availabilityStatus,
    required this.onAcceptSuccess,
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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: orders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final order = orders[index];
          final isProcessing = processingOrderIds.contains(order.id);

          return _OrderCard(
            order: order,
            isIncoming: true,
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
                        onAcceptSuccess();
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

class _RunningOrdersTab extends ConsumerWidget {
  final List<DriverOrderModel> orders;

  const _RunningOrdersTab({required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return const _EmptyOrderState(
        icon: Icons.local_shipping_outlined,
        title: 'Belum ada order berjalan',
        subtitle: 'Order yang sudah diterima akan pindah ke tab ini.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(driverOrdersProvider.notifier).refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: orders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final order = orders[index];
          return _OrderCard(
            order: order,
            isIncoming: false,
            onNavigate: () {
              if (!_isServerOrderId(order.id)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'ID order dari server tidak valid. Refresh daftar order dan coba lagi.',
                    ),
                    backgroundColor: AppColors.primaryDark,
                  ),
                );
                return;
              }

              context.go(AppRoutes.driverOrderActivePath(order.id));
            },
            onContact: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    order.customerPhone == null ||
                            order.customerPhone!.trim().isEmpty
                        ? 'Nomor customer belum tersedia.'
                        : 'Hubungi customer: ${order.customerPhone}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  bool _isServerOrderId(String orderId) {
    return RegExp(r'^\d+$').hasMatch(orderId.trim());
  }
}

class _OrderCard extends StatelessWidget {
  final DriverOrderModel order;
  final bool isIncoming;
  final bool isProcessing;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onNavigate;
  final VoidCallback? onContact;

  const _OrderCard({
    required this.order,
    required this.isIncoming,
    this.isProcessing = false,
    this.onAccept,
    this.onReject,
    this.onNavigate,
    this.onContact,
  });

  String get _displayOrderId {
    final number = order.orderNumber.trim();
    if (number.isNotEmpty) {
      return number.startsWith('#') ? number : '#$number';
    }
    return '#${order.id}';
  }

  String get _etaLabel {
    if (!isIncoming) {
      return 'Diterima ${formatBackendTimeText(order.acceptedAt)}';
    }
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isIncoming
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border.withValues(alpha: 0.5),
          width: isIncoming ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isIncoming
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isIncoming) Container(height: 3, color: AppColors.primary),
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
                      background: isIncoming
                          ? AppColors.primaryLight
                          : AppColors.success.withValues(alpha: 0.12),
                      foreground: isIncoming
                          ? AppColors.primaryDark
                          : AppColors.success,
                      icon: isIncoming
                          ? Icons.schedule_rounded
                          : Icons.check_circle_outline_rounded,
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
                          AppColors.primary.withValues(alpha: 0.1),
                          AppColors.primaryDark,
                        ),
                      if (order.statusCode.isNotEmpty)
                        _metaChip(
                          order.statusDisplayName ?? order.statusCode,
                          AppColors.success.withValues(alpha: 0.12),
                          AppColors.success,
                        ),
                    ],
                  ),
                ],
                if (isIncoming && packageDetails.isCourier) ...[
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
              gradient: LinearGradient(
                colors: [
                  AppColors.cardYellow,
                  AppColors.primaryLight.withValues(alpha: 0.3),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 18,
                  color: AppColors.primaryDark.withValues(alpha: 0.9),
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
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: isIncoming
                ? Row(
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
                            textStyle: GoogleFonts.poppins(
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
                            elevation: 4,
                            shadowColor: AppColors.primary.withValues(
                              alpha: 0.4,
                            ),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: GoogleFonts.poppins(
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
                  )
                : Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onNavigate,
                          icon: const Icon(Icons.navigation_rounded, size: 18),
                          label: const Text('Rute'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onContact,
                          icon: const Icon(Icons.call_outlined, size: 18),
                          label: const Text('Hubungi'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryLight,
            AppColors.primary.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
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
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _routeStop(
            icon: Icons.storefront_rounded,
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
                  backgroundColor: AppColors.primary.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: iconColor),
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
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 16,
                color: AppColors.primaryDark.withValues(alpha: 0.9),
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
          if (packageDetails.sizeLine.isNotEmpty)
            _courierInfoLine('Ukuran', packageDetails.sizeLine),
          if (packageDetails.safetyLine.isNotEmpty)
            _courierInfoLine('Keamanan', packageDetails.safetyLine),
          if (packageDetails.packingNote.isNotEmpty)
            _courierInfoLine('Catatan', packageDetails.packingNote),
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

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Gagal memuat order',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
