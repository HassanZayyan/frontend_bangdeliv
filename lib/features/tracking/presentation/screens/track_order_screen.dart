import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/payment_assets.dart';
import '../../../../core/widgets/bang_amount_negotiation_card.dart';
import '../../../../core/widgets/bang_confirmation_dialog.dart';
import '../../../../core/widgets/bang_counter_amount_dialog.dart';
import '../../../../core/widgets/bang_image_preview.dart';
import '../../../../core/widgets/bang_sheet_drag_region.dart';
import '../../../../services/qris_download_service.dart';
import '../../../../models/customer_order_model.dart';
import '../../../../models/payment_proof_feedback_model.dart';
import '../../../../core/di/app_providers.dart';
import '../../../orders/application/customer_order_providers.dart';
import '../../../orders/application/order_chat_unread_provider.dart';
import '../../../orders/presentation/screens/order_chat_screen.dart';
import '../../../orders/presentation/widgets/customer_order_cancel_sheet.dart';
import '../../application/customer_order_tracking_provider.dart';
import '../../application/tracking_focus_target.dart';
import '../../../../utils/order_formatters.dart';
import '../../../../utils/order_status.dart';
import '../../../../utils/order_ui_helpers.dart';
import '../../../../utils/service_type.dart';
import '../../../../widgets/order_chat_badge_icon.dart';
import '../../../../widgets/profile_avatar.dart';
import '../../../../widgets/tracking_map_section.dart';
import '../../application/track_order_presenter.dart';

import '../widgets/track_order_widgets.dart';

class TrackOrderScreen extends ConsumerStatefulWidget {
  const TrackOrderScreen({super.key}) : initialOrderId = null;

  const TrackOrderScreen.route({super.key, required int orderId})
    : initialOrderId = orderId;

  final int? initialOrderId;

  @override
  ConsumerState<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends ConsumerState<TrackOrderScreen> {
  final Set<int> _cancellingOrderIds = <int>{};
  final GlobalKey _paymentFocusKey = GlobalKey(debugLabel: 'payment_focus');
  final GlobalKey _deliveryFeeFocusKey = GlobalKey(
    debugLabel: 'delivery_fee_focus',
  );
  final Map<int, GlobalKey> _shoppingPriceFocusKeys = <int, GlobalKey>{};
  String? _scheduledFocusSignature;
  String? _completedFocusSignature;
  String? _appliedShoppingFocusSignature;
  double? _trackingSheetExtent;
  String _selectedShoppingPointId = 'summary';
  final DraggableScrollableController _trackingSheetController =
      DraggableScrollableController();

  static const double _trackingSheetInitialChildSize = 0.38;
  static const double _trackingSheetMinChildSize = 0.20;
  static const double _trackingSheetMidChildSize = 0.62;
  static const double _trackingSheetMaxChildSize = 0.92;
  static const double _trackingSheetExtentUpdateThreshold = 0.006;
  static const double _trackingMapTopPadding = 76;
  static const double _trackingMapSidePadding = 16;
  static const double _trackingMapBottomGap = 18;
  static const double _trackingMapMinimumVisibleHeight = 180;

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
    'Tiba',
  ];

  static const _kStepLabelsRideCompleted = [
    'Menunggu',
    'Ditugaskan',
    'Naik',
    'Perjalanan',
    'Selesai',
  ];

  double get _effectiveTrackingSheetExtent =>
      _trackingSheetExtent ?? _trackingSheetInitialChildSize;

  @override
  void dispose() {
    _trackingSheetController.dispose();
    super.dispose();
  }

  bool _isCancellingOrder(int orderId) => _cancellingOrderIds.contains(orderId);

  bool _handleTrackingSheetNotification(
    DraggableScrollableNotification notification,
  ) {
    final nextExtent = notification.extent
        .clamp(_trackingSheetMinChildSize, _trackingSheetMaxChildSize)
        .toDouble();
    if ((nextExtent - _effectiveTrackingSheetExtent).abs() <
        _trackingSheetExtentUpdateThreshold) {
      return false;
    }

    setState(() => _trackingSheetExtent = nextExtent);
    return false;
  }

  EdgeInsets _trackingMapPadding(BoxConstraints constraints) {
    final height = constraints.maxHeight;
    final sheetHeight = height * _effectiveTrackingSheetExtent;
    final desiredBottom = sheetHeight + _trackingMapBottomGap;
    final maxBottom = (height - _trackingMapMinimumVisibleHeight)
        .clamp(0.0, height)
        .toDouble();
    final bottomPadding = desiredBottom.clamp(0.0, maxBottom).toDouble();

    return EdgeInsets.fromLTRB(
      _trackingMapSidePadding,
      _trackingMapTopPadding,
      _trackingMapSidePadding,
      bottomPadding,
    );
  }

  @override
  Widget build(BuildContext context) {
    final goRouterState = GoRouterState.of(context);
    final focusTarget = TrackingFocusTarget.fromUri(goRouterState.uri);
    final routeArgs = widget.initialOrderId != null
        ? TrackRouteArgs(orderId: widget.initialOrderId)
        : TrackOrderPresenter.extractRouteArgs(goRouterState.extra);
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
        focusTarget: focusTarget,
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
        focusTarget: focusTarget,
      ),
      error: (error, stackTrace) => _buildScaffold(
        context,
        ref,
        AsyncError<CustomerOrderTrackingState>(error, stackTrace),
        showEmptyForNoActiveOrder: false,
        onRetry: () => ref.invalidate(customerOrdersProvider),
        focusTarget: focusTarget,
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
            focusTarget: focusTarget,
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
          focusTarget: focusTarget,
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
    TrackingFocusTarget? focusTarget,
  }) {
    final appBarTitle = TrackOrderPresenter.appBarTitle(
      forceHistoryTitle: forceHistoryTitle,
      isTerminalStatus:
          trackingAsync.asData?.value.detail.summary.isResolvedForCustomer ??
          false,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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
                focusTarget: focusTarget,
              ),
            ),
    );
  }

  void _scheduleFocusScroll(TrackingFocusTarget? target) {
    if (target == null) {
      return;
    }

    final signature = target.signature;
    if (_completedFocusSignature == signature ||
        _scheduledFocusSignature == signature) {
      return;
    }

    _scheduledFocusSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduledFocusSignature = null;
      if (!mounted) {
        return;
      }

      final context = _contextForFocusTarget(target);
      if (context == null) {
        return;
      }

      _completedFocusSignature = signature;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
    });
  }

  BuildContext? _contextForFocusTarget(TrackingFocusTarget target) {
    if (target.isPayment) {
      return _paymentFocusKey.currentContext;
    }
    if (target.isDeliveryFee) {
      return _deliveryFeeFocusKey.currentContext;
    }
    if (target.isShoppingPrice) {
      final pickupLocationId = target.pickupLocationId;
      if (pickupLocationId != null) {
        return _shoppingPriceFocusKeys[pickupLocationId]?.currentContext;
      }
    }

    return null;
  }

  GlobalKey _shoppingPriceFocusKey(int pickupLocationId) {
    return _shoppingPriceFocusKeys.putIfAbsent(
      pickupLocationId,
      () => GlobalKey(debugLabel: 'shopping_price_focus_$pickupLocationId'),
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
    TrackingFocusTarget? focusTarget,
  }) {
    _scheduleFocusScroll(focusTarget);

    final detail = tracking.detail;
    _syncShoppingSelection(detail, focusTarget);
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
    final driverEtaMessage = TrackOrderPresenter.driverEtaMessage(detail);

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
        final mapPadding = _trackingMapPadding(constraints);

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
                      showLegend: false,
                      followDriver: true,
                      mapPadding: mapPadding,
                      selectedPickupId: _selectedShoppingPickupId?.toString(),
                      onPickupSelected: detail.isShoppingOrder
                          ? (pickupId) {
                              setState(
                                () => _selectedShoppingPointId =
                                    'pickup:$pickupId',
                              );
                            }
                          : null,
                    )
                  : const ColoredBox(color: AppColors.background),
            ),
            NotificationListener<DraggableScrollableNotification>(
              onNotification: _handleTrackingSheetNotification,
              child: DraggableScrollableSheet(
                controller: _trackingSheetController,
                initialChildSize: _trackingSheetInitialChildSize,
                minChildSize: _trackingSheetMinChildSize,
                maxChildSize: _trackingSheetMaxChildSize,
                snap: true,
                snapSizes: const [
                  _trackingSheetInitialChildSize,
                  _trackingSheetMidChildSize,
                  _trackingSheetMaxChildSize,
                ],
                builder: (context, scrollController) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10),
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
                        BangSheetDragRegion(
                          key: const ValueKey(
                            'customer-tracking-sheet-header-drag-region',
                          ),
                          controller: _trackingSheetController,
                          minExtent: _trackingSheetMinChildSize,
                          maxExtent: _trackingSheetMaxChildSize,
                          snapExtents: const [
                            _trackingSheetMinChildSize,
                            _trackingSheetInitialChildSize,
                            _trackingSheetMidChildSize,
                            _trackingSheetMaxChildSize,
                          ],
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              Container(
                                key: const ValueKey(
                                  'customer-tracking-sheet-handle',
                                ),
                                width: 48,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.border,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (detail.isShoppingOrder) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: _buildShoppingPointSelector(detail),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: onRefresh ?? () async {},
                            child: ListView(
                              controller: scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                              children: [
                                if (_showShoppingSummary(detail))
                                  _buildActiveTrackingCard(
                                    order: order,
                                    isRide: isRide,
                                    driverEtaMessage: driverEtaMessage,
                                  ),
                                const SizedBox(height: 12),
                                if (_showShoppingSummary(detail) &&
                                    driverName.isNotEmpty) ...[
                                  _buildDriverCard(
                                    driverName,
                                    orderId: order.id,
                                    avatarUrl: detail.driverAvatarUrl,
                                    vehicleLabel: driverVehicleLabel,
                                    vehiclePlate: driverVehiclePlate,
                                    onChat: () => context.push(
                                      AppRoutes.orderChatPath(order.id),
                                      extra: OrderChatRouteArgs(
                                        returnPath: GoRouterState.of(
                                          context,
                                        ).uri.toString(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (!_showSelectedShoppingPlace(detail)) ...[
                                  _buildRouteCard(detail),
                                  const SizedBox(height: 12),
                                  _buildOrderDetailsCard(
                                    context,
                                    ref,
                                    order,
                                    detail,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (detail.isShoppingOrder) ...[
                                  TrackShoppingOrderItemsCard(
                                    detail: detail,
                                    onChanged: onRefresh,
                                    shoppingPriceFocusKeyFor:
                                        _shoppingPriceFocusKey,
                                    selectedPickupLocationId:
                                        _selectedShoppingPickupId,
                                    showStops: _showSelectedShoppingPlace(
                                      detail,
                                    ),
                                    showPricing: _showShoppingSummary(detail),
                                    showGlobalActions: _showShoppingSummary(
                                      detail,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (detail.proofs.isNotEmpty) ...[
                                  _buildProofsCard(context, detail.proofs),
                                  const SizedBox(height: 12),
                                ],
                                if (!_showSelectedShoppingPlace(detail))
                                  ..._paymentCardSection(
                                    context,
                                    ref,
                                    order,
                                    detail,
                                    onRefresh,
                                  ),
                                if (_showShoppingSummary(detail) &&
                                    TrackOrderPresenter.canCustomerCancelOrder(
                                      order,
                                    )) ...[
                                  _buildCustomerCancelOrderAction(order),
                                  const SizedBox(height: 12),
                                ],
                                if (_showShoppingSummary(detail))
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
              if (detail.isShoppingOrder) ...[
                _buildShoppingPointSelector(detail),
                const SizedBox(height: 12),
              ],
              if (_showShoppingSummary(detail)) ...[
                _buildActiveTrackingCard(
                  order: order,
                  isRide:
                      normalizeServiceTypeCode(order.serviceTypeCode) ==
                      ServiceTypeCodes.ride,
                  driverEtaMessage: TrackOrderPresenter.driverEtaMessage(
                    detail,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_showShoppingSummary(detail) && driverName.isNotEmpty) ...[
                _buildDriverCard(
                  driverName,
                  orderId: order.id,
                  avatarUrl: detail.driverAvatarUrl,
                  vehicleLabel: driverVehicleLabel,
                  vehiclePlate: driverVehiclePlate,
                  onChat: () => context.push(
                    AppRoutes.orderChatPath(order.id),
                    extra: OrderChatRouteArgs(
                      returnPath: GoRouterState.of(context).uri.toString(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (!_showSelectedShoppingPlace(detail)) ...[
                _buildRouteCard(detail),
                const SizedBox(height: 12),
                _buildOrderDetailsCard(context, ref, order, detail),
                const SizedBox(height: 12),
              ],
              if (detail.isShoppingOrder) ...[
                TrackShoppingOrderItemsCard(
                  detail: detail,
                  onChanged: onRefresh,
                  shoppingPriceFocusKeyFor: _shoppingPriceFocusKey,
                  selectedPickupLocationId: _selectedShoppingPickupId,
                  showStops: _showSelectedShoppingPlace(detail),
                  showPricing: _showShoppingSummary(detail),
                  showGlobalActions: _showShoppingSummary(detail),
                ),
                const SizedBox(height: 12),
              ],
              if (!_showSelectedShoppingPlace(detail) &&
                  detail.proofs.isNotEmpty) ...[
                _buildProofsCard(context, detail.proofs),
                const SizedBox(height: 12),
              ],
              if (!_showSelectedShoppingPlace(detail))
                ..._paymentCardSection(context, ref, order, detail, onRefresh),
              if (_showShoppingSummary(detail) &&
                  TrackOrderPresenter.canCustomerCancelOrder(order)) ...[
                _buildCustomerCancelOrderAction(order),
                const SizedBox(height: 12),
              ],
              if (_showShoppingSummary(detail))
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
              if (detail.isShoppingOrder) ...[
                _buildShoppingPointSelector(detail),
                const SizedBox(height: 12),
              ],
              if (_showShoppingSummary(detail)) ...[
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
              ],
              if (!_showSelectedShoppingPlace(detail)) ...[
                _buildRouteCard(detail),
                const SizedBox(height: 12),
                _buildOrderDetailsCard(context, ref, order, detail),
                const SizedBox(height: 12),
              ],
              if (detail.isShoppingOrder) ...[
                TrackShoppingOrderItemsCard(
                  detail: detail,
                  onChanged: onRefresh,
                  shoppingPriceFocusKeyFor: _shoppingPriceFocusKey,
                  selectedPickupLocationId: _selectedShoppingPickupId,
                  showStops: _showSelectedShoppingPlace(detail),
                  showPricing: _showShoppingSummary(detail),
                  showGlobalActions: _showShoppingSummary(detail),
                ),
                const SizedBox(height: 12),
              ],
              if (!_showSelectedShoppingPlace(detail) &&
                  detail.proofs.isNotEmpty) ...[
                _buildProofsCard(context, detail.proofs),
                const SizedBox(height: 12),
              ],
              if (!_showSelectedShoppingPlace(detail))
                ..._paymentCardSection(context, ref, order, detail, onRefresh),
              if (_showShoppingSummary(detail) &&
                  TrackOrderPresenter.canCustomerCancelOrder(order))
                _buildCustomerCancelOrderAction(order),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCancelOrderAction(CustomerOrderSummaryModel order) {
    final isCancelling = _isCancellingOrder(order.id);

    return Semantics(
      button: true,
      label: isCancelling ? 'Sedang membatalkan pesanan' : 'Batalkan pesanan',
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          key: ValueKey('track-cancel-order-${order.id}'),
          onPressed: isCancelling ? null : () => _cancelOrder(order),
          icon: isCancelling
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.error,
                  ),
                )
              : const Icon(Icons.cancel_outlined, size: 19),
          label: Text(
            isCancelling ? 'Membatalkan...' : 'Batalkan Pesanan',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            disabledForegroundColor: AppColors.textMuted,
            side: BorderSide(
              color: isCancelling
                  ? AppColors.border
                  : AppColors.error.withValues(alpha: 0.55),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cancelOrder(CustomerOrderSummaryModel order) async {
    final reason = await showCustomerOrderCancelSheet(context);
    if (reason == null || reason.trim().isEmpty || !mounted) {
      return;
    }

    setState(() => _cancellingOrderIds.add(order.id));

    try {
      await ref
          .read(customerOrderRepositoryProvider)
          .cancelOrder(order.id, reason: reason);

      ref.invalidate(customerOrderTrackingProvider(order.id));
      ref.invalidate(customerOrdersProvider);
      ref.invalidate(customerOrderDetailProvider(order.id));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order berhasil dibatalkan.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cancellingOrderIds.remove(order.id));
      }
    }
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
                'Tempat ${stop.sequenceNo <= 0 ? 1 : stop.sequenceNo}: ${stop.merchant.name}',
            latitude: stop.merchant.latitude!,
            longitude: stop.merchant.longitude!,
          ),
        )
        .toList(growable: false);
  }

  void _syncShoppingSelection(
    CustomerOrderDetailModel detail,
    TrackingFocusTarget? focusTarget,
  ) {
    if (!detail.isShoppingOrder) {
      _selectedShoppingPointId = 'summary';
      return;
    }
    if (_selectedShoppingPointId == 'dropoff') {
      _selectedShoppingPointId = 'summary';
    }
    // Semua tempat (termasuk yang gagal & yang sudah diganti) tetap bisa dibuka
    // sebagai history; hanya SKIPPED yang tak pernah tampil.
    final selectableIds = detail.shoppingStops
        .where((stop) => !stop.isSkipped)
        .map((stop) => stop.pickupLocationId)
        .toSet();
    final focusedPickup = focusTarget?.pickupLocationId;
    final focusSignature = focusTarget == null
        ? null
        : '${detail.summary.id}:${focusTarget.signature}';
    if (focusedPickup != null &&
        selectableIds.contains(focusedPickup) &&
        _appliedShoppingFocusSignature != focusSignature) {
      _selectedShoppingPointId = 'pickup:$focusedPickup';
      _appliedShoppingFocusSignature = focusSignature;
      return;
    }
    final selectedPickup = _selectedShoppingPickupId;
    if (selectedPickup != null && !selectableIds.contains(selectedPickup)) {
      _selectedShoppingPointId = 'summary';
    }
  }

  int? get _selectedShoppingPickupId {
    if (!_selectedShoppingPointId.startsWith('pickup:')) return null;
    return int.tryParse(_selectedShoppingPointId.substring(7));
  }

  bool _showShoppingSummary(CustomerOrderDetailModel detail) =>
      !detail.isShoppingOrder || _selectedShoppingPointId == 'summary';

  bool _showSelectedShoppingPlace(CustomerOrderDetailModel detail) =>
      detail.isShoppingOrder && _selectedShoppingPickupId != null;

  Widget _buildShoppingPointSelector(CustomerOrderDetailModel detail) {
    // History lengkap: semua tempat yang pernah didatangi tetap tampil sebagai
    // tab (gagal maupun sudah diganti) -- maksimal 3 sesuai kuota BangDeliv.
    // Nomor tab STABIL mengikuti urutan pembuatan (pickupLocationId menaik),
    // bukan sequence_no rute yang bisa berubah saat ongkir dioptimasi ulang.
    final stops =
        detail.shoppingStops
            .where((stop) => !stop.isSkipped)
            .toList(growable: false)
          ..sort((a, b) => a.pickupLocationId.compareTo(b.pickupLocationId));
    final entries = <(String, String, IconData?, Color?)>[
      ('summary', 'Ringkasan', null, null),
      ...stops.indexed.map((entry) {
        final stop = entry.$2;
        // Tempat yang gagal, dibatalkan, maupun sudah diganti sama-sama pakai
        // ikon silang merah -- menandakan tempat itu batal/tidak jadi.
        final (IconData? icon, Color? color) =
            (stop.isReplaced || stop.isFailed || stop.isAbandoned)
            ? (Icons.cancel_outlined, AppColors.error)
            : (null, null);
        return (
          'pickup:${stop.pickupLocationId}',
          'Tempat ${entry.$1 + 1}',
          icon,
          color,
        );
      }),
    ];

    return Semantics(
      label: 'Pilih bagian detail order Nitip',
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          key: const ValueKey('customer-shopping-point-selector'),
          scrollDirection: Axis.horizontal,
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final selected = _selectedShoppingPointId == entry.$1;
            final icon = entry.$3;
            return ChoiceChip(
              selected: selected,
              // Jangan pakai centang bawaan chip: biar ikon status (✕/diganti)
              // tetap terlihat saat tab dipilih.
              showCheckmark: false,
              avatar: icon != null
                  ? Icon(
                      icon,
                      size: 16,
                      color: selected ? AppColors.primary : entry.$4,
                    )
                  : null,
              label: Text(entry.$2),
              onSelected: (_) {
                if (!selected) {
                  setState(() => _selectedShoppingPointId = entry.$1);
                }
              },
            );
          },
        ),
      ),
    );
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
    final normalized = normalizeOrderStatusCode(statusCode);
    final stepLabels = isRide
        ? normalized == OrderStatusCodes.completed
              ? _kStepLabelsRideCompleted
              : _kStepLabelsRide
        : _kStepLabelsDefault;
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
        borderRadius: BorderRadius.circular(10),
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
    required CustomerOrderSummaryModel order,
    bool isRide = false,
    String? driverEtaMessage,
  }) {
    final statusTitle = _detailStatusTitle(order);
    final etaMessage = (driverEtaMessage ?? '').trim();
    final showProgress =
        !order.isTerminalStatus &&
        !isTerminalOrderStatus(normalizeOrderStatusCode(order.statusCode));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
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
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.15,
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
          if (etaMessage.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildDriverEtaBanner(etaMessage),
          ],
        ],
      ),
    );
  }

  Widget _buildDriverEtaBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: AppColors.primaryDark,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
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

  String? _driverVehiclePart(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Widget? _driverVehicleLine({String? vehicleLabel, String? vehiclePlate}) {
    final label = _driverVehiclePart(vehicleLabel);
    final plate = _driverVehiclePart(vehiclePlate);
    if (label == null && plate == null) {
      return null;
    }

    const style = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.25,
    );

    if (label == null || plate == null) {
      return Text(
        label ?? plate!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return Row(
      children: [
        Flexible(
          flex: 5,
          fit: FlexFit.loose,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const Text(' - ', maxLines: 1, style: style),
        Flexible(
          flex: 4,
          fit: FlexFit.loose,
          child: Text(
            plate,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
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
    final vehicleLine = _driverVehicleLine(
      vehicleLabel: vehicleLabel,
      vehiclePlate: vehiclePlate,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
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
          ProfileAvatar(name: driverName, avatarUrl: avatarUrl, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    height: 1.15,
                  ),
                ),
                if (vehicleLine != null) ...[
                  const SizedBox(height: 4),
                  vehicleLine,
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
    return TrackOrderPresenter.detailStatusTitle(order);
  }

  // ---------------------------------------------------------------------------
  // Order summary card
  // ---------------------------------------------------------------------------

  Widget _buildOrderDetailsCard(
    BuildContext context,
    WidgetRef ref,
    CustomerOrderSummaryModel order,
    CustomerOrderDetailModel detail,
  ) {
    final deliveryFeeNotice = _deliveryFeeNotice(order, detail);
    final deliveryFeeNoticeReason = _deliveryFeeNoticeReason(order, detail);
    final serviceCode = normalizeServiceTypeCode(order.serviceTypeCode);
    final isShopping = serviceCode == ServiceTypeCodes.shopping;
    final isPaid = isPaymentPaid(detail.paymentStatus);
    final summaryPaymentMessage = _paymentMessage(
      order,
      detail,
      isPaid: isPaid,
    );
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
          if (!isShopping) ...[
            const Divider(height: 18, thickness: 1, color: AppColors.border),
            _summaryRow(
              TrackInfoRow(
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
            TrackDeliveryFeeNotice(
              text: deliveryFeeNotice,
              reason: deliveryFeeNoticeReason,
            ),
          ],
          if (detail.deliveryFeeNegotiation?.canCustomerRespond == true) ...[
            const SizedBox(height: 12),
            _deliveryFeeNegotiationCard(context, ref, detail),
          ],
        ],
      ),
    );
  }

  Widget _deliveryFeeNegotiationCard(
    BuildContext context,
    WidgetRef ref,
    CustomerOrderDetailModel detail,
  ) {
    final negotiation = detail.deliveryFeeNegotiation;
    final amount = negotiation?.quotedAmount ?? 0;
    final isShoppingTotalTransport =
        negotiation?.isShoppingTotalTransport == true;

    return KeyedSubtree(
      key: _deliveryFeeFocusKey,
      child: BangAmountNegotiationCard(
        label: isShoppingTotalTransport
            ? 'Konfirmasi total ongkir Nitip'
            : 'Konfirmasi revisi ongkir',
        amount: amount,
        amountLabel: isShoppingTotalTransport
            ? 'Total ongkir Nitip'
            : 'Ongkir baru',
        previousAmount: isShoppingTotalTransport
            ? negotiation?.previousTotalTransport
            : negotiation?.oldDeliveryFee,
        previousAmountLabel: isShoppingTotalTransport
            ? 'Total transport sebelumnya'
            : 'Ongkir awal',
        reasonLabel: 'Alasan',
        reason: negotiation?.note,
        approveLabel: 'Setujui',
        counterLabel: 'Tawar',
        cancelLabel: 'Batalkan pesanan',
        // Pada revisi total ongkir Nitip, driver sudah membeli barang sehingga
        // customer tidak boleh membatalkan pesanan (backend juga menolaknya).
        // Customer tetap bisa Setujui atau Tawar.
        showCancelAction: !isShoppingTotalTransport,
        showIcon: false,
        embedded: true,
        onApprove: () => _respondDeliveryFeeOverride(
          context,
          ref,
          detail,
          action: 'APPROVE',
        ),
        onCounter: () => _showDeliveryFeeCounterDialog(context, ref, detail),
        onCancel: () => _showDeliveryFeeCancelSheet(context, ref, detail),
      ),
    );
  }

  Widget _summaryRow(TrackInfoRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
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

  Future<void> _showDeliveryFeeCounterDialog(
    BuildContext context,
    WidgetRef ref,
    CustomerOrderDetailModel detail,
  ) async {
    final amount = await showBangCounterAmountDialog(
      context,
      title: 'Tawar ongkir',
    );

    if (amount == null || amount <= 0 || !context.mounted) {
      return;
    }

    await _respondDeliveryFeeOverride(
      context,
      ref,
      detail,
      action: 'COUNTER',
      counterAmount: amount,
    );
  }

  Future<void> _showDeliveryFeeCancelSheet(
    BuildContext context,
    WidgetRef ref,
    CustomerOrderDetailModel detail,
  ) async {
    final confirmed = await showBangConfirmationDialog(
      context,
      title: 'Batalkan pesanan?',
      message:
          'Pesanan akan dibatalkan dan revisi ongkir tidak dilanjutkan. Tindakan ini tidak bisa dibatalkan.',
      confirmLabel: 'Batalkan',
      isDestructive: true,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    await _respondDeliveryFeeOverride(
      context,
      ref,
      detail,
      action: 'CANCEL_ORDER',
    );
  }

  Future<void> _respondDeliveryFeeOverride(
    BuildContext context,
    WidgetRef ref,
    CustomerOrderDetailModel detail, {
    required String action,
    double? counterAmount,
  }) async {
    try {
      await ref
          .read(customerOrderRepositoryProvider)
          .respondDeliveryFeeOverride(
            detail.summary.id,
            action: action,
            counterAmount: counterAmount,
          );
      ref.invalidate(customerOrderTrackingProvider(detail.summary.id));
      ref.invalidate(customerOrdersProvider);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Respons revisi ongkir diproses.')),
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

    final amountText = formatCurrency(deliveryFee);
    if (detail.deliveryFeeNegotiation?.isActiveShoppingTotalTransport == true) {
      return 'Total ongkir Nitip diperbarui menjadi $amountText.';
    }

    return 'Ongkir diperbarui menjadi $amountText.';
  }

  String? _deliveryFeeNoticeReason(
    CustomerOrderSummaryModel order,
    CustomerOrderDetailModel detail,
  ) {
    for (final rawReason in [
      detail.deliveryFeeChangeNote,
      order.deliveryFeeChangeNote,
    ]) {
      final reason = rawReason?.trim();
      if (reason != null && reason.isNotEmpty) {
        return reason;
      }
    }

    return null;
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
    final isTransfer =
        TrackOrderPresenter.normalizedPaymentMethod(order, detail) ==
        'TRANSFER';

    if (isCancelledWithFee) {
      return isPaid
          ? 'Penalty tempat gagal sudah tercatat.'
          : 'Bayar penalty tempat gagal sesuai nominal.';
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
        // Foto "toko tutup" yang tertaut ke sebuah stop kini tampil di tab
        // "Tempat N" masing-masing, jadi tidak diduplikasi di Ringkasan.
        .where(
          (proof) => !(proof.type == 'store_closed' &&
              proof.pickupLocationId != null),
        )
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
              'Bukti QRIS menunggu verifikasi driver/admin.',
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
          borderRadius: BorderRadius.circular(10),
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
    final paymentProofFeedback = detail.paymentProofFeedback;
    final isTransferProofRejected =
        isTransfer &&
        !isPaid &&
        paymentProofFeedback?.isRejected == true &&
        !hasPendingTransferProof;
    final paymentStatusText = isTransferProofRejected
        ? 'Ditolak'
        : hasPendingTransferProof && !isPaid
        ? 'Menunggu verifikasi'
        : paymentStatusLabel(detail.paymentStatus);
    final paymentStatusColor = _paymentStatusColor(
      detail.paymentStatus,
      isPaid: isPaid,
      hasPendingTransferProof: hasPendingTransferProof,
      isTransferProofRejected: isTransferProofRejected,
    );
    final paymentMessage = _paymentActionMessage(
      order: order,
      isPaid: isPaid,
      isTransfer: isTransfer,
      isCourier: isCourier,
      isCancelledWithFee: isCancelledWithFee,
      hasPendingTransferProof: hasPendingTransferProof,
      isTransferProofRejected: isTransferProofRejected,
    );

    return KeyedSubtree(
      key: _paymentFocusKey,
      child: _buildCard(
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
            if (isTransferProofRejected) ...[
              const SizedBox(height: 10),
              _buildRejectedPaymentProofNotice(paymentProofFeedback),
            ],
            if (!isPaid) ...[
              const SizedBox(height: 12),
              if (isTransfer && !hasPendingTransferProof) ...[
                _buildQrisPaymentPanel(context, ref),
                const SizedBox(height: 12),
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
                    label: Text(
                      isTransferProofRejected
                          ? 'Upload Ulang Bukti QRIS'
                          : 'Upload Bukti QRIS',
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _paymentCardSection(
    BuildContext context,
    WidgetRef ref,
    CustomerOrderSummaryModel order,
    CustomerOrderDetailModel detail,
    Future<void> Function()? onRefresh,
  ) {
    if (!TrackOrderPresenter.shouldShowCustomerPaymentCard(order, detail)) {
      return const <Widget>[];
    }

    return <Widget>[
      _buildPaymentCard(context, ref, order, detail, onRefresh),
      const SizedBox(height: 12),
    ];
  }

  Widget _buildQrisPaymentPanel(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: 'Preview QRIS Bang Deliv',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Material(
                color: AppColors.white,
                child: InkWell(
                  key: const ValueKey('qris-preview-thumbnail'),
                  onTap: () => showBangNetworkImagePreview(
                    context,
                    imageUrl: PaymentAssets.qrisUrl,
                  ),
                  child: SizedBox(
                    width: 72,
                    height: 92,
                    child: Image.network(
                      PaymentAssets.qrisUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.qr_code_2,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bayar dengan QRIS Bang Deliv',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Scan atau download QRIS, lalu upload bukti pembayaran.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _downloadQrisAsset(context, ref),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.download_outlined, size: 17),
                  label: const Text('Download QRIS'),
                ),
              ],
            ),
          ),
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
          borderRadius: BorderRadius.circular(10),
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
    required bool isTransferProofRejected,
  }) {
    if (isPaid) {
      return AppColors.success;
    }

    if (isTransferProofRejected) {
      return AppColors.error;
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

  Widget _buildRejectedPaymentProofNotice(PaymentProofFeedbackModel? feedback) {
    final reason = feedback?.displayReason;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bukti QRIS ditolak',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          if (reason != null) ...[
            const SizedBox(height: 4),
            Text(
              reason,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
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
        borderRadius: BorderRadius.circular(10),
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
    required bool isTransferProofRejected,
  }) {
    if (isCancelledWithFee) {
      if (isPaid) {
        return 'Fee pembatalan tempat sudah tercatat.';
      }
      return 'Bayar fee pembatalan tempat sebesar 50% dari ongkir aktif terakhir lewat QRIS.';
    }

    if (isTransfer) {
      if (isPaid) {
        return 'Pembayaran QRIS sudah diverifikasi.';
      }
      if (isTransferProofRejected) {
        return 'Upload ulang bukti QRIS agar pembayaran bisa dicek kembali.';
      }
      return hasPendingTransferProof
          ? 'Bukti QRIS menunggu verifikasi driver/admin.'
          : 'Scan QRIS Bang Deliv lalu upload bukti pembayaran agar driver/admin bisa memverifikasi.';
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
        const SnackBar(content: Text('Bukti QRIS berhasil diupload.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _downloadQrisAsset(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Mengunduh QRIS ke galeri...')),
    );

    try {
      await ref.read(qrisDownloadServiceProvider).downloadQrisToGallery();
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('QRIS tersimpan di galeri.')),
      );
    } on QrisDownloadException catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('QRIS gagal disimpan ke galeri.')),
      );
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
            showConnector: true,
          ),
          const SizedBox(height: 2),
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
      final showNumbers = stops.length > 1;
      return stops.indexed
          .map((entry) {
            final name = entry.$2.merchant.name.trim();
            final label = name.isEmpty || name == '-'
                ? 'Toko ${entry.$1 + 1}'
                : name;
            if (!showNumbers) {
              return label;
            }

            return '${entry.$1 + 1}. $label';
          })
          .join('\n');
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
                              borderRadius: BorderRadius.circular(10),
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
                            _statusHistoryTimestamp(item.changedAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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

  String _statusHistoryTimestamp(DateTime? value) {
    final formatted = formatDateMonthTime(value);
    return formatted == '-' ? formatted : '$formatted WIB';
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
        borderRadius: BorderRadius.circular(10),
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

  String? _driverVehicleLabel(CustomerOrderDetailModel detail) {
    final model = (detail.driverVehicleModel ?? '').trim();
    return model.isNotEmpty ? model : null;
  }

  String? _driverVehiclePlate(CustomerOrderDetailModel detail) {
    final plate = (detail.driverVehiclePlate ?? '').trim().toUpperCase();
    return plate.isEmpty ? null : plate;
  }
}
