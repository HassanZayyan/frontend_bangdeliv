import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../models/customer_order_model.dart';
import '../../../../core/di/app_providers.dart';
import '../../../orders/application/customer_order_providers.dart';
import '../../../orders/application/order_chat_unread_provider.dart';
import '../../application/customer_order_tracking_provider.dart';
import '../../../../utils/order_formatters.dart';
import '../../../../utils/order_status.dart';
import '../../../../utils/order_ui_helpers.dart';
import '../../../../utils/service_type.dart';
import '../../../../widgets/order_chat_badge_icon.dart';
import '../../../../widgets/tracking_map_section.dart';
import '../../application/track_order_presenter.dart';

import '../widgets/track_order_widgets.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeArgs = initialOrderId != null
        ? TrackRouteArgs(orderId: initialOrderId)
        : TrackOrderPresenter.extractRouteArgs(GoRouterState.of(context).extra);
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
    final appBarTitle = TrackOrderPresenter.appBarTitle(
      forceHistoryTitle: forceHistoryTitle,
      isTerminalStatus:
          trackingAsync.asData?.value.detail.summary.isTerminalStatus ?? false,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          appBarTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
              child: Icon(
                Icons.map_outlined,
                size: AppTextScaling.adaptive(context, normal: 80, large: 68),
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
    final shouldShowMap = TrackOrderPresenter.shouldShowTrackingMap(order);
    final isWaitingDriver = TrackOrderPresenter.isWaitingDriverStatus(order);
    final isPassengerDropoff = TrackOrderPresenter.isPassengerDropoffStatus(
      order,
    );
    final isDriverArrivedDestination =
        TrackOrderPresenter.isDriverArrivedDestinationStatus(order);
    final isRide =
        normalizeServiceTypeCode(order.serviceTypeCode) ==
        ServiceTypeCodes.ride;
    final driverName = (detail.driverName ?? '').trim();
    final driverVehicleLabel = _driverVehicleLabel(detail);
    final driverVehiclePlate = _driverVehiclePlate(detail);

    if (!shouldShowMap) {
      return _buildFixedStatusLayout(
        context: context,
        order: order,
        detail: detail,
        ref: ref,
        infoMessage: TrackOrderPresenter.fixedStatusInfoMessage(order),
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
        infoMessage: TrackOrderPresenter.fixedStatusInfoMessage(order),
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
                                context: context,
                                order: order,
                                isRide: isRide,
                              ),
                              const SizedBox(height: 8),
                              if (driverName.isNotEmpty) ...[
                                _buildDriverCard(
                                  driverName,
                                  orderId: order.id,
                                  avatarUrl: detail.driverAvatarUrl,
                                  vehicleLabel: driverVehicleLabel,
                                  vehiclePlate: driverVehiclePlate,
                                  onChat: () => context.push(
                                    AppRoutes.orderChatPath(order.id),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              _buildRouteCard(detail),
                              const SizedBox(height: 8),
                              _buildOrderDetailsCard(order, detail),
                              const SizedBox(height: 8),
                              if (detail.isShoppingOrder) ...[
                                TrackShoppingOrderItemsCard(
                                  detail: detail,
                                  onChanged: onRefresh,
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (detail.proofs.isNotEmpty) ...[
                                _buildProofsCard(context, detail.proofs),
                                const SizedBox(height: 8),
                              ],
                              _buildPaymentCard(
                                context,
                                ref,
                                order,
                                detail,
                                onRefresh,
                              ),
                              const SizedBox(height: 8),
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
    required String infoMessage,
    Future<void> Function()? onRefresh,
  }) {
    final driverName = (detail.driverName ?? '').trim();
    final driverVehicleLabel = _driverVehicleLabel(detail);
    final driverVehiclePlate = _driverVehiclePlate(detail);
    final isWaitingDriver = TrackOrderPresenter.isWaitingDriverStatus(order);

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
                context: context,
                order: order,
                isRide:
                    normalizeServiceTypeCode(order.serviceTypeCode) ==
                    ServiceTypeCodes.ride,
              ),
              const SizedBox(height: 12),
              if (driverName.isNotEmpty) ...[
                _buildDriverCard(
                  driverName,
                  orderId: order.id,
                  avatarUrl: detail.driverAvatarUrl,
                  vehicleLabel: driverVehicleLabel,
                  vehiclePlate: driverVehiclePlate,
                  onChat: () => context.push(AppRoutes.orderChatPath(order.id)),
                ),
                const SizedBox(height: 12),
              ],
              _buildRouteCard(detail),
              const SizedBox(height: 12),
              _buildOrderDetailsCard(order, detail),
              const SizedBox(height: 12),
              if (detail.isShoppingOrder) ...[
                TrackShoppingOrderItemsCard(
                  detail: detail,
                  onChanged: onRefresh,
                ),
                const SizedBox(height: 12),
              ],
              if (detail.proofs.isNotEmpty) ...[
                _buildProofsCard(context, detail.proofs),
                const SizedBox(height: 12),
              ],
              _buildPaymentCard(context, ref, order, detail, onRefresh),
              if (!order.isTerminalStatus) ...[
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
              const TrackWaitingDriverHeroCard(),
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
                TrackShoppingOrderItemsCard(
                  detail: detail,
                  onChanged: onRefresh,
                ),
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
        borderRadius: BorderRadius.circular(14),
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
  // Active tracking card: order number, status badge, and progress
  // ---------------------------------------------------------------------------

  Widget _buildActiveTrackingCard({
    required BuildContext context,
    required CustomerOrderSummaryModel order,
    bool isRide = false,
  }) {
    final statusTitle = _detailStatusTitle(order);
    final statusTitleFontSize = AppTextScaling.adaptive(
      context,
      normal: 18,
      large: 16.5,
    );
    final showProgress =
        !order.isTerminalStatus &&
        !isTerminalOrderStatus(normalizeOrderStatusCode(order.statusCode));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
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
                fontWeight: FontWeight.w800,
                height: 1.12,
              ).copyWith(fontSize: statusTitleFontSize),
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
    String? avatarUrl,
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
        borderRadius: BorderRadius.circular(14),
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
          _buildDriverAvatar(driverName, avatarUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
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
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(driver)',
                      maxLines: 1,
                      style: GoogleFonts.nunitoSans(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                        fontSize: 12.5,
                        height: 1.2,
                      ),
                    ),
                  ],
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

  Widget _buildDriverAvatar(String driverName, String? avatarUrl) {
    final normalizedAvatarUrl = avatarUrl?.trim() ?? '';

    return Semantics(
      image: true,
      label: 'Avatar driver $driverName',
      child: Container(
        width: 48,
        height: 48,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Text(
                _driverInitials(driverName),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  height: 1,
                ),
              ),
            ),
            if (normalizedAvatarUrl.isNotEmpty)
              Image.network(
                normalizedAvatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
          ],
        ),
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
    CustomerOrderDetailModel detail,
  ) {
    final deliveryFeeNotice = _deliveryFeeNotice(order, detail);
    final serviceCode = normalizeServiceTypeCode(order.serviceTypeCode);
    final rows = <TrackInfoRow>[
      TrackInfoRow('No. Order', order.orderNumber),
      TrackInfoRow('Layanan', order.serviceTypeLabel),
      if (serviceCode == ServiceTypeCodes.courier &&
          order.itemsSummary.trim().isNotEmpty &&
          order.itemsSummary.trim().toLowerCase() != 'tanpa item')
        TrackInfoRow('Barang', order.itemsSummary.trim()),
      if ((detail.deliveryDistanceText ?? '').trim().isNotEmpty)
        TrackInfoRow('Jarak', detail.deliveryDistanceText!.trim()),
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
          if (deliveryFeeNotice != null) ...[
            const SizedBox(height: 12),
            TrackDeliveryFeeNotice(text: deliveryFeeNotice),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(TrackInfoRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
    final normalizedPaymentMethod = TrackOrderPresenter.normalizedPaymentMethod(
      order,
      detail,
    );
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
    final paymentStatusText = hasPendingTransferProof && !isPaid
        ? 'Menunggu verifikasi'
        : paymentStatusLabel(detail.paymentStatus);
    final paymentStatusColor = _paymentStatusColor(
      detail.paymentStatus,
      isPaid: isPaid,
      hasPendingTransferProof: hasPendingTransferProof,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _paymentMethodSummary(
                  paymentMethodLabel(normalizedPaymentMethod),
                ),
              ),
              const SizedBox(width: 10),
              _paymentStatusPill(
                label: paymentStatusText,
                color: paymentStatusColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _summaryRow(
            TrackInfoRow(
              'Total',
              formatCurrency(order.totalAmount),
              emphasized: true,
            ),
          ),
          const SizedBox(height: 10),
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
            const SizedBox(height: 4),
            if ((isTransfer || isCancelledWithFee) && !hasPendingTransferProof)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _uploadTransferEvidence(
                    context,
                    ref,
                    order.id,
                    onRefresh,
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: paymentStatusColor),
                    foregroundColor: paymentStatusColor,
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

  Widget _paymentMethodSummary(String methodLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Metode',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          methodLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13.2,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _paymentStatusPill({required String label, required Color color}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  Color _paymentStatusColor(
    String? rawStatus, {
    required bool isPaid,
    required bool hasPendingTransferProof,
  }) {
    if (isPaid) {
      return AppColors.success;
    }

    final normalizedStatus = (rawStatus ?? '').trim().toLowerCase();
    if (normalizedStatus.contains('fail') ||
        normalizedStatus.contains('reject') ||
        normalizedStatus.contains('declin') ||
        normalizedStatus.contains('cancel')) {
      return AppColors.error;
    }

    if (hasPendingTransferProof) {
      return AppColors.warning;
    }

    return AppColors.primary;
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
          .read(customerOrderRepositoryProvider)
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
          TrackRoutePoint(
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
          TrackRoutePoint(
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
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
          const Divider(height: 14, color: AppColors.border),
          child,
        ],
      ),
    );
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
