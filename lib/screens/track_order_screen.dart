import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/customer_order_model.dart';
import '../providers/api_providers.dart';
import '../providers/customer_order_providers.dart';
import '../providers/customer_order_tracking_provider.dart';
import '../providers/order_chat_unread_provider.dart';
import '../screens/shopping_add_item_screen.dart';
import '../utils/order_formatters.dart';
import '../utils/order_status.dart';
import '../utils/order_ui_helpers.dart';
import '../utils/service_type.dart';
import '../widgets/order_chat_badge_icon.dart';
import '../widgets/shopping_fee_breakdown.dart';
import '../widgets/tracking_map_section.dart';

String _normalizedPaymentMethod(
  CustomerOrderSummaryModel order,
  CustomerOrderDetailModel detail,
) {
  final detailMethod = (detail.paymentMethod ?? '').trim();
  if (detailMethod.isNotEmpty) {
    return detailMethod.toUpperCase();
  }

  final summaryMethod = (order.paymentMethod ?? '').trim();
  if (summaryMethod.isNotEmpty) {
    return summaryMethod.toUpperCase();
  }

  return 'COD';
}

class TrackOrderScreen extends ConsumerWidget {
  const TrackOrderScreen({super.key}) : initialOrderId = null;

  const TrackOrderScreen.route({super.key, required int orderId})
    : initialOrderId = orderId;

  final int? initialOrderId;

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
        normalizeServiceTypeCode(order.serviceTypeCode) !=
            ServiceTypeCodes.ride;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeArgs = initialOrderId != null
        ? _TrackRouteArgs(orderId: initialOrderId)
        : _extractRouteArgs(GoRouterState.of(context).extra);
    final orderId = routeArgs.orderId;

    if (orderId != null) {
      final trackingProvider = customerOrderTrackingProvider(orderId);
      final trackingAsync = ref.watch(trackingProvider);
      return _buildScaffold(
        context,
        ref,
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
        ref,
        const AsyncLoading<CustomerOrderTrackingState>(),
        showEmptyForNoActiveOrder: false,
        onRetry: () => ref.invalidate(customerOrdersProvider),
      ),
      error: (error, stackTrace) => _buildScaffold(
        context,
        ref,
        AsyncError<CustomerOrderTrackingState>(error, stackTrace),
        showEmptyForNoActiveOrder: false,
        onRetry: () => ref.invalidate(customerOrdersProvider),
      ),
      data: (_) {
        final activeOrder = ref.watch(customerActiveOrderProvider);
        if (activeOrder == null) {
          return _buildScaffold(
            context,
            ref,
            const AsyncLoading<CustomerOrderTrackingState>(),
            showEmptyForNoActiveOrder: true,
            onRetry: () => ref.invalidate(customerOrdersProvider),
          );
        }
        final trackingProvider = customerOrderTrackingProvider(activeOrder.id);
        final trackingAsync = ref.watch(trackingProvider);
        return _buildScaffold(
          context,
          ref,
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
    WidgetRef ref,
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
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
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
                ref,
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
    WidgetRef ref,
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
        normalizeServiceTypeCode(order.serviceTypeCode) ==
        ServiceTypeCodes.ride;
    final hasLiveDriver = tracking.hasLiveDriverLocation;
    final driverName = (detail.driverName ?? '').trim();
    final driverVehicleLabel = _driverVehicleLabel(detail);
    final driverVehiclePlate = _driverVehiclePlate(detail);

    if (!shouldShowMap) {
      return _buildFixedStatusLayout(
        context: context,
        order: order,
        detail: detail,
        ref: ref,
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
        ref: ref,
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
                      pickupStops: _shoppingPickupStops(detail),
                      encodedPolyline: detail.route?.encodedPolyline,
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
                              _buildActiveTrackingCard(
                                order: order,
                                hasLiveDriver: hasLiveDriver,
                                showEta: _shouldShowEta(order),
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
                              _buildRouteCard(detail),
                              const SizedBox(height: 12),
                              _buildOrderDetailsCard(
                                order,
                                detail,
                                showEta: _shouldShowEta(order),
                              ),
                              const SizedBox(height: 12),
                              if (detail.isShoppingOrder) ...[
                                _ShoppingOrderItemsCard(
                                  detail: detail,
                                  onChanged: onRefresh,
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (detail.proofs.isNotEmpty) ...[
                                _buildProofsCard(context, detail.proofs),
                                const SizedBox(height: 12),
                              ],
                              _buildPaymentCard(
                                context,
                                ref,
                                order,
                                detail,
                                onRefresh,
                              ),
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
    required WidgetRef ref,
    required CustomerOrderSummaryModel order,
    required CustomerOrderDetailModel detail,
    required bool hasLiveDriver,
    required String infoMessage,
    Future<void> Function()? onRefresh,
  }) {
    final driverName = (detail.driverName ?? '').trim();
    final driverVehicleLabel = _driverVehicleLabel(detail);
    final driverVehiclePlate = _driverVehiclePlate(detail);
    final isWaitingDriver = _isWaitingDriverStatus(order);

    if (isWaitingDriver && driverName.isEmpty && !order.isTerminalStatus) {
      return _buildWaitingDriverLayout(
        context: context,
        ref: ref,
        order: order,
        detail: detail,
        infoMessage: infoMessage,
        onRefresh: onRefresh,
      );
    }

    return ColoredBox(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: onRefresh ?? () async {},
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _buildActiveTrackingCard(
                order: order,
                hasLiveDriver: hasLiveDriver,
                showEta: _shouldShowEta(order),
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
              _buildRouteCard(detail),
              const SizedBox(height: 12),
              _buildOrderDetailsCard(
                order,
                detail,
                showEta: _shouldShowEta(order),
              ),
              const SizedBox(height: 12),
              if (detail.isShoppingOrder) ...[
                _ShoppingOrderItemsCard(detail: detail, onChanged: onRefresh),
                const SizedBox(height: 12),
              ],
              if (detail.proofs.isNotEmpty) ...[
                _buildProofsCard(context, detail.proofs),
                const SizedBox(height: 12),
              ],
              _buildPaymentCard(context, ref, order, detail, onRefresh),
              const SizedBox(height: 12),
              _buildCard(
                title: 'Info Tracking',
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

  Widget _buildWaitingDriverLayout({
    required BuildContext context,
    required WidgetRef ref,
    required CustomerOrderSummaryModel order,
    required CustomerOrderDetailModel detail,
    required String infoMessage,
    Future<void> Function()? onRefresh,
  }) {
    final isRide =
        normalizeServiceTypeCode(order.serviceTypeCode) ==
        ServiceTypeCodes.ride;

    return ColoredBox(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: onRefresh ?? () async {},
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              const _WaitingDriverHeroCard(),
              const SizedBox(height: 12),
              _buildStatusProgress(
                order.statusCode,
                statusLabel: order.statusLabel,
                isTerminalStatus: order.isTerminalStatus,
                isRide: isRide,
              ),
              const SizedBox(height: 12),
              _buildTrackingInfoBanner(infoMessage),
              const SizedBox(height: 12),
              _buildRouteCard(detail),
              const SizedBox(height: 12),
              _buildOrderDetailsCard(order, detail),
              const SizedBox(height: 12),
              if (detail.isShoppingOrder) ...[
                _ShoppingOrderItemsCard(detail: detail, onChanged: onRefresh),
                const SizedBox(height: 12),
              ],
              if (detail.proofs.isNotEmpty) ...[
                _buildProofsCard(context, detail.proofs),
                const SizedBox(height: 12),
              ],
              _buildPaymentCard(context, ref, order, detail, onRefresh),
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

  List<TrackingMapPickupPoint> _shoppingPickupStops(
    CustomerOrderDetailModel detail,
  ) {
    if (!detail.isShoppingOrder) {
      return const <TrackingMapPickupPoint>[];
    }

    final stops = detail.shoppingStops
        .where((stop) => stop.isActive)
        .where(
          (stop) =>
              stop.merchant.latitude != null && stop.merchant.longitude != null,
        )
        .toList(growable: false);
    stops.sort((a, b) {
      final orderedIds =
          detail.route?.orderedPickupLocationIds ?? const <int>[];
      final aIndex = orderedIds.indexOf(a.pickupLocationId);
      final bIndex = orderedIds.indexOf(b.pickupLocationId);
      if (aIndex >= 0 || bIndex >= 0) {
        return (aIndex < 0 ? 1 << 20 : aIndex).compareTo(
          bIndex < 0 ? 1 << 20 : bIndex,
        );
      }
      return a.sequenceNo.compareTo(b.sequenceNo);
    });

    return stops
        .map(
          (stop) => TrackingMapPickupPoint(
            id: stop.pickupLocationId.toString(),
            label:
                'Merchant ${stop.sequenceNo <= 0 ? 1 : stop.sequenceNo}: ${stop.merchant.name}',
            latitude: stop.merchant.latitude!,
            longitude: stop.merchant.longitude!,
          ),
        )
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Progress stepper (visible for non-terminal active statuses)
  // ---------------------------------------------------------------------------

  Widget _buildStatusProgress(
    String statusCode, {
    String? statusLabel,
    bool isTerminalStatus = false,
    bool isRide = false,
    bool embedded = false,
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

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(stepLabels.length, (stepIndex) {
        final isFirst = stepIndex == 0;
        final isLast = stepIndex == stepLabels.length - 1;
        final isCurrentStep = stepIndex == currentIndex;
        final isPast =
            stepIndex < currentIndex || (shouldCheckFinalStep && isCurrentStep);
        final isCurrent = isCurrentStep && !shouldCheckFinalStep;

        final leftLineColor = (stepIndex <= currentIndex)
            ? AppColors.primary
            : AppColors.border;

        final rightLineColor = (stepIndex < currentIndex)
            ? AppColors.primary
            : AppColors.border;

        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 22,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 2,
                            color: isFirst ? Colors.transparent : leftLineColor,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: isLast ? Colors.transparent : rightLineColor,
                          ),
                        ),
                      ],
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: isCurrent ? 22 : 18,
                      height: isCurrent ? 22 : 18,
                      decoration: BoxDecoration(
                        color: (isPast || isCurrent)
                            ? AppColors.primary
                            : AppColors.border,
                        shape: BoxShape.circle,
                        border: isCurrent
                            ? Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: 0.25,
                                ),
                                width: 4,
                              )
                            : null,
                      ),
                      child: Center(
                        child: isPast
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 10,
                              )
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
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                stepLabels[stepIndex],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.visible,
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
          ),
        );
      }),
    );

    if (embedded) {
      return content;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
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
      child: content,
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
  // Active tracking card: order number, status badge, ETA, and progress
  // ---------------------------------------------------------------------------

  Widget _buildActiveTrackingCard({
    required CustomerOrderSummaryModel order,
    required bool hasLiveDriver,
    bool showEta = true,
    bool isRide = false,
  }) {
    final hasEta = showEta && order.estimatedDelivery != null;
    final statusTitle = _detailStatusTitle(order);
    final showProgress =
        !order.isTerminalStatus &&
        !isTerminalOrderStatus(normalizeOrderStatusCode(order.statusCode));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildServiceTypeBadge(
                order.serviceTypeLabel,
                icon: serviceTypeLeadingIcon(order.serviceTypeCode),
              ),
              if (hasLiveDriver) _buildLiveBadge(),
            ],
          ),
          if (statusTitle.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              statusTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
          ],
          if (hasEta) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: GoogleFonts.nunitoSans(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                        children: [
                          const TextSpan(text: 'Estimasi tiba: '),
                          TextSpan(
                            text: _estimateArrivalText(order.estimatedDelivery),
                            style: GoogleFonts.nunitoSans(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (showProgress) ...[
            const SizedBox(height: 16),
            _buildStatusProgress(
              order.statusCode,
              statusLabel: order.statusLabel,
              isTerminalStatus: order.isTerminalStatus,
              isRide: isRide,
              embedded: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceTypeBadge(String text, {IconData? icon}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
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

  String? _driverVehicleSubtitle({String? vehicleLabel, String? vehiclePlate}) {
    final parts = [
      vehicleLabel,
      vehiclePlate,
    ].where((part) => part != null && part.trim().isNotEmpty);
    final subtitle = parts.map((part) => part!.trim()).join(' - ');
    return subtitle.isEmpty ? null : subtitle;
  }

  // ---------------------------------------------------------------------------
  // Driver card: avatar inisial + nama driver
  // ---------------------------------------------------------------------------

  Widget _buildDriverCard(
    String driverName, {
    required int orderId,
    String? vehicleLabel,
    String? vehiclePlate,
    VoidCallback? onChat,
  }) {
    final vehicleSubtitle = _driverVehicleSubtitle(
      vehicleLabel: vehicleLabel,
      vehiclePlate: vehiclePlate,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Center(
              child: Text(
                _driverInitials(driverName),
                style: GoogleFonts.nunitoSans(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    height: 1.15,
                  ),
                ),
                if (vehicleSubtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    vehicleSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
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
                  icon: OrderChatBadgeIcon(unreadCount: unreadCount),
                  color: AppColors.primary,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _detailStatusTitle(CustomerOrderSummaryModel order) {
    final normalizedCode = normalizeOrderStatusCode(order.statusCode);
    final label = order.statusLabel.trim();
    final normalizedLabel = label.toUpperCase();

    if (normalizedCode == OrderStatusCodes.completed ||
        normalizedCode == OrderStatusCodes.delivered ||
        normalizedLabel == 'SELESAI') {
      return 'Pesanan selesai';
    }

    return label;
  }

  String _driverInitials(String driverName) {
    final parts = driverName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return '${parts.first.characters.first}${parts[1].characters.first}'
        .toUpperCase();
  }

  // ---------------------------------------------------------------------------
  // Order summary card
  // ---------------------------------------------------------------------------

  Widget _buildOrderDetailsCard(
    CustomerOrderSummaryModel order,
    CustomerOrderDetailModel detail, {
    bool showEta = false,
  }) {
    final deliveryFeeNotice = _deliveryFeeNotice(order, detail);
    final serviceCode = normalizeServiceTypeCode(order.serviceTypeCode);
    final isShopping = serviceCode == ServiceTypeCodes.shopping;
    final normalizedPaymentMethod = _normalizedPaymentMethod(order, detail);
    final paymentMethod = paymentMethodLabel(normalizedPaymentMethod);
    final paymentStatus = paymentStatusLabel(detail.paymentStatus);
    final isPaid = isPaymentPaid(detail.paymentStatus);
    final summaryPaymentMessage = _paymentMessage(
      order,
      detail,
      isPaid: isPaid,
    );
    final rows = <_InfoRow>[
      _InfoRow('No. Order', order.orderNumber),
      _InfoRow('Layanan', order.serviceTypeLabel),
      if (serviceCode == ServiceTypeCodes.courier &&
          order.itemsSummary.trim().isNotEmpty &&
          order.itemsSummary.trim().toLowerCase() != 'tanpa item')
        _InfoRow('Barang', order.itemsSummary.trim()),
      if (showEta && order.estimatedDelivery != null)
        _InfoRow('ETA', _estimateArrivalText(order.estimatedDelivery)),
      if ((detail.deliveryDistanceText ?? '').trim().isNotEmpty)
        _InfoRow('Jarak', detail.deliveryDistanceText!.trim()),
      _InfoRow('Pembayaran', '$paymentMethod - $paymentStatus'),
    ];

    return _buildCard(
      title: 'Detail Order',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(rows.length, (index) {
            final row = rows[index];
            return _summaryRow(row);
          }),
          if (!isShopping) ...[
            const Divider(height: 18, thickness: 1, color: AppColors.border),
            _summaryRow(
              _InfoRow(
                'Total',
                formatCurrency(order.totalAmount),
                emphasized: true,
              ),
            ),
            if (summaryPaymentMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                summaryPaymentMessage,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
          if (deliveryFeeNotice != null) ...[
            const SizedBox(height: 12),
            _DeliveryFeeNotice(text: deliveryFeeNotice),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(_InfoRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              row.value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: row.emphasized ? FontWeight.w800 : FontWeight.w600,
                fontSize: row.emphasized ? 15.5 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _deliveryFeeNotice(
    CustomerOrderSummaryModel order,
    CustomerOrderDetailModel detail,
  ) {
    final deliveryFeeSource =
        (detail.deliveryFeeSource ?? order.deliveryFeeSource ?? '')
            .trim()
            .toLowerCase();
    if (deliveryFeeSource != 'driver_manual') {
      return null;
    }

    final deliveryFee = detail.summary.deliveryFee ?? order.deliveryFee;
    if (deliveryFee == null || deliveryFee <= 0) {
      return null;
    }

    final reason =
        (detail.deliveryFeeChangeNote ?? order.deliveryFeeChangeNote ?? '')
            .trim();

    if (reason.isEmpty) {
      return 'Ongkir diperbarui driver menjadi ${formatCurrency(deliveryFee)}.';
    }

    return 'Ongkir diperbarui driver menjadi ${formatCurrency(deliveryFee)}. Alasan: $reason.';
  }

  String _paymentMessage(
    CustomerOrderSummaryModel order,
    CustomerOrderDetailModel detail, {
    required bool isPaid,
  }) {
    final isCourier =
        normalizeServiceTypeCode(order.serviceTypeCode) ==
        ServiceTypeCodes.courier;
    final isCancelledWithFee =
        normalizeOrderStatusCode(order.statusCode) ==
        OrderStatusCodes.cancelledWithFee;
    final isTransfer = _normalizedPaymentMethod(order, detail) == 'TRANSFER';

    if (isCancelledWithFee) {
      return isPaid
          ? 'Penalty merchant gagal sudah tercatat.'
          : 'Bayar penalty merchant gagal sesuai nominal.';
    }

    if (isTransfer) {
      return '';
    }

    if (isCourier) {
      return isPaid
          ? 'Pembayaran pickup sudah tercatat.'
          : 'Bayar tunai ke driver saat menyerahkan barang di titik ambil.';
    }

    return isPaid
        ? 'Pembayaran tunai sudah tercatat.'
        : 'Bayar tunai ke driver saat pesanan sampai.';
  }

  Widget _buildProofsCard(
    BuildContext context,
    List<CustomerOrderProofModel> proofs,
  ) {
    final visibleProofs = proofs
        .where((proof) => (proof.photoUrl ?? '').trim().isNotEmpty)
        .toList(growable: false);
    if (visibleProofs.isEmpty) {
      return const SizedBox.shrink();
    }
    final hasPendingTransferProof = visibleProofs.any(
      (proof) =>
          proof.type == 'payment_transfer' &&
          (proof.status ?? '').trim().toLowerCase() == 'pending',
    );

    return _buildCard(
      title: 'Bukti Foto',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: visibleProofs
                .map(
                  (proof) => InkWell(
                    onTap: () => _showProofPreview(context, proof),
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 104,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              proof.photoUrl!,
                              width: 104,
                              height: 84,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 104,
                                height: 84,
                                color: AppColors.background,
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            proof.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          if (hasPendingTransferProof) ...[
            const SizedBox(height: 12),
            const Text(
              'Bukti transfer menunggu verifikasi driver/admin.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showProofPreview(BuildContext context, CustomerOrderProofModel proof) {
    final url = proof.photoUrl;
    if (url == null || url.isEmpty) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Gambar bukti belum bisa dimuat.'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(
    BuildContext context,
    WidgetRef ref,
    CustomerOrderSummaryModel order,
    CustomerOrderDetailModel detail,
    Future<void> Function()? onRefresh,
  ) {
    final isPaid = isPaymentPaid(detail.paymentStatus);
    final statusColor = isPaid ? AppColors.success : AppColors.primary;
    final normalizedPaymentMethod = _normalizedPaymentMethod(order, detail);
    final isTransfer = normalizedPaymentMethod == 'TRANSFER';
    final isCourier =
        normalizeServiceTypeCode(order.serviceTypeCode) ==
        ServiceTypeCodes.courier;
    final isCancelledWithFee =
        normalizeOrderStatusCode(order.statusCode) ==
        OrderStatusCodes.cancelledWithFee;
    final hasPendingTransferProof = detail.proofs.any(
      (proof) =>
          proof.type == 'payment_transfer' &&
          (proof.status ?? '').trim().toLowerCase() == 'pending',
    );
    final paymentMessage = _paymentActionMessage(
      order: order,
      isPaid: isPaid,
      isTransfer: isTransfer,
      isCourier: isCourier,
      isCancelledWithFee: isCancelledWithFee,
      hasPendingTransferProof: hasPendingTransferProof,
    );

    return _buildCard(
      title: 'Pembayaran',
      icon: Icons.payments_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _paymentChip(
                paymentMethodLabel(normalizedPaymentMethod),
                statusColor,
              ),
              _paymentChip(
                paymentStatusLabel(detail.paymentStatus),
                statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            paymentMessage,
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
            const SizedBox(height: 12),
            if (isTransfer || isCancelledWithFee)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _uploadTransferEvidence(
                    context,
                    ref,
                    order.id,
                    onRefresh,
                  ),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Upload Bukti Transfer'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackingInfoBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _paymentActionMessage({
    required CustomerOrderSummaryModel order,
    required bool isPaid,
    required bool isTransfer,
    required bool isCourier,
    required bool isCancelledWithFee,
    required bool hasPendingTransferProof,
  }) {
    if (isCancelledWithFee) {
      if (isPaid) {
        return 'Fee pembatalan merchant sudah tercatat.';
      }
      return 'Bayar fee pembatalan merchant sebesar 50% dari ongkir aktif terakhir lewat transfer.';
    }

    if (isTransfer) {
      if (isPaid) {
        return 'Pembayaran transfer sudah diverifikasi.';
      }
      return hasPendingTransferProof
          ? 'Bukti transfer menunggu verifikasi driver/admin.'
          : 'Upload bukti transfer agar driver/admin bisa memverifikasi pembayaran.';
    }

    if (isCourier) {
      return isPaid
          ? 'Pembayaran pickup sudah tercatat.'
          : 'Bayar tunai ke driver saat menyerahkan barang di titik ambil.';
    }

    return isPaid
        ? 'Pembayaran tunai sudah tercatat.'
        : 'Bayar tunai ke driver saat pesanan sampai.';
  }

  Future<void> _uploadTransferEvidence(
    BuildContext context,
    WidgetRef ref,
    int orderId,
    Future<void> Function()? onRefresh,
  ) async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (photo == null) {
      return;
    }

    try {
      await ref
          .read(customerOrderApiServiceProvider)
          .uploadTransferEvidence(orderId, photo: photo);
      ref.invalidate(customerOrderTrackingProvider(orderId));
      ref.invalidate(customerOrdersProvider);
      await onRefresh?.call();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bukti transfer berhasil diupload.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
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

  // ---------------------------------------------------------------------------
  // Route card
  // ---------------------------------------------------------------------------

  Widget _buildRouteCard(CustomerOrderDetailModel detail) {
    final order = detail.summary;
    final serviceCode = normalizeServiceTypeCode(order.serviceTypeCode);
    final pickupLabel = _pickupLabel(serviceCode);
    final dropoffLabel = _dropoffLabel(serviceCode);
    final pickupText = _pickupText(detail, serviceCode);
    final dropoffText =
        (detail.dropoffAddress ?? order.deliveryAddress).trim().isEmpty
        ? '-'
        : (detail.dropoffAddress ?? order.deliveryAddress).trim();

    return _buildCard(
      title: 'Rute Pesanan',
      child: Column(
        children: [
          _RoutePoint(
            icon: Icons.radio_button_checked,
            iconColor: AppColors.primary,
            label: pickupLabel,
            value: pickupText,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 9, top: 4, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: 18,
                child: VerticalDivider(
                  color: AppColors.border,
                  thickness: 1.4,
                  width: 1,
                ),
              ),
            ),
          ),
          _RoutePoint(
            icon: Icons.location_on,
            iconColor: AppColors.success,
            label: dropoffLabel,
            value: dropoffText,
          ),
        ],
      ),
    );
  }

  String _pickupLabel(String serviceCode) {
    switch (serviceCode) {
      case ServiceTypeCodes.ride:
        return 'Jemput di';
      case ServiceTypeCodes.courier:
        return 'Ambil paket di';
      case ServiceTypeCodes.shopping:
        return 'Ambil di';
      default:
        return 'Ambil di';
    }
  }

  String _dropoffLabel(String serviceCode) {
    switch (serviceCode) {
      case ServiceTypeCodes.ride:
        return 'Tujuan';
      case ServiceTypeCodes.courier:
        return 'Kirim ke';
      case ServiceTypeCodes.shopping:
        return 'Antar ke';
      default:
        return 'Tujuan';
    }
  }

  String _pickupText(CustomerOrderDetailModel detail, String serviceCode) {
    if (serviceCode == ServiceTypeCodes.shopping &&
        detail.shoppingStops.isNotEmpty) {
      final activeStops = detail.shoppingStops
          .where((stop) => stop.isActive)
          .toList(growable: false);
      final stops = activeStops.isEmpty ? detail.shoppingStops : activeStops;
      final firstStop = stops.first;
      final merchantName = firstStop.merchant.name.trim();
      final merchantAddress = (firstStop.merchant.address ?? '').trim();
      final buffer = StringBuffer(
        merchantName.isNotEmpty && merchantName != '-' ? merchantName : 'Toko',
      );

      if (merchantAddress.isNotEmpty) {
        buffer.write(' - $merchantAddress');
      }
      if (stops.length > 1) {
        buffer.write(' +${stops.length - 1} lokasi ambil lainnya');
      }

      return buffer.toString();
    }

    final pickupAddress = (detail.pickupAddress ?? '').trim();
    if (pickupAddress.isNotEmpty) {
      return pickupAddress;
    }

    final fallbackName = detail.summary.restaurantName.trim();
    return fallbackName.isNotEmpty && fallbackName != '-' ? fallbackName : '-';
  }

  // ---------------------------------------------------------------------------
  // Timeline card: vertical stepper with connectors
  // ---------------------------------------------------------------------------

  Widget _buildTimelineCard(
    List<OrderStatusSnapshot> timeline, {
    required bool isRide,
    required bool shouldShowMap,
  }) {
    return _buildCard(
      title: 'Riwayat Status',
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
                    width: 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: isLast ? 12 : 9,
                          height: isLast ? 12 : 9,
                          decoration: BoxDecoration(
                            color: isLast
                                ? dotColor
                                : dotColor.withValues(alpha: 0.72),
                            shape: BoxShape.circle,
                            border: isLast
                                ? Border.all(
                                    color: dotColor.withValues(alpha: 0.16),
                                    width: 3,
                                  )
                                : null,
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 1.5,
                            height: 24,
                            margin: const EdgeInsets.symmetric(vertical: 4),
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
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: TextStyle(
                              color: isLast ? dotColor : AppColors.textPrimary,
                              fontWeight: isLast
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 12.5,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatDateTime(item.changedAt),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.2,
                              height: 1.25,
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
    IconData? icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
              ],
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

    final brandModel = [
      brand,
      model,
    ].where((part) => part.isNotEmpty).join(' ');
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

class _ShoppingOrderItemsCard extends ConsumerStatefulWidget {
  final CustomerOrderDetailModel detail;
  final Future<void> Function()? onChanged;

  const _ShoppingOrderItemsCard({required this.detail, this.onChanged});

  @override
  ConsumerState<_ShoppingOrderItemsCard> createState() =>
      _ShoppingOrderItemsCardState();
}

class _ShoppingOrderItemsCardState
    extends ConsumerState<_ShoppingOrderItemsCard> {
  final Set<int> _expandedStopIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final stops = detail.shoppingStops;
    final activeStops = stops
        .where((stop) => stop.isActive)
        .toList(growable: false);
    final pricing = detail.shoppingPricing;
    final failedStops = stops
        .where((stop) => stop.isFailed)
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'Item Nitip',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (detail.canEditShoppingItems)
                TextButton.icon(
                  onPressed: () => _openAddItemScreen(context, ref),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('Tambah'),
                ),
            ],
          ),
          const Divider(height: 18, color: AppColors.border),
          if (failedStops.isNotEmpty) ...[
            ...failedStops.map((stop) => _failedStopNotice(context, ref, stop)),
            const SizedBox(height: 4),
          ],
          if (activeStops.isEmpty)
            const Text(
              'Belum ada item belanja.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            ...activeStops.indexed.map(
              (entry) => _stopSection(
                context,
                ref,
                entry.$2,
                showDivider: entry.$1 > 0,
              ),
            ),
          if (pricing != null) ...[
            const Divider(height: 18, color: AppColors.border),
            _pricingRow('Subtotal barang', pricing.subtotal),
            _pricingRow('Ongkir', pricing.deliveryFee),
            _pricingRow('Service fee', pricing.serviceFee),
            ShoppingFeeBreakdown(
              items: pricing.feeBreakdown
                  .map(
                    (item) => ShoppingFeeBreakdownItem(
                      label: item.label,
                      description: item.description,
                      amount: item.amount,
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 4),
            _pricingRow('Total', pricing.totalPrice, isTotal: true),
          ],
        ],
      ),
    );
  }

  Widget _failedStopNotice(
    BuildContext context,
    WidgetRef ref,
    CustomerShoppingStopModel stop,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                color: AppColors.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${stop.merchant.name} tutup/gagal pickup',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if ((stop.failureReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              stop.failureReason!.trim(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openAddItemScreen(
                  context,
                  ref,
                  replacementForPickupLocationId: stop.pickupLocationId,
                ),
                icon: const Icon(Icons.add_business_outlined, size: 16),
                label: const Text('Tambah pengganti'),
              ),
              TextButton.icon(
                onPressed: () => _skipFailedStop(context, ref, stop),
                icon: const Icon(Icons.done_outline, size: 16),
                label: const Text('Lanjut tanpa ini'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stopSection(
    BuildContext context,
    WidgetRef ref,
    CustomerShoppingStopModel stop, {
    required bool showDivider,
  }) {
    const collapsedItemLimit = 5;
    final showToggle = stop.items.length > collapsedItemLimit;
    final isExpanded = _expandedStopIds.contains(stop.pickupLocationId);
    final visibleItems = showToggle && !isExpanded
        ? stop.items.take(collapsedItemLimit).toList(growable: false)
        : stop.items;
    final hiddenCount = stop.items.length - visibleItems.length;
    final hasPendingPrice = stop.items.any((item) => item.isPricePending);
    final address = _displayMerchantAddress(stop.merchant.address);
    final activeStopCount = widget.detail.shoppingStops
        .where((item) => item.isActive)
        .length;
    final sequenceNo = stop.sequenceNo <= 0 ? 1 : stop.sequenceNo;

    return Padding(
      padding: EdgeInsets.only(top: showDivider ? 12 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDivider) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activeStopCount > 1) ...[
                _stopNumberBadge(sequenceNo),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.merchant.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    if (address != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        address,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (stop.isFailed || stop.isSkipped)
                _stopStatusChip(stop.isFailed ? 'Gagal' : 'Dilewati'),
            ],
          ),
          const SizedBox(height: 8),
          ...visibleItems.map((item) => _itemRow(context, ref, item)),
          if (showToggle) ...[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedStopIds.remove(stop.pickupLocationId);
                    } else {
                      _expandedStopIds.add(stop.pickupLocationId);
                    }
                  });
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(
                  isExpanded
                      ? 'Sembunyikan item'
                      : 'Lihat semua item (${stop.items.length})'
                            '${hiddenCount > 0 ? ' (+$hiddenCount)' : ''}',
                ),
              ),
            ),
          ],
          if (hasPendingPrice) ...[
            const SizedBox(height: 4),
            const Text(
              'Harga barang mengikuti struk dari merchant.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stopNumberBadge(int number) {
    return Container(
      width: 21,
      height: 21,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        number.toString(),
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }

  String? _displayMerchantAddress(String? rawAddress) {
    final address = (rawAddress ?? '').trim();
    if (address.isEmpty || address == '-') {
      return null;
    }

    final lower = address.toLowerCase();
    final looksLikeCoordinate = RegExp(
      r'-?\d+\.\d+,\s*-?\d+\.\d+',
    ).hasMatch(address);
    if (looksLikeCoordinate || lower.contains('dummy')) {
      return null;
    }

    return address;
  }

  Widget _stopStatusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.error,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _itemRow(
    BuildContext context,
    WidgetRef ref,
    CustomerShoppingItemModel item,
  ) {
    final priceText = !item.isAvailable
        ? 'Tidak tersedia'
        : item.isPricePending
        ? ''
        : item.subtotal > 0
        ? formatCurrency(item.subtotal)
        : 'Termasuk total struk';
    final statusColor = !item.isAvailable || item.isPricePending
        ? AppColors.error
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.quantity <= 0 ? 1 : item.quantity}x ${item.name}',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    decoration: item.isAvailable
                        ? TextDecoration.none
                        : TextDecoration.lineThrough,
                  ),
                ),
                if ((item.notes ?? '').trim().isNotEmpty)
                  Text(
                    item.notes!.trim(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (priceText.isNotEmpty)
            Flexible(
              child: Text(
                priceText,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (widget.detail.canEditShoppingItems &&
              widget.detail.shoppingItems.length > 1)
            IconButton(
              tooltip: 'Hapus item',
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              onPressed: () => _removeItem(context, ref, item),
              icon: Icon(
                Icons.delete_outline,
                color: AppColors.error.withValues(alpha: 0.82),
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  Widget _pricingRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isTotal
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                fontSize: isTotal ? 13.5 : 12.8,
              ),
            ),
          ),
          Text(
            formatCurrency(value),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
              fontSize: isTotal ? 14.5 : 12.8,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddItemScreen(
    BuildContext context,
    WidgetRef ref, {
    int? replacementForPickupLocationId,
  }) async {
    final result = await context.push<ShoppingAddItemResult>(
      AppRoutes.shoppingAddItemPath(widget.detail.summary.id),
      extra: ShoppingAddItemRouteArgs(
        detail: widget.detail,
        replacementForPickupLocationId: replacementForPickupLocationId,
      ),
    );

    if (result == null || !context.mounted) {
      return;
    }

    ref.invalidate(customerOrderTrackingProvider(widget.detail.summary.id));
    ref.invalidate(customerOrdersProvider);
    await widget.onChanged?.call();
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.deliveryFeeChanged ? AppColors.success : null,
      ),
    );
  }

  Future<void> _skipFailedStop(
    BuildContext context,
    WidgetRef ref,
    CustomerShoppingStopModel stop,
  ) async {
    try {
      await ref
          .read(customerOrderApiServiceProvider)
          .skipFailedShoppingStop(
            widget.detail.summary.id,
            stop.pickupLocationId,
          );
      ref.invalidate(customerOrderTrackingProvider(widget.detail.summary.id));
      ref.invalidate(customerOrdersProvider);
      await widget.onChanged?.call();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${stop.merchant.name} dilewati.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _removeItem(
    BuildContext context,
    WidgetRef ref,
    CustomerShoppingItemModel item,
  ) async {
    try {
      await ref
          .read(customerOrderApiServiceProvider)
          .removeShoppingItem(widget.detail.summary.id, item.id);
      ref.invalidate(customerOrderTrackingProvider(widget.detail.summary.id));
      ref.invalidate(customerOrdersProvider);
      await widget.onChanged?.call();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item belanja berhasil dihapus.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _TrackRouteArgs {
  final int? orderId;
  final bool fromHistory;

  const _TrackRouteArgs({this.orderId, this.fromHistory = false});
}

class _WaitingDriverHeroCard extends StatelessWidget {
  const _WaitingDriverHeroCard();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          height: 164,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.035),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: 12,
                bottom: 8,
                child: Semantics(
                  label: 'Ilustrasi driver BangDeliv sedang dicari',
                  image: true,
                  child: Image.asset(
                    'assets/images/hero.png',
                    width: (constraints.maxWidth * 0.40).clamp(128.0, 168.0),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 16, 18),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.55,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Menunggu Driver',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Kami sedang mencari driver untuk Anda.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.32,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeliveryFeeNotice extends StatelessWidget {
  const _DeliveryFeeNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  const _RoutePoint({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 19),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value, {this.emphasized = false});
  final String label;
  final String value;
  final bool emphasized;
}
