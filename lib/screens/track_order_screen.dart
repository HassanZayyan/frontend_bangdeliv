import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/customer_order_model.dart';
import '../providers/customer_order_providers.dart';
import '../services/pusher_service.dart';
import '../utils/order_formatters.dart';
import '../utils/order_status.dart';
import '../utils/order_ui_helpers.dart';
import '../utils/service_type.dart';
import '../widgets/tracking_map_section.dart';

class TrackOrderScreen extends ConsumerStatefulWidget {
  const TrackOrderScreen({super.key});

  @override
  ConsumerState<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends ConsumerState<TrackOrderScreen> {
  // ── Real-time driver location (updated by Pusher) ─────────────────────────
  double? _driverLat;
  double? _driverLng;
  DateTime? _driverUpdatedAt;

  // ── Pusher subscription ───────────────────────────────────────────────────
  StreamSubscription<Map<String, dynamic>>? _trackingSub;
  int? _subscribedOrderId;
  int? _lastAppliedHistoryId;
  Timer? _statusRefreshDebounce;
  bool _allowDriverLocationUpdates = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _cancelPusher();
    _statusRefreshDebounce?.cancel();
    super.dispose();
  }

  void _cancelPusher() {
    _trackingSub?.cancel();
    _trackingSub = null;
    _subscribedOrderId = null;
  }

  void _scheduleOrderRefresh(int orderId, {int? historyId}) {
    if (historyId != null) {
      final lastApplied = _lastAppliedHistoryId;
      if (lastApplied != null && historyId <= lastApplied) {
        return;
      }
      _lastAppliedHistoryId = historyId;
    }

    _statusRefreshDebounce?.cancel();
    _statusRefreshDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.invalidate(customerOrderDetailProvider(orderId));
      ref.invalidate(customerOrdersProvider);
    });
  }

  /// Subscribe to Pusher when the order is still active and we haven't
  /// subscribed to this orderId.
  Future<void> _maybeSubscribePusher(
    CustomerOrderDetailModel detail,
  ) async {
    final orderId = detail.summary.id;

    final shouldTrack = !detail.summary.isTerminalStatus;
    _allowDriverLocationUpdates = _shouldShowTrackingMap(detail.summary);

    if (!shouldTrack) {
      if (_trackingSub != null) _cancelPusher();
      return;
    }

    if (_subscribedOrderId == orderId && _trackingSub != null) return;

    _cancelPusher();
    _subscribedOrderId = orderId;
    _lastAppliedHistoryId = null;

    try {
      await PusherService.instance.connect();

      _trackingSub = PusherService.instance.subscribeOrderTracking(
        orderId,
        onLocation: (lat, lng, heading, updatedAt) {
          if (!mounted) return;
          if (!_allowDriverLocationUpdates) return;
          setState(() {
            _driverLat = lat;
            _driverLng = lng;
            _driverUpdatedAt = updatedAt;
          });
        },
        onStatusChanged: (statusCode, previousStatusCode, historyId, changedAt) {
          _scheduleOrderRefresh(orderId, historyId: historyId);
        },
      );
    } catch (_) {
      // Pusher connection failed — silently degrade
    }
  }

  bool _shouldShowTrackingMap(CustomerOrderSummaryModel order) {
    if (normalizeServiceTypeCode(order.serviceTypeCode) != ServiceTypeCodes.ride) {
      return true;
    }

    final statusCode = normalizeOrderStatusCode(order.statusCode);
    return statusCode == OrderStatusCodes.driverAssigned;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final orderId = _extractOrderId(GoRouterState.of(context).extra);

    if (orderId != null) {
      final detailProvider = customerOrderDetailProvider(orderId);
      ref.listen<AsyncValue<CustomerOrderDetailModel>>(detailProvider, (
        previous,
        next,
      ) {
        next.whenData(_maybeSubscribePusher);
      });

      final detailAsync = ref.watch(detailProvider);
      return _buildScaffold(
        context,
        detailAsync,
        showEmptyForNoActiveOrder: false,
        orderId: orderId,
      );
    }

    final ordersAsync = ref.watch(customerOrdersProvider);

    return ordersAsync.when(
      loading: () => _buildScaffold(
        context,
        const AsyncLoading<CustomerOrderDetailModel>(),
        showEmptyForNoActiveOrder: false,
      ),
      error: (error, stackTrace) => _buildScaffold(
        context,
        AsyncError<CustomerOrderDetailModel>(error, stackTrace),
        showEmptyForNoActiveOrder: false,
      ),
      data: (_) {
        final activeOrder = ref.watch(customerActiveOrderProvider);
        if (activeOrder == null) {
          _cancelPusher();
          return _buildScaffold(
            context,
            const AsyncLoading<CustomerOrderDetailModel>(),
            showEmptyForNoActiveOrder: true,
          );
        }

        final detailProvider = customerOrderDetailProvider(activeOrder.id);
        ref.listen<AsyncValue<CustomerOrderDetailModel>>(detailProvider, (
          previous,
          next,
        ) {
          next.whenData(_maybeSubscribePusher);
        });

        final detailAsync = ref.watch(detailProvider);
        return _buildScaffold(
          context,
          detailAsync,
          showEmptyForNoActiveOrder: false,
          orderId: activeOrder.id,
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
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

  Widget _buildDetailView(CustomerOrderDetailModel detail) {
    final order = detail.summary;
    final shouldShowTrackingMap = _shouldShowTrackingMap(order);
    final isRide =
        normalizeServiceTypeCode(order.serviceTypeCode) == ServiceTypeCodes.ride;

    // Prefer real-time coordinates when available; fallback to API snapshot.
    final driverLat = _driverLat ?? detail.driverLatitude;
    final driverLng = _driverLng ?? detail.driverLongitude;
    final driverUpdatedAt = _driverUpdatedAt ?? detail.driverLocationUpdatedAt;

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
                      // Live indicator badge
                      if (shouldShowTrackingMap && _driverLat != null)
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
                                      'Tracking peta hanya tersedia saat driver ditugaskan.',
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

    final diff = estimatedDelivery.toLocal().difference(DateTime.now());
    if (diff.inMinutes <= 0) return 'Segera tiba';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lagi';

    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (minutes == 0) return '$hours jam lagi';
    return '$hours jam $minutes menit lagi';
  }

}
