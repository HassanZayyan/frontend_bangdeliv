import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/customer_order_model.dart';
import '../providers/customer_order_providers.dart';
import '../providers/customer_order_tracking_provider.dart';
import '../utils/order_formatters.dart';
import '../utils/order_status.dart';
import '../utils/order_ui_helpers.dart';
import '../utils/service_type.dart';
import '../widgets/tracking_map_section.dart';

class TrackOrderScreen extends ConsumerWidget {
  const TrackOrderScreen({super.key});

  bool _shouldShowTrackingMap(CustomerOrderSummaryModel order) {
    if (order.isTerminalStatus) {
      return false;
    }

    return isDriverLocationTrackable(order.statusCode) ||
        normalizeServiceTypeCode(order.serviceTypeCode) != ServiceTypeCodes.ride;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderId = _extractOrderId(GoRouterState.of(context).extra);

    if (orderId != null) {
      final trackingProvider = customerOrderTrackingProvider(orderId);
      final trackingAsync = ref.watch(trackingProvider);
      return _buildScaffold(
        context,
        trackingAsync,
        showEmptyForNoActiveOrder: false,
        onRetry: () => ref.invalidate(trackingProvider),
      );
    }

    final ordersAsync = ref.watch(customerOrdersProvider);

    return ordersAsync.when(
      loading: () => _buildScaffold(
        context,
        const AsyncLoading<CustomerOrderTrackingState>(),
        showEmptyForNoActiveOrder: false,
        onRetry: () => ref.invalidate(customerOrdersProvider),
      ),
      error: (error, stackTrace) => _buildScaffold(
        context,
        AsyncError<CustomerOrderTrackingState>(error, stackTrace),
        showEmptyForNoActiveOrder: false,
        onRetry: () => ref.invalidate(customerOrdersProvider),
      ),
      data: (_) {
        final activeOrder = ref.watch(customerActiveOrderProvider);
        if (activeOrder == null) {
          return _buildScaffold(
            context,
            const AsyncLoading<CustomerOrderTrackingState>(),
            showEmptyForNoActiveOrder: true,
            onRetry: () => ref.invalidate(customerOrdersProvider),
          );
        }

        final trackingProvider = customerOrderTrackingProvider(activeOrder.id);
        final trackingAsync = ref.watch(trackingProvider);
        return _buildScaffold(
          context,
          trackingAsync,
          showEmptyForNoActiveOrder: false,
          onRetry: () => ref.invalidate(trackingProvider),
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    AsyncValue<CustomerOrderTrackingState> trackingAsync, {
    required bool showEmptyForNoActiveOrder,
    required VoidCallback onRetry,
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
      ),
      body: showEmptyForNoActiveOrder
          ? _buildEmptyState(context)
          : trackingAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: onRetry,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
              data: _buildDetailView,
            ),
    );
  }

  int? _extractOrderId(dynamic extra) {
    if (extra is int) return extra;
    if (extra is String) return int.tryParse(extra);
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

  Widget _buildDetailView(CustomerOrderTrackingState tracking) {
    final detail = tracking.detail;
    final order = detail.summary;
    final shouldShowTrackingMap = _shouldShowTrackingMap(order);
    final isRide =
        normalizeServiceTypeCode(order.serviceTypeCode) == ServiceTypeCodes.ride;

    final driverLat = detail.driverLatitude;
    final driverLng = detail.driverLongitude;
    final driverUpdatedAt = detail.driverLocationUpdatedAt;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(
              child: shouldShowTrackingMap
                  ? TrackingMapSection(
                      dropoffAddress: order.deliveryAddress,
                      pickupLatitude: detail.pickupLatitude,
                      pickupLongitude: detail.pickupLongitude,
                      dropoffLatitude: detail.dropoffLatitude,
                      dropoffLongitude: detail.dropoffLongitude,
                      driverLatitude: driverLat,
                      driverLongitude: driverLng,
                      driverLocationUpdatedAt: driverUpdatedAt,
                      height: constraints.maxHeight,
                      borderRadius: 0,
                      showLegend: true,
                    )
                  : const ColoredBox(color: AppColors.background),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.35,
              minChildSize: 0.18,
              maxChildSize: 0.9,
              snap: true,
              snapSizes: const [0.35, 0.6, 0.9],
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (shouldShowTrackingMap &&
                          tracking.hasLiveDriverLocation)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle,
                                    size: 8, color: Colors.green),
                                SizedBox(width: 6),
                                Text(
                                  'LIVE: posisi driver diperbarui',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          children: [
                            _buildHeaderCard(order),
                            const SizedBox(height: 12),
                            _buildInfoCard(
                              title: 'Ringkasan Order',
                              children: [
                                _infoRow('Order', order.orderNumber),
                                _infoRow('Layanan', order.serviceTypeLabel),
                                _infoRow('Status', order.statusLabel),
                                _infoRow(
                                  'Total',
                                  formatCurrency(order.totalAmount),
                                ),
                                _infoRow(
                                  'ETA',
                                  _estimateArrivalText(
                                      order.estimatedDelivery),
                                ),
                                if ((detail.deliveryDistanceText ?? '')
                                    .trim()
                                    .isNotEmpty)
                                  _infoRow(
                                    'Jarak',
                                    detail.deliveryDistanceText!.trim(),
                                  ),
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
                                if (isRide && !shouldShowTrackingMap)
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      'Tracking peta tersedia saat driver aktif dalam perjalanan.',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                if (detail.timeline.isEmpty)
                                  const Text(
                                    'Belum ada update status.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                else
                                  for (final item in detail.timeline)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(
                                                top: 4),
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: orderStatusColor(item.code),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.label,
                                                  style: const TextStyle(
                                                    color:
                                                        AppColors.textPrimary,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                  ),
                                                ),
                                                Text(
                                                  formatDateTime(
                                                      item.changedAt),
                                                  style: const TextStyle(
                                                    color: AppColors
                                                        .textSecondary,
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
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
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
              color:
                  orderStatusColor(order.statusCode).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              serviceTypeLeadingIcon(order.serviceTypeCode),
              color: orderStatusColor(order.statusCode),
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
                    color: orderStatusColor(order.statusCode),
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
    if (estimatedDelivery == null) return '-';

    final diff = estimatedDelivery.toUtc().difference(DateTime.now().toUtc());
    if (diff.inMinutes <= 0) return 'Segera tiba';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lagi';

    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (minutes == 0) return '$hours jam lagi';
    return '$hours jam $minutes menit lagi';
  }

}
