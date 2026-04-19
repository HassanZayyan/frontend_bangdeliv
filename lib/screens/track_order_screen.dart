import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/customer_order_model.dart';
import '../providers/customer_order_providers.dart';

class TrackOrderScreen extends ConsumerWidget {
  const TrackOrderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderId = _extractOrderId(GoRouterState.of(context).extra);

    if (orderId != null) {
      final detailAsync = ref.watch(customerOrderDetailProvider(orderId));
      return _buildScaffold(
        context,
        ref,
        detailAsync,
        showEmptyForNoActiveOrder: false,
        orderId: orderId,
      );
    }

    final ordersAsync = ref.watch(customerOrdersProvider);

    return ordersAsync.when(
      loading: () => _buildScaffold(
        context,
        ref,
        const AsyncLoading<CustomerOrderDetailModel>(),
        showEmptyForNoActiveOrder: false,
      ),
      error: (error, stackTrace) => _buildScaffold(
        context,
        ref,
        AsyncError<CustomerOrderDetailModel>(error, stackTrace),
        showEmptyForNoActiveOrder: false,
      ),
      data: (_) {
        final activeOrder = ref.watch(customerActiveOrderProvider);
        if (activeOrder == null) {
          return _buildScaffold(
            context,
            ref,
            const AsyncLoading<CustomerOrderDetailModel>(),
            showEmptyForNoActiveOrder: true,
          );
        }

        final detailAsync = ref.watch(
          customerOrderDetailProvider(activeOrder.id),
        );
        return _buildScaffold(
          context,
          ref,
          detailAsync,
          showEmptyForNoActiveOrder: false,
          orderId: activeOrder.id,
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<CustomerOrderDetailModel> detailAsync, {
    required bool showEmptyForNoActiveOrder,
    int? orderId,
  }) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Lacak Pesanan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(customerOrdersProvider);
              if (orderId != null) {
                ref.invalidate(customerOrderDetailProvider(orderId));
              }
            },
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: showEmptyForNoActiveOrder
          ? _buildEmptyState(context)
          : detailAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          ref.invalidate(customerOrdersProvider);
                          if (orderId != null) {
                            ref.invalidate(
                              customerOrderDetailProvider(orderId),
                            );
                          }
                        },
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (detail) => _buildDetailView(detail),
            ),
    );
  }

  int? _extractOrderId(dynamic extra) {
    if (extra is int) {
      return extra;
    }

    if (extra is String) {
      return int.tryParse(extra);
    }

    return null;
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.map_outlined,
                size: 80,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Belum Ada Pesanan Aktif',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Saat ada order berjalan, detail tracking akan tampil di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Kembali ke Beranda'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailView(CustomerOrderDetailModel detail) {
    final order = detail.summary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(order),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Ringkasan Order',
            children: [
              _infoRow('Order', order.orderNumber),
              _infoRow('Layanan', order.serviceTypeLabel),
              _infoRow('Status', order.statusLabel),
              _infoRow('Total', _formatCurrency(order.totalAmount)),
              _infoRow('ETA', _estimateArrivalText(order.estimatedDelivery)),
              if ((detail.deliveryDistanceText ?? '').trim().isNotEmpty)
                _infoRow('Jarak', detail.deliveryDistanceText!.trim()),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Alamat Pengantaran',
            children: [
              Text(
                order.deliveryAddress,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Timeline Status',
            children: [
              if (detail.timeline.isEmpty)
                const Text(
                  'Belum ada update status.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                for (final item in detail.timeline)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _statusColor(item.code),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                _formatDateTime(item.changedAt),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
          if ((detail.driverName ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoCard(
              title: 'Driver',
              children: [
                Text(
                  detail.driverName!.trim(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if ((detail.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoCard(
              title: 'Catatan',
              children: [
                Text(
                  detail.notes!.trim(),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(CustomerOrderSummaryModel order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _statusColor(order.statusCode).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_shipping_outlined,
              color: _statusColor(order.statusCode),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.orderNumber,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.statusLabel,
                  style: TextStyle(
                    color: _statusColor(order.statusCode),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _estimateArrivalText(DateTime? estimatedDelivery) {
    if (estimatedDelivery == null) {
      return '-';
    }

    final diff = estimatedDelivery.toLocal().difference(DateTime.now());
    if (diff.inMinutes <= 0) {
      return 'Segera tiba';
    }

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} menit lagi';
    }

    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    if (minutes == 0) {
      return '$hours jam lagi';
    }

    return '$hours jam $minutes menit lagi';
  }

  Color _statusColor(String code) {
    switch (code.toUpperCase()) {
      case 'COMPLETED':
      case 'DELIVERED':
        return AppColors.success;
      case 'CANCELLED':
      case 'CANCELLED_WITH_FEE':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  String _formatCurrency(double value) {
    final whole = value.round().toString();
    final withDots = whole.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );

    return 'Rp $withDots';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }
}
