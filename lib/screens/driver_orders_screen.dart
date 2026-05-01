import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/driver_order_model.dart';
import '../providers/driver_order_providers.dart';
import '../utils/order_formatters.dart';

class DriverOrdersScreen extends ConsumerStatefulWidget {
  const DriverOrdersScreen({super.key});

  @override
  ConsumerState<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends ConsumerState<DriverOrdersScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      ref.read(driverOrdersProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(driverOrdersProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Orderan Driver',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: AppColors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Masuk'),
              Tab(text: 'Berjalan'),
            ],
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
            return Column(
              children: [
                Expanded(
                  child: TabBarView(
                    children: [
                      _IncomingOrdersTab(
                        orders: data.incoming,
                        processingOrderIds: data.processingOrderIds,
                      ),
                      _RunningOrdersTab(
                        orders: data.running,
                        isMockMode: data.isMockData,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IncomingOrdersTab extends ConsumerWidget {
  final List<DriverOrderModel> orders;
  final Set<String> processingOrderIds;

  const _IncomingOrdersTab({
    required this.orders,
    required this.processingOrderIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return const _EmptyOrderState(
        icon: Icons.inbox_outlined,
        title: 'Belum ada orderan masuk',
        subtitle: 'Order baru akan tampil di sini saat driver sedang aktif.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(driverOrdersProvider.notifier).refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
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
                    final error = await ref
                        .read(driverOrdersProvider.notifier)
                        .acceptOrder(order.id);

                    if (!context.mounted) {
                      return;
                    }

                    if (error == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order diterima.')),
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
  final bool isMockMode;

  const _RunningOrdersTab({required this.orders, this.isMockMode = false});

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
      onRefresh: () => ref.read(driverOrdersProvider.notifier).refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = orders[index];
          return _OrderCard(
            order: order,
            isIncoming: false,
            onNavigate: () {
              if (isMockMode || !_isServerOrderId(order.id)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Detail order tidak tersedia karena data masih mode demo.',
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                order.id,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isIncoming
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isIncoming
                      ? 'Accept ${order.etaMinutes} menit'
                      : 'Diterima ${formatBackendTimeText(order.acceptedAt)}',
                  style: TextStyle(
                    color: isIncoming
                        ? AppColors.primaryDark
                        : AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${order.customerName} • ${order.itemCount} item',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (order.serviceTypeCode.isNotEmpty ||
              order.statusCode.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (order.serviceTypeCode.isNotEmpty)
                  _metaChip(
                    order.serviceTypeCode.toUpperCase(),
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
          const SizedBox(height: 8),
          _addressLine(Icons.storefront_outlined, order.pickupAddress),
          const SizedBox(height: 6),
          _addressLine(Icons.location_on_outlined, order.dropoffAddress),
          const SizedBox(height: 10),
          Text(
            'Fee: ${formatCurrency(order.fee)}',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          if (isIncoming)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isProcessing ? null : onAccept,
                    child: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Text('Terima'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.navigation_outlined, size: 18),
                    label: const Text('Detail Proses'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onContact,
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: const Text('Hubungi'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _addressLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
      ],
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

class _EmptyOrderState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyOrderState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 30),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
