import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/customer_order_model.dart';
import '../providers/customer_order_providers.dart';
import '../providers/customer_order_tracking_provider.dart';
import '../providers/order_chat_unread_provider.dart';
import '../utils/order_formatters.dart';
import '../utils/order_status.dart';
import '../utils/order_ui_helpers.dart';
import '../utils/service_type.dart';
import '../widgets/tracking_map_section.dart';

class TrackOrderScreen extends ConsumerWidget {
  const TrackOrderScreen({super.key});

  static const _kStepLabelsDefault = [
    'Menunggu',
    'Ditugaskan',
    'Diambil',
    'Perjalanan',
    'Tiba',
  ];

  static const _kStepLabelsRide = [
    'Menunggu',
    'Ditugaskan',
    'Naik',
    'Perjalanan',
    'Selesai',
  ];

  bool _shouldShowTrackingMap(CustomerOrderSummaryModel order) {
    if (order.isTerminalStatus) return false;
    return isDriverLocationTrackable(
          order.statusCode,
          statusLabel: order.statusLabel,
        ) ||
        normalizeServiceTypeCode(order.serviceTypeCode) != ServiceTypeCodes.ride;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeArgs = _extractRouteArgs(GoRouterState.of(context).extra);
    final orderId = routeArgs.orderId;

    if (orderId != null) {
      final trackingProvider = customerOrderTrackingProvider(orderId);
      final trackingAsync = ref.watch(trackingProvider);
      return _buildScaffold(
        context,
        trackingAsync,
        forceHistoryTitle: routeArgs.fromHistory,
        showEmptyForNoActiveOrder: false,
        onRetry: () => ref.invalidate(trackingProvider),
        onRefresh: () async {
          ref.invalidate(trackingProvider);
          try {
            await ref.read(trackingProvider.future);
          } catch (_) {
            // Errors are rendered by the provider state.
          }
        },
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
          onRefresh: () async {
            ref.invalidate(trackingProvider);
            try {
              await ref.read(trackingProvider.future);
            } catch (_) {
              // Errors are rendered by the provider state.
            }
          },
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    AsyncValue<CustomerOrderTrackingState> trackingAsync, {
    bool forceHistoryTitle = false,
    required bool showEmptyForNoActiveOrder,
    required VoidCallback onRetry,
    Future<void> Function()? onRefresh,
  }) {
    final isHistoryDetail =
        forceHistoryTitle ||
        (trackingAsync.asData?.value.detail.summary.isTerminalStatus ?? false);
    final appBarTitle = isHistoryDetail ? 'Detail Pesanan' : 'Lacak Pesanan';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                        onPressed: onRetry,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (tracking) => _buildDetailView(
                context,
                tracking,
                onRefresh: onRefresh,
              ),
            ),
    );
  }

  _TrackRouteArgs _extractRouteArgs(dynamic extra) {
    if (extra is int) {
      return _TrackRouteArgs(orderId: extra);
    }
    if (extra is String) {
      return _TrackRouteArgs(orderId: int.tryParse(extra));
    }
    if (extra is Map) {
      final map = Map<String, dynamic>.from(extra);
      final dynamic rawOrderId = map['orderId'] ?? map['order_id'] ?? map['id'];
      final orderId = rawOrderId is int
          ? rawOrderId
          : int.tryParse(rawOrderId?.toString() ?? '');
      final fromHistory = map['fromHistory'] == true;
      return _TrackRouteArgs(orderId: orderId, fromHistory: fromHistory);
    }
    return const _TrackRouteArgs();
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

  Widget _buildDetailView(
    BuildContext context,
    CustomerOrderTrackingState tracking, {
    Future<void> Function()? onRefresh,
  }) {
    final detail = tracking.detail;
    final order = detail.summary;
    final shouldShowMap = _shouldShowTrackingMap(order);
    final isWaitingDriver = _isWaitingDriverStatus(order);
    final isPassengerDropoff = _isPassengerDropoffStatus(order);
    final isDriverArrivedDestination = _isDriverArrivedDestinationStatus(order);
    final isRide =
        normalizeServiceTypeCode(order.serviceTypeCode) == ServiceTypeCodes.ride;
    final hasLiveDriver = tracking.hasLiveDriverLocation;
    final driverName = (detail.driverName ?? '').trim();
    final driverVehicleLabel = _driverVehicleLabel(detail);
    final driverVehiclePlate = _driverVehiclePlate(detail);

    if (!shouldShowMap) {
      return _buildFixedStatusLayout(
        context: context,
        order: order,
        detail: detail,
        hasLiveDriver: hasLiveDriver,
        infoMessage: _fixedStatusInfoMessage(order),
        onRefresh: onRefresh,
      );
    }

    if ((isWaitingDriver || isPassengerDropoff || isDriverArrivedDestination) &&
        !order.isTerminalStatus) {
      return _buildFixedStatusLayout(
        context: context,
        order: order,
        detail: detail,
        hasLiveDriver: hasLiveDriver,
        infoMessage: _fixedStatusInfoMessage(order),
        onRefresh: onRefresh,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(
              child: shouldShowMap
                  ? TrackingMapSection(
                      dropoffAddress: order.deliveryAddress,
                      pickupLatitude: detail.pickupLatitude,
                      pickupLongitude: detail.pickupLongitude,
                      dropoffLatitude: detail.dropoffLatitude,
                      dropoffLongitude: detail.dropoffLongitude,
                      driverLatitude: detail.driverLatitude,
                      driverLongitude: detail.driverLongitude,
                      driverLocationUpdatedAt: detail.driverLocationUpdatedAt,
                      height: constraints.maxHeight,
                      borderRadius: 0,
                      showLegend: true,
                      followDriver: true,
                    )
                  : const ColoredBox(color: AppColors.background),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.38,
              minChildSize: 0.20,
              maxChildSize: 0.92,
              snap: true,
              snapSizes: const [0.38, 0.62, 0.92],
              builder: (context, scrollController) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 24,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: onRefresh ?? () async {},
                          child: ListView(
                            controller: scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                            children: [
                              _buildStatusProgress(
                                order.statusCode,
                                statusLabel: order.statusLabel,
                                isTerminalStatus: order.isTerminalStatus,
                                isRide: isRide,
                              ),
                              const SizedBox(height: 12),
                              if (driverName.isNotEmpty) ...[
                                _buildDriverCard(
                                  driverName,
                                  orderId: order.id,
                                  vehicleLabel: driverVehicleLabel,
                                  vehiclePlate: driverVehiclePlate,
                                  onChat: () => context.push(
                                    AppRoutes.orderChatPath(order.id),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              _buildStatusHeader(
                                order: order,
                                hasLiveDriver: hasLiveDriver,
                                showEta: _shouldShowEta(order),
                              ),
                              const SizedBox(height: 12),
                              _buildAddressCard(order.deliveryAddress),
                              const SizedBox(height: 12),
                              _buildSummaryCard(
                                order,
                                detail,
                                showEta: _shouldShowEta(order),
                              ),
                              const SizedBox(height: 12),
                              _buildPaymentCard(order, detail),
                              const SizedBox(height: 12),
                              _buildTimelineCard(
                                detail.timeline,
                                isRide: isRide,
                                shouldShowMap: shouldShowMap,
                              ),
                            ],
                          ),
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

  Widget _buildFixedStatusLayout({
    required BuildContext context,
    required CustomerOrderSummaryModel order,
    required CustomerOrderDetailModel detail,
    required bool hasLiveDriver,
    required String infoMessage,
    Future<void> Function()? onRefresh,
  }) {
    final driverName = (detail.driverName ?? '').trim();
    final driverVehicleLabel = _driverVehicleLabel(detail);
    final driverVehiclePlate = _driverVehiclePlate(detail);

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: onRefresh ?? () async {},
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _buildStatusProgress(
                order.statusCode,
                statusLabel: order.statusLabel,
                isTerminalStatus: order.isTerminalStatus,
                isRide:
                    normalizeServiceTypeCode(order.serviceTypeCode) ==
                    ServiceTypeCodes.ride,
              ),
              const SizedBox(height: 12),
              if (driverName.isNotEmpty) ...[
                _buildDriverCard(
                  driverName,
                  orderId: order.id,
                  vehicleLabel: driverVehicleLabel,
                  vehiclePlate: driverVehiclePlate,
                  onChat: () => context.push(AppRoutes.orderChatPath(order.id)),
                ),
                const SizedBox(height: 12),
              ],
              _buildStatusHeader(
                order: order,
                hasLiveDriver: hasLiveDriver,
                showEta: _shouldShowEta(order),
              ),
              const SizedBox(height: 12),
              _buildAddressCard(order.deliveryAddress),
              const SizedBox(height: 12),
              _buildSummaryCard(
                order,
                detail,
                showEta: _shouldShowEta(order),
              ),
              const SizedBox(height: 12),
              _buildPaymentCard(order, detail),
              const SizedBox(height: 12),
              _buildCard(
                title: 'Info Tracking',
                icon: Icons.info_outline,
                child: Text(
                  infoMessage,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isWaitingDriverStatus(CustomerOrderSummaryModel order) {
    final normalizedCode = normalizeOrderStatusCode(order.statusCode);
    if (normalizedCode == OrderStatusCodes.pending) {
      return true;
    }

    final normalizedLabel = order.statusLabel.trim().toUpperCase();
    return normalizedLabel.contains('MENUNGGU') &&
        normalizedLabel.contains('DRIVER');
  }

  bool _isPassengerDropoffStatus(CustomerOrderSummaryModel order) {
    final normalizedCode = normalizeOrderStatusCode(order.statusCode);
    if (normalizedCode == OrderStatusCodes.delivered ||
        normalizedCode == OrderStatusCodes.completed) {
      return true;
    }

    final normalizedLabel = order.statusLabel.trim().toUpperCase();
    return (normalizedLabel.contains('PENUMPANG') &&
            normalizedLabel.contains('TURUN')) ||
        normalizedLabel.contains('SUDAH SAMPAI TUJUAN');
  }

  bool _isDriverArrivedDestinationStatus(CustomerOrderSummaryModel order) {
    final normalizedLabel = order.statusLabel.trim().toUpperCase();
    return normalizedLabel.contains('DRIVER') &&
        normalizedLabel.contains('TIBA') &&
        normalizedLabel.contains('TUJUAN');
  }

  String _fixedStatusInfoMessage(CustomerOrderSummaryModel order) {
    if (order.isTerminalStatus) {
      return 'Order sudah selesai, peta tracking tidak lagi ditampilkan.';
    }

    if (_isDriverArrivedDestinationStatus(order)) {
      return 'Driver sudah tiba di tujuan. Proses order akan segera diselesaikan.';
    }

    if (_isPassengerDropoffStatus(order)) {
      return 'Penumpang sudah tiba di tujuan. Proses order akan segera diselesaikan.';
    }

    return 'Peta tracking akan muncul otomatis setelah driver mulai menuju titik jemput.';
  }

  bool _shouldShowEta(CustomerOrderSummaryModel order) {
    if (order.isTerminalStatus ||
        _isPassengerDropoffStatus(order) ||
        _isDriverArrivedDestinationStatus(order)) {
      return false;
    }

    return order.estimatedDelivery != null;
  }

  // ---------------------------------------------------------------------------
  // Progress stepper (visible for non-terminal active statuses)
  // ---------------------------------------------------------------------------

  Widget _buildStatusProgress(
    String statusCode, {
    String? statusLabel,
    bool isTerminalStatus = false,
    bool isRide = false,
  }) {
    final stepLabels = isRide ? _kStepLabelsRide : _kStepLabelsDefault;
    final normalized = normalizeOrderStatusCode(statusCode);
    if (isTerminalStatus || isTerminalOrderStatus(normalized)) {
      return const SizedBox.shrink();
    }

    final currentIndex = resolveTrackingStepIndex(
      statusCode: statusCode,
      statusLabel: statusLabel,
    );
    final shouldCheckFinalStep = _shouldRenderFinalStepAsCompleted(
      statusCode: statusCode,
      statusLabel: statusLabel,
      currentIndex: currentIndex,
      totalSteps: stepLabels.length,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(stepLabels.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepIndex = (i - 1) ~/ 2;
            final isPastConnector = stepIndex < currentIndex;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: isPastConnector ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            );
          }

          final stepIndex = i ~/ 2;
          final isCurrentStep = stepIndex == currentIndex;
          final isPast = stepIndex < currentIndex ||
              (shouldCheckFinalStep && isCurrentStep);
          final isCurrent = isCurrentStep && !shouldCheckFinalStep;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isCurrent ? 22 : 18,
                height: isCurrent ? 22 : 18,
                decoration: BoxDecoration(
                  color: (isPast || isCurrent) ? AppColors.primary : AppColors.border,
                  shape: BoxShape.circle,
                  border: isCurrent
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          width: 4,
                        )
                      : null,
                ),
                child: Center(
                  child: isPast
                      ? const Icon(Icons.check, color: Colors.white, size: 10)
                      : isCurrent
                          ? Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                stepLabels[stepIndex],
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                  color: isCurrent
                      ? AppColors.primary
                      : isPast
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  bool _shouldRenderFinalStepAsCompleted({
    required String statusCode,
    String? statusLabel,
    required int currentIndex,
    required int totalSteps,
  }) {
    final normalizedCode = normalizeOrderStatusCode(statusCode);
    if (currentIndex != totalSteps - 1) {
      return false;
    }

    if (normalizedCode == OrderStatusCodes.delivered ||
        normalizedCode == OrderStatusCodes.completed) {
      return true;
    }

    final normalizedLabel = (statusLabel ?? '').trim().toUpperCase();
    return normalizedLabel.contains('SUDAH SAMPAI TUJUAN') ||
        (normalizedLabel.contains('PENUMPANG') &&
            normalizedLabel.contains('TURUN')) ||
        normalizedLabel.contains('SELESAI');
  }

  // ---------------------------------------------------------------------------
  // Status header card — order number, status badge, LIVE badge, ETA banner
  // ---------------------------------------------------------------------------

  Widget _buildStatusHeader({
    required CustomerOrderSummaryModel order,
    required bool hasLiveDriver,
    bool showEta = true,
  }) {
    final statusColor = orderStatusColor(order.statusCode);
    final hasEta = showEta && order.estimatedDelivery != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        serviceTypeLeadingIcon(order.serviceTypeCode),
                        color: statusColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 24,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            order.orderNumber,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildServiceTypeBadge(order.serviceTypeLabel),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatusBadge(
                      text: order.statusLabel,
                      color: statusColor,
                    ),
                    if (hasLiveDriver) _buildLiveBadge(),
                  ],
                ),
              ],
            ),
          ),
          if (hasEta)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                border: const Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Estimasi tiba: ${_estimateArrivalText(order.estimatedDelivery)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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

  Widget _buildStatusBadge({required String text, required Color color}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          height: 1.15,
        ),
      ),
    );
  }

  Widget _buildServiceTypeBadge(String text) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30, maxWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          height: 1.15,
        ),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.green,
              letterSpacing: 0.5,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInfoSection({
    String? vehicleLabel,
    String? vehiclePlate,
  }) {
    if (vehicleLabel == null && vehiclePlate == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (vehicleLabel != null)
          _buildVehicleInfoRow(
            label: 'Motor',
            value: vehicleLabel,
            icon: Icons.two_wheeler_outlined,
          ),
        if (vehicleLabel != null && vehiclePlate != null)
          const SizedBox(height: 6),
        if (vehiclePlate != null)
          _buildVehicleInfoRow(
            label: 'Plat',
            value: vehiclePlate,
            icon: Icons.confirmation_number_outlined,
          ),
      ],
    );
  }

  Widget _buildVehicleInfoRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Text(
          ': ',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Driver card — avatar inisial + nama driver
  // ---------------------------------------------------------------------------

  Widget _buildDriverCard(
    String driverName, {
    required int orderId,
    String? vehicleLabel,
    String? vehiclePlate,
    VoidCallback? onChat,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.18),
                      AppColors.primary.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    driverName[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Driver Anda',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      driverName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              if (onChat != null) ...[
                const SizedBox(width: 10),
                Consumer(
                  builder: (context, ref, _) {
                    final unreadCountAsync = ref.watch(
                      orderChatUnreadCountProvider(orderId),
                    );
                    final unreadCount = unreadCountAsync.asData?.value ?? 0;

                    return IconButton(
                      onPressed: onChat,
                      tooltip: 'Chat driver',
                      icon: _ChatBadgeIcon(unreadCount: unreadCount),
                      color: AppColors.primary,
                    );
                  },
                ),
              ],
            ],
          ),
          if (vehicleLabel != null || vehiclePlate != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            const SizedBox(height: 10),
            _buildVehicleInfoSection(
              vehicleLabel: vehicleLabel,
              vehiclePlate: vehiclePlate,
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Order summary card
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCard(
    CustomerOrderSummaryModel order,
    CustomerOrderDetailModel detail, {
    bool showEta = true,
  }) {
    final paymentMethod = _paymentMethodLabel(detail.paymentMethod);
    final paymentStatus = _paymentStatusLabel(detail.paymentStatus);
    final rows = <_InfoRow>[
      _InfoRow('No. Order', order.orderNumber),
      _InfoRow('Layanan', order.serviceTypeLabel),
      _InfoRow('Total', formatCurrency(order.totalAmount)),
      if (showEta && order.estimatedDelivery != null)
        _InfoRow('ETA', _estimateArrivalText(order.estimatedDelivery)),
      if ((detail.deliveryDistanceText ?? '').trim().isNotEmpty)
        _InfoRow('Jarak', detail.deliveryDistanceText!.trim()),
      _InfoRow('Pembayaran', '$paymentMethod - $paymentStatus'),
    ];

    return _buildCard(
      title: 'Ringkasan Order',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: List.generate(rows.length, (index) {
          final row = rows[index];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (index > 0)
                const Divider(height: 1, thickness: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Text(
                      row.label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      row.value,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPaymentCard(
    CustomerOrderSummaryModel order,
    CustomerOrderDetailModel detail,
  ) {
    final isPaid = _isPaymentPaid(detail.paymentStatus);
    final statusColor = isPaid ? AppColors.success : AppColors.primary;

    return _buildCard(
      title: 'Pembayaran COD',
      icon: Icons.payments_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _paymentChip(
                _paymentMethodLabel(detail.paymentMethod),
                statusColor,
              ),
              _paymentChip(
                _paymentStatusLabel(detail.paymentStatus),
                statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isPaid
                ? 'Pembayaran tunai sudah tercatat.'
                : 'Bayar tunai ke driver saat pesanan sampai.',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (!isPaid) ...[
            const SizedBox(height: 6),
            Text(
              'Nominal: ${formatCurrency(order.totalAmount)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  bool _isPaymentPaid(String? status) {
    return (status ?? '').trim().toLowerCase() == 'paid';
  }

  String _paymentStatusLabel(String? status) {
    return _isPaymentPaid(status) ? 'Sudah dibayar' : 'Belum dibayar';
  }

  String _paymentMethodLabel(String? method) {
    final normalized = (method ?? 'COD').trim().toUpperCase();
    return normalized.isEmpty ? 'COD' : normalized;
  }

  // ---------------------------------------------------------------------------
  // Address card
  // ---------------------------------------------------------------------------

  Widget _buildAddressCard(String address) {
    return _buildCard(
      title: 'Alamat Tujuan',
      icon: Icons.location_on_outlined,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.place_rounded, color: AppColors.error, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                address,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Timeline card — vertical stepper with connectors
  // ---------------------------------------------------------------------------

  Widget _buildTimelineCard(
    List<OrderStatusSnapshot> timeline, {
    required bool isRide,
    required bool shouldShowMap,
  }) {
    return _buildCard(
      title: 'Riwayat Status',
      icon: Icons.history_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRide && !shouldShowMap)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
              child: const Text(
                'Tracking peta tersedia saat driver aktif dalam perjalanan.',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
              ),
            ),
          if (timeline.isEmpty)
            const Text(
              'Belum ada update status.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            ...List.generate(timeline.length, (index) {
              final item = timeline[index];
              final isLast = index == timeline.length - 1;
              final dotColor = orderStatusColor(item.code);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: isLast ? 16 : 14,
                          height: isLast ? 16 : 14,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            boxShadow: isLast
                                ? [
                                    BoxShadow(
                                      color: dotColor.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: !isLast
                              ? const Icon(Icons.check, color: Colors.white, size: 8)
                              : null,
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 30,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: TextStyle(
                              color: isLast ? dotColor : AppColors.textPrimary,
                              fontWeight: isLast ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatDateTime(item.changedAt),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Generic section card with icon + title header
  // ---------------------------------------------------------------------------

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
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
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: AppColors.border),
          child,
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

  String? _driverVehicleLabel(CustomerOrderDetailModel detail) {
    final type = (detail.driverVehicleType ?? '').trim();
    final brand = (detail.driverVehicleBrand ?? '').trim();
    final model = (detail.driverVehicleModel ?? '').trim();

    final brandModel = [brand, model].where((part) => part.isNotEmpty).join(' ');
    if (brandModel.isNotEmpty) {
      return brandModel;
    }

    final typeBrand = [type, brand].where((part) => part.isNotEmpty).join(' ');
    if (typeBrand.isNotEmpty) {
      return typeBrand;
    }

    return type.isNotEmpty ? type : null;
  }

  String? _driverVehiclePlate(CustomerOrderDetailModel detail) {
    final plate = (detail.driverVehiclePlate ?? '').trim().toUpperCase();
    return plate.isEmpty ? null : plate;
  }
}

class _TrackRouteArgs {
  final int? orderId;
  final bool fromHistory;

  const _TrackRouteArgs({this.orderId, this.fromHistory = false});
}

class _InfoRow {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;
}

class _ChatBadgeIcon extends StatelessWidget {
  const _ChatBadgeIcon({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final label = unreadCount > 99 ? '99+' : unreadCount.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
        if (unreadCount > 0)
          Positioned(
            top: -5,
            right: -7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
