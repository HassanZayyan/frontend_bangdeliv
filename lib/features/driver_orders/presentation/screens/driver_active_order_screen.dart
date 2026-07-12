import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/widgets/bang_async_state.dart';
import '../../../../models/driver_order_model.dart';
import '../../../../services/driver_order_service.dart';
import '../../../../services/customer_order_api_service.dart';
import '../../../../utils/order_formatters.dart';
import '../../../../utils/order_status.dart';
import '../../../../utils/service_type.dart';
import '../../../../utils/external_navigation_launcher.dart';
import '../../../../widgets/driver_transfer_payment_card.dart';
import '../../../../widgets/order_chat_badge_icon.dart';
import '../../../orders/application/order_chat_unread_provider.dart';
import '../../../shopping/presentation/screens/shopping_merchant_map_picker_screen.dart';
import '../../application/driver_location_reporter_provider.dart';
import '../../application/driver_order_providers.dart';
import '../models/driver_active_order_point.dart';
import 'driver_shopping_change_wizard_screen.dart';
import '../widgets/driver_active_order_action_widgets.dart';
import '../widgets/driver_active_order_map_widgets.dart';
import '../widgets/driver_active_order_meta_widgets.dart';
import '../widgets/driver_active_order_proof_widgets.dart';
import '../widgets/driver_active_order_shopping_widgets.dart';
import '../widgets/driver_active_order_widget_helpers.dart';
import '../widgets/driver_order_sheet_drag_region.dart';

class DriverActiveOrderScreen extends ConsumerStatefulWidget {
  final String orderId;

  const DriverActiveOrderScreen({super.key, required this.orderId});

  @override
  ConsumerState<DriverActiveOrderScreen> createState() =>
      _DriverActiveOrderScreenState();
}

const List<BoxShadow> _mapControlShadow = [
  BoxShadow(color: Color(0x26000000), blurRadius: 12, offset: Offset(0, 4)),
];

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.child,
    this.isLoading = false,
  }) : assert(icon != null || child != null);

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? child;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      child: Semantics(
        button: true,
        enabled: onPressed != null && !isLoading,
        label: isLoading ? 'Sedang memperbarui order' : tooltip,
        child: IconButton(
          tooltip: isLoading ? 'Sedang memperbarui order' : tooltip,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          onPressed: isLoading ? null : onPressed,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: isLoading
                ? const SizedBox(
                    key: ValueKey('driver-order-refresh-progress'),
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.primary,
                      semanticsLabel: 'Memperbarui data order',
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('driver-order-refresh-idle'),
                    child: child ?? Icon(icon, color: AppColors.textPrimary),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SheetPrimaryAction extends StatelessWidget {
  const _SheetPrimaryAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Icon(icon),
              label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.surfaceAlt,
                disabledForegroundColor: AppColors.textMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverActiveOrderScreenState
    extends ConsumerState<DriverActiveOrderScreen> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final GlobalKey<DriverShoppingItemsCardState> _shoppingCardKey = GlobalKey();
  final DriverShoppingItemsDraftStore _shoppingDraftStore =
      DriverShoppingItemsDraftStore();
  String? _selectedPointId;
  String? _lastActivePointId;
  bool _isRefreshingOrder = false;

  String get orderId => widget.orderId;

  // Dipakai untuk mengukur tinggi sticky action bar agar toast hasil aksi
  // driver muncul DI ATAS tombol aksi, bukan menutupinya. Khusus layar ini.
  static final GlobalKey _stickyActionBarKey = GlobalKey();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  DriverActiveOrderPoint _resolveSelectedPoint(
    List<DriverActiveOrderPoint> points,
    DriverActiveOrderPoint activePoint,
  ) {
    final previousActivePointId = _lastActivePointId;
    final activePointChanged = previousActivePointId != activePoint.id;
    final selectedStillExists = points.any(
      (point) => point.id == _selectedPointId,
    );

    if (!selectedStillExists ||
        _selectedPointId == null ||
        (activePointChanged && _selectedPointId == previousActivePointId)) {
      _selectedPointId = activePoint.id;
    }
    _lastActivePointId = activePoint.id;

    return points.firstWhere(
      (point) => point.id == _selectedPointId,
      orElse: () => activePoint,
    );
  }

  void _selectPoint(String pointId, {double? targetExtent}) {
    if (_selectedPointId != pointId) {
      setState(() => _selectedPointId = pointId);
    }
    final extent = targetExtent;
    if (extent == null || !_sheetController.isAttached) {
      return;
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _sheetController.jumpTo(extent);
      return;
    }
    unawaited(
      _sheetController.animateTo(
        extent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _refreshOrder(
    String id, {
    bool showResultFeedback = false,
  }) async {
    if (_isRefreshingOrder) {
      return;
    }

    setState(() => _isRefreshingOrder = true);
    try {
      await ref.read(driverOrderDetailRefreshProvider(id))();
      if (showResultFeedback && mounted) {
        _showActionSnackBar(
          context,
          message: 'Data order berhasil diperbarui.',
        );
      }
    } catch (error) {
      if (mounted) {
        _showActionSnackBar(
          context,
          message: _mapDetailError(error),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingOrder = false);
      }
    }
  }

  Widget _buildShoppingHistoryCard(DriverOrderModel order) {
    final historicalStops = order.shoppingStops
        .where(
          (stop) =>
              stop.isReplaced ||
              stop.isSkipped ||
              stop.isFailed ||
              stop.isAbandoned,
        )
        .toList(growable: false);
    if (historicalStops.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        leading: const Icon(Icons.history_rounded, color: AppColors.primary),
        title: const Text(
          'Riwayat toko/resto',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text('${historicalStops.length} toko/resto tidak aktif'),
        children: historicalStops
            .map(
              (stop) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  stop.isFailed || stop.isAbandoned
                      ? Icons.close_rounded
                      : Icons.swap_horiz_rounded,
                  color: stop.isFailed || stop.isAbandoned
                      ? AppColors.error
                      : AppColors.textSecondary,
                ),
                title: Text(stop.merchant.name),
                subtitle: Text(
                  stop.isAbandoned
                      ? 'Batas percobaan tercapai'
                      : stop.isFailed
                      ? 'Kunjungan gagal'
                      : stop.isReplaced
                      ? 'Diganti dengan toko/resto lain'
                      : 'Dilewati',
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildTopControls(
    BuildContext context, {
    required DriverOrderModel order,
    required int unreadCount,
  }) {
    final orderNumber = order.orderNumber.trim().isEmpty
        ? order.id
        : order.orderNumber.trim();
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              _MapControlButton(
                tooltip: 'Kembali',
                icon: Icons.arrow_back_rounded,
                onPressed: _handleBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                    boxShadow: _mapControlShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${serviceTypeLabel(order.serviceTypeCode)} • #$orderNumber',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        order.statusDisplayName ??
                            orderStatusLabel(order.statusCode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _MapControlButton(
                tooltip: 'Hubungi customer',
                onPressed: () =>
                    context.push(AppRoutes.orderChatPath(order.id)),
                child: OrderChatBadgeIcon(
                  unreadCount: unreadCount,
                  iconColor: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              _MapControlButton(
                tooltip: 'Refresh order',
                icon: Icons.refresh_rounded,
                isLoading: _isRefreshingOrder,
                onPressed: () => unawaited(
                  _refreshOrder(order.id, showResultFeedback: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionsButton(
    BuildContext context, {
    required DriverActiveOrderPoint selectedPoint,
    required double bottom,
  }) {
    final enabled = selectedPoint.hasCoordinates;
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom,
      child: Center(
        child: Semantics(
          button: true,
          enabled: enabled,
          label: enabled
              ? 'Buka petunjuk arah ke ${selectedPoint.title}'
              : 'Petunjuk arah tidak tersedia',
          child: FilledButton.icon(
            onPressed: enabled
                ? () => _openDirections(context, selectedPoint)
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              backgroundColor: AppColors.primaryDark,
              foregroundColor: AppColors.white,
              disabledBackgroundColor: AppColors.textMuted,
              shape: const StadiumBorder(),
              elevation: 5,
            ),
            icon: const Icon(Icons.navigation_rounded),
            label: const Text(
              'Petunjuk arah',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDirections(
    BuildContext context,
    DriverActiveOrderPoint point,
  ) async {
    final latitude = point.latitude;
    final longitude = point.longitude;
    if (latitude == null || longitude == null) {
      _showActionSnackBar(
        context,
        message: 'Koordinat tujuan belum tersedia.',
        isError: true,
      );
      return;
    }
    final opened = await launchGoogleMapsNavigation(
      latitude: latitude,
      longitude: longitude,
    );
    if (!opened && context.mounted) {
      _showActionSnackBar(
        context,
        message:
            'Google Maps tidak dapat dibuka. Coba lagi dari detail tujuan.',
        isError: true,
      );
    }
  }

  Widget _buildSheetHeader({
    required DriverOrderModel order,
    required List<DriverActiveOrderPoint> points,
    required DriverActiveOrderPoint selectedPoint,
    required DriverActiveOrderPoint activePoint,
    required VoidCallback onProblem,
  }) {
    final hasProblem = _hasProblemAction(order, selectedPoint, activePoint);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 6),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selectedPoint.id == activePoint.id
                      ? AppColors.primaryLight
                      : AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _pointIcon(selectedPoint),
                  size: 19,
                  color: selectedPoint.id == activePoint.id
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedPoint.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      selectedPoint.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: hasProblem
                    ? 'Masalah pada tugas ini'
                    : 'Tidak ada aksi masalah',
                onPressed: hasProblem ? onProblem : null,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                icon: const Icon(Icons.report_problem_outlined),
                color: AppColors.error,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            key: const ValueKey('driver-active-order-point-selector'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: points.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final point = points[index];
              final selected = point.id == selectedPoint.id;
              return Semantics(
                button: true,
                selected: selected,
                label: '${point.label}, ${point.subtitle}',
                child: ChoiceChip(
                  key: ValueKey('driver-order-point-${point.id}'),
                  selected: selected,
                  showCheckmark: point.isTerminal,
                  avatar: point.isFailed
                      ? const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.error,
                        )
                      : null,
                  label: Text(point.label),
                  onSelected: (_) => _selectPoint(point.id, targetExtent: 0.52),
                  selectedColor: AppColors.primaryLight,
                  side: BorderSide(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                  labelStyle: TextStyle(
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 7),
      ],
    );
  }

  IconData _pointIcon(DriverActiveOrderPoint point) {
    switch (point.kind) {
      case DriverActiveOrderPointKind.summary:
        return Icons.receipt_long_outlined;
      case DriverActiveOrderPointKind.pickup:
        return Icons.radio_button_checked_rounded;
      case DriverActiveOrderPointKind.merchant:
        return Icons.storefront_outlined;
      case DriverActiveOrderPointKind.dropoff:
        return Icons.location_on_outlined;
    }
  }

  bool _hasProblemAction(
    DriverOrderModel order,
    DriverActiveOrderPoint selectedPoint,
    DriverActiveOrderPoint activePoint,
  ) {
    final selectedStop = DriverActiveOrderPointPresenter.stopForPoint(
      order,
      selectedPoint,
    );
    if (selectedStop != null &&
        DriverActiveOrderPointPresenter.canStartPendingMerchant(
          order,
          selectedStop,
        )) {
      return true;
    }
    return selectedPoint.id == activePoint.id &&
        order.availableActions.any(_isProblemOrderAction);
  }

  bool _isProblemOrderAction(DriverOrderActionModel action) {
    final code = action.actionCode.toUpperCase();
    return code.contains('CANCEL') ||
        code.contains('INVALID') ||
        code.contains('FAILED') ||
        code.contains('REJECT') ||
        code.contains('PROBLEM');
  }

  Future<void> _showProblemMenu(
    BuildContext context, {
    required DriverOrderModel order,
    required DriverActiveOrderPoint selectedPoint,
    required DriverActiveOrderPoint activePoint,
    required DriverShoppingStopModel? selectedStop,
  }) async {
    final problemActions = selectedPoint.id == activePoint.id
        ? order.availableActions
              .where(_isProblemOrderAction)
              .toList(growable: false)
        : const <DriverOrderActionModel>[];
    final canCloseMerchant =
        selectedStop != null &&
        DriverActiveOrderPointPresenter.canStartPendingMerchant(
          order,
          selectedStop,
        );

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Laporkan masalah',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Aksi hanya tersedia sesuai status ${selectedPoint.label}.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (canCloseMerchant)
              ListTile(
                minTileHeight: 52,
                leading: const Icon(
                  Icons.store_mall_directory_outlined,
                  color: AppColors.error,
                ),
                title: const Text('Tempat tutup'),
                subtitle: const Text('Foto dan validasi lokasi tetap berlaku.'),
                onTap: () => Navigator.of(sheetContext).pop('merchant_closed'),
              ),
            ...problemActions.map(
              (action) => ListTile(
                minTileHeight: 52,
                enabled: !action.blocked,
                leading: const Icon(
                  Icons.report_gmailerrorred_outlined,
                  color: AppColors.error,
                ),
                title: Text(action.label),
                subtitle: action.blockedReason == null
                    ? null
                    : Text(action.blockedReason!),
                onTap: action.blocked
                    ? null
                    : () => Navigator.of(
                        sheetContext,
                      ).pop('action:${action.actionCode}'),
              ),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) {
      return;
    }
    if (choice == 'merchant_closed' && selectedStop != null) {
      await _shoppingCardKey.currentState?.showMerchantClosedFlow(
        selectedStop.pickupLocationId,
      );
      return;
    }
    if (choice.startsWith('action:')) {
      final code = choice.substring('action:'.length);
      for (final action in problemActions) {
        if (action.actionCode == code) {
          await _executeOrderAction(context, order, action);
          return;
        }
      }
    }
  }

  Widget _buildSheetFooter(
    BuildContext context, {
    required DriverOrderModel order,
    required DriverActiveOrderPoint selectedPoint,
    required DriverActiveOrderPoint activePoint,
    required DriverShoppingStopModel? selectedStop,
    required bool isOrderBusy,
    required bool Function(String actionKey) isProcessingAction,
  }) {
    if (selectedStop != null &&
        DriverActiveOrderPointPresenter.canStartPendingMerchant(
          order,
          selectedStop,
        )) {
      final actionKey = DriverOrderActionKeys.markShoppingMerchantOpen(
        order.id,
        selectedStop.pickupLocationId,
      );
      return _SheetPrimaryAction(
        label: 'Tempat buka',
        icon: Icons.storefront_outlined,
        isLoading: isProcessingAction(actionKey),
        onPressed: isOrderBusy
            ? null
            : () => _markMerchantOpen(order, selectedStop),
      );
    }

    if (selectedPoint.id != activePoint.id) {
      return _SheetPrimaryAction(
        label: 'Kembali ke tugas aktif: ${activePoint.label}',
        icon: Icons.near_me_outlined,
        onPressed: () => _selectPoint(activePoint.id, targetExtent: 0.52),
      );
    }

    final primaryActions = order.availableActions
        .where((action) => !_isProblemOrderAction(action))
        .take(1)
        .toList(growable: false);
    final footerOrder = order.copyWith(availableActions: primaryActions);
    if (!hasDriverOrderStickyActionBarContent(footerOrder)) {
      return const SizedBox.shrink();
    }
    return _buildStickyActionBar(
      context,
      ref,
      footerOrder,
      isOrderBusy,
      isProcessingAction(DriverOrderActionKeys.shoppingCheckout(order.id)),
      compactForSheet: true,
    );
  }

  Future<void> _markMerchantOpen(
    DriverOrderModel order,
    DriverShoppingStopModel stop,
  ) async {
    final error = await ref
        .read(driverOrdersProvider.notifier)
        .markShoppingMerchantOpen(
          orderId: order.id,
          pickupLocationId: stop.pickupLocationId,
        );
    if (!mounted) {
      return;
    }
    _showActionSnackBar(
      context,
      message: error ?? 'Toko/resto dikonfirmasi buka.',
      isError: error != null,
    );
    if (error == null) {
      ref.invalidate(driverOrderDetailProvider(order.id));
    }
  }

  // Menampilkan snackbar hasil aksi driver dengan margin bawah yang menyesuaikan
  // tinggi tombol aksi (sticky action bar). Jika tombol aksi tidak tampil, jatuh
  // kembali ke inset default (di atas floating bottom nav).
  void _showActionSnackBar(
    BuildContext context, {
    required String message,
    bool isError = false,
  }) {
    showDriverActiveOrderSnackBar(
      context,
      message: message,
      isError: isError,
      stickyActionBarKey: _stickyActionBarKey,
    );
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }

    context.go(AppRoutes.driverHome);
  }

  Widget _buildBackNavigationGuard() {
    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _handleBack();
      },
      child: const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (orderId.trim().isEmpty || !_isServerOrderId(orderId)) {
      return Scaffold(
        body: const Center(
          child: Text('Order ID tidak valid untuk data server.'),
        ),
        bottomNavigationBar: _buildBackNavigationGuard(),
      );
    }

    final detailState = ref.watch(driverOrderDetailProvider(orderId));
    final pendingSnackBarMessage = ref.watch(
      driverActiveOrderSnackBarMessageProvider,
    );
    ref.watch(driverOrderDetailRealtimeProvider(orderId));
    ref.watch(driverOrderDetailReconciliationProvider(orderId));
    final ordersState = ref.watch(driverOrdersProvider);
    final ordersSnapshot = ordersState.asData?.value;
    final isOrderBusy = ordersSnapshot?.isProcessing(orderId) ?? false;
    bool isProcessingAction(String actionKey) {
      return ordersSnapshot?.isProcessingAction(actionKey) ?? false;
    }

    final parsedOrderId = int.tryParse(orderId);
    final unreadCountAsync = parsedOrderId == null
        ? const AsyncData<int>(0)
        : ref.watch(orderChatUnreadCountProvider(parsedOrderId));
    final unreadCount = unreadCountAsync.asData?.value ?? 0;

    if (pendingSnackBarMessage != null && detailState.asData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }

        final message = ref.read(driverActiveOrderSnackBarMessageProvider);
        if (message == null) {
          return;
        }

        ref.read(driverActiveOrderSnackBarMessageProvider.notifier).clear();
        _showActionSnackBar(context, message: message);
      });
    }

    return DriverActiveOrderSnackBarScope(
      stickyActionBarKey: _stickyActionBarKey,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: detailState.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          skipError: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            return BangErrorState(
              message: _mapDetailError(error),
              onRetry: () {
                unawaited(_refreshOrder(orderId));
              },
            );
          },
          data: (order) {
            final locationState = ref.watch(driverLocationReporterProvider);
            final latestPosition = locationState.activeOrderId == order.id
                ? locationState.latestPosition
                : null;
            final driverPosition = latestPosition == null
                ? null
                : LatLng(latestPosition.latitude, latestPosition.longitude);

            final points = DriverActiveOrderPointPresenter.build(order);
            final activePoint = DriverActiveOrderPointPresenter.activePoint(
              order,
              points,
            );
            final selectedPoint = _resolveSelectedPoint(points, activePoint);
            final selectedStop = DriverActiveOrderPointPresenter.stopForPoint(
              order,
              selectedPoint,
            );
            final isSummary = selectedPoint.isSummary;
            final isPickup =
                selectedPoint.kind == DriverActiveOrderPointKind.pickup;
            final isDropoff = selectedPoint.isDropoff;
            final isMerchant = selectedPoint.isMerchant;
            return LayoutBuilder(
              builder: (context, constraints) {
                final minExtent = (232 / constraints.maxHeight).clamp(
                  0.28,
                  0.38,
                );
                const mediumExtent = 0.52;
                const maxExtent = 0.94;

                return Stack(
                  children: [
                    Positioned.fill(
                      child: DriverActiveOrderMapCard(
                        order: order,
                        driverPosition: driverPosition,
                        points: points,
                        selectedPointId: selectedPoint.id,
                        onPointSelected: (pointId) =>
                            _selectPoint(pointId, targetExtent: mediumExtent),
                        fullBleed: true,
                        mapTopPadding: MediaQuery.paddingOf(context).top + 72,
                        mapBottomPadding:
                            constraints.maxHeight * minExtent + 64,
                      ),
                    ),
                    _buildTopControls(
                      context,
                      order: order,
                      unreadCount: unreadCount,
                    ),
                    _buildDirectionsButton(
                      context,
                      selectedPoint: selectedPoint,
                      bottom: constraints.maxHeight * minExtent + 16,
                    ),
                    DraggableScrollableSheet(
                      controller: _sheetController,
                      initialChildSize: minExtent,
                      minChildSize: minExtent,
                      maxChildSize: maxExtent,
                      snap: true,
                      snapSizes: const [mediumExtent],
                      snapAnimationDuration: const Duration(milliseconds: 220),
                      builder: (context, scrollController) {
                        return Material(
                          color: AppColors.white,
                          elevation: 16,
                          shadowColor: Colors.black.withValues(alpha: 0.16),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              DriverOrderSheetDragRegion(
                                key: const ValueKey(
                                  'driver-order-sheet-drag-region',
                                ),
                                controller: _sheetController,
                                minExtent: minExtent,
                                mediumExtent: mediumExtent,
                                maxExtent: maxExtent,
                                snapDuration: const Duration(milliseconds: 220),
                                child: _buildSheetHeader(
                                  order: order,
                                  points: points,
                                  selectedPoint: selectedPoint,
                                  activePoint: activePoint,
                                  onProblem: () => _showProblemMenu(
                                    context,
                                    order: order,
                                    selectedPoint: selectedPoint,
                                    activePoint: activePoint,
                                    selectedStop: selectedStop,
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: RefreshIndicator(
                                  onRefresh: () => _refreshOrder(order.id),
                                  child: ListView(
                                    controller: scrollController,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(
                                          parent: ClampingScrollPhysics(),
                                        ),
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      14,
                                      16,
                                      24,
                                    ),
                                    children: [
                                      if (isSummary ||
                                          isPickup ||
                                          isDropoff) ...[
                                        DriverOrderCustomerCard(order: order),
                                        const SizedBox(height: 12),
                                      ],
                                      if (isSummary) ...[
                                        DriverOrderRouteCard(order: order),
                                        const SizedBox(height: 12),
                                        if (normalizeServiceTypeCode(
                                              order.serviceTypeCode,
                                            ) ==
                                            ServiceTypeCodes.shopping) ...[
                                          _buildShoppingHistoryCard(order),
                                          const SizedBox(height: 12),
                                        ],
                                      ],
                                      if (normalizeServiceTypeCode(
                                                order.serviceTypeCode,
                                              ) ==
                                              ServiceTypeCodes.courier &&
                                          (isSummary || isPickup)) ...[
                                        DriverOrderPackageCard(order: order),
                                        const SizedBox(height: 12),
                                      ],
                                      if (isSummary)
                                        Builder(
                                          builder: (context) {
                                            final canEditDeliveryFee =
                                                order
                                                    .deliveryFeeNegotiation
                                                    ?.canDriverSubmitQuote ==
                                                true;
                                            final canAcceptDeliveryFeeCounter =
                                                order
                                                    .deliveryFeeNegotiation
                                                    ?.canDriverAcceptCounter ==
                                                true;
                                            final canBypassDeliveryFee =
                                                order
                                                    .deliveryFeeNegotiation
                                                    ?.isPendingCustomer ==
                                                true;

                                            return DriverOrderPricingCard(
                                              order: order,
                                              isProcessing: isProcessingAction(
                                                DriverOrderActionKeys.updateFee(
                                                  order.id,
                                                ),
                                              ),
                                              isAcceptingDeliveryFeeCounter:
                                                  isProcessingAction(
                                                    DriverOrderActionKeys.acceptDeliveryFeeCounter(
                                                      order.id,
                                                    ),
                                                  ),
                                              isBypassingDeliveryFee:
                                                  isProcessingAction(
                                                    DriverOrderActionKeys.bypassDeliveryFee(
                                                      order.id,
                                                    ),
                                                  ),
                                              onEditDeliveryFee:
                                                  canEditDeliveryFee
                                                  ? ({
                                                      required amount,
                                                      required reason,
                                                    }) async {
                                                      final error = await ref
                                                          .read(
                                                            driverOrdersProvider
                                                                .notifier,
                                                          )
                                                          .updateDeliveryFeeOverride(
                                                            orderId: order.id,
                                                            amount: amount,
                                                            reason: reason,
                                                          );
                                                      if (error == null) {
                                                        ref.invalidate(
                                                          driverOrderDetailProvider(
                                                            order.id,
                                                          ),
                                                        );
                                                      }
                                                      return error;
                                                    }
                                                  : null,
                                              onAcceptDeliveryFeeCounter:
                                                  canAcceptDeliveryFeeCounter
                                                  ? () async {
                                                      final error = await ref
                                                          .read(
                                                            driverOrdersProvider
                                                                .notifier,
                                                          )
                                                          .acceptDeliveryFeeCounterOffer(
                                                            orderId: order.id,
                                                          );

                                                      if (!context.mounted) {
                                                        return;
                                                      }

                                                      _showActionSnackBar(
                                                        context,
                                                        message:
                                                            error ??
                                                            'Tawaran ongkir customer disetujui.',
                                                        isError: error != null,
                                                      );
                                                      if (error == null) {
                                                        ref.invalidate(
                                                          driverOrderDetailProvider(
                                                            order.id,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  : null,
                                              onBypassDeliveryFee:
                                                  canBypassDeliveryFee
                                                  ? () async {
                                                      final error = await ref
                                                          .read(
                                                            driverOrdersProvider
                                                                .notifier,
                                                          )
                                                          .bypassDeliveryFeeOverride(
                                                            orderId: order.id,
                                                          );

                                                      if (!context.mounted) {
                                                        return;
                                                      }

                                                      _showActionSnackBar(
                                                        context,
                                                        message:
                                                            error ??
                                                            'Persetujuan ongkir customer dibypass.',
                                                        isError: error != null,
                                                      );
                                                      if (error == null) {
                                                        ref.invalidate(
                                                          driverOrderDetailProvider(
                                                            order.id,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  : null,
                                            );
                                          },
                                        ),
                                      const SizedBox(height: 12),
                                      if (normalizeServiceTypeCode(
                                                order.serviceTypeCode,
                                              ) ==
                                              ServiceTypeCodes.courier &&
                                          (isSummary ||
                                              isPickup ||
                                              isDropoff)) ...[
                                        DriverOrderProofChecklistCard(
                                          order: order,
                                          isOrderBusy: isOrderBusy,
                                          isProofUploading: (type) =>
                                              isProcessingAction(
                                                DriverOrderActionKeys.uploadProof(
                                                  order.id,
                                                  type,
                                                ),
                                              ),
                                          onUploadProof:
                                              ({
                                                required type,
                                                required photo,
                                                note,
                                                pickupLocationId,
                                              }) {
                                                return ref
                                                    .read(
                                                      driverOrdersProvider
                                                          .notifier,
                                                    )
                                                    .uploadProof(
                                                      orderId: order.id,
                                                      type: type,
                                                      photo: photo,
                                                      note: note,
                                                      pickupLocationId:
                                                          pickupLocationId,
                                                    );
                                              },
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      if (isMerchant &&
                                          selectedStop != null) ...[
                                        if (DriverShoppingItemChangeRequestCard.shouldShow(
                                          order,
                                        )) ...[
                                          DriverShoppingItemChangeRequestCard(
                                            request: order
                                                .shoppingItemChangeRequest!,
                                            isOrderBusy: isOrderBusy,
                                            isApproving: isProcessingAction(
                                              DriverOrderActionKeys.respondShoppingItemChange(
                                                order.id,
                                                'APPROVE',
                                              ),
                                            ),
                                            isRejecting: isProcessingAction(
                                              DriverOrderActionKeys.respondShoppingItemChange(
                                                order.id,
                                                'REJECT',
                                              ),
                                            ),
                                            onRespond: (action) async {
                                              final error = await ref
                                                  .read(
                                                    driverOrdersProvider
                                                        .notifier,
                                                  )
                                                  .respondShoppingItemChange(
                                                    orderId: order.id,
                                                    action: action,
                                                  );
                                              if (error == null) {
                                                ref.invalidate(
                                                  driverOrderDetailProvider(
                                                    order.id,
                                                  ),
                                                );
                                              }
                                              return error;
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        DriverShoppingItemsCard(
                                          key: _shoppingCardKey,
                                          order: order,
                                          selectedPickupLocationId:
                                              selectedStop.pickupLocationId,
                                          mapFirstMode: true,
                                          readOnly:
                                              selectedStop.fulfillmentStatus
                                                      .toUpperCase() ==
                                                  'PENDING'
                                              ? !DriverActiveOrderPointPresenter.canStartPendingMerchant(
                                                  order,
                                                  selectedStop,
                                                )
                                              : selectedPoint.id !=
                                                    activePoint.id,
                                          draftStore: _shoppingDraftStore,
                                          isOrderBusy: isOrderBusy,
                                          isSavingItems: (pickupLocationId) =>
                                              isProcessingAction(
                                                DriverOrderActionKeys.updateShoppingItems(
                                                  order.id,
                                                  pickupLocationId,
                                                ),
                                              ),
                                          canEditAvailability: order
                                              .shoppingCapabilities
                                              .canDriverUpdateItemAvailability,
                                          canUploadReceipt: order
                                              .shoppingCapabilities
                                              .canDriverUploadReceipt,
                                          isSubmittingQuote:
                                              (
                                                pickupLocationId,
                                              ) => isProcessingAction(
                                                DriverOrderActionKeys.shoppingPriceQuote(
                                                  order.id,
                                                  pickupLocationId,
                                                ),
                                              ),
                                          isBypassingPrice:
                                              (
                                                pickupLocationId,
                                              ) => isProcessingAction(
                                                DriverOrderActionKeys.bypassShoppingPrice(
                                                  order.id,
                                                  pickupLocationId,
                                                ),
                                              ),
                                          isBypassingUnavailableItems:
                                              (
                                                pickupLocationId,
                                              ) => isProcessingAction(
                                                DriverOrderActionKeys.bypassUnavailableItems(
                                                  order.id,
                                                  pickupLocationId,
                                                ),
                                              ),
                                          isDecidingUnavailableItems:
                                              (
                                                pickupLocationId,
                                                action,
                                              ) => isProcessingAction(
                                                DriverOrderActionKeys.decideUnavailableItems(
                                                  order.id,
                                                  pickupLocationId,
                                                  action,
                                                ),
                                              ),
                                          isMarkingMerchantOpen:
                                              (
                                                pickupLocationId,
                                              ) => isProcessingAction(
                                                DriverOrderActionKeys.markShoppingMerchantOpen(
                                                  order.id,
                                                  pickupLocationId,
                                                ),
                                              ),
                                          isClosingMerchant:
                                              (
                                                pickupLocationId,
                                              ) => isProcessingAction(
                                                DriverOrderActionKeys.pickupFailed(
                                                  order.id,
                                                  pickupLocationId,
                                                ),
                                              ),
                                          isDeliveryFeeRevisionPending:
                                              order
                                                  .deliveryFeeNegotiation
                                                  ?.isPending ==
                                              true,
                                          onUploadReceipt: (photo) {
                                            return ref
                                                .read(
                                                  driverOrdersProvider.notifier,
                                                )
                                                .uploadProof(
                                                  orderId: order.id,
                                                  type: 'receipt',
                                                  photo: photo,
                                                );
                                          },
                                          onSubmitQuote:
                                              ({
                                                required amount,
                                                pickupLocationId,
                                              }) async {
                                                final error = await ref
                                                    .read(
                                                      driverOrdersProvider
                                                          .notifier,
                                                    )
                                                    .submitShoppingPriceQuote(
                                                      orderId: order.id,
                                                      amount: amount,
                                                      pickupLocationId:
                                                          pickupLocationId,
                                                    );
                                                if (error == null) {
                                                  ref.invalidate(
                                                    driverOrderDetailProvider(
                                                      order.id,
                                                    ),
                                                  );
                                                }
                                                return error;
                                              },
                                          onBypassPrice:
                                              ({
                                                required pickupLocationId,
                                              }) async {
                                                final error = await ref
                                                    .read(
                                                      driverOrdersProvider
                                                          .notifier,
                                                    )
                                                    .bypassShoppingPriceQuote(
                                                      orderId: order.id,
                                                      pickupLocationId:
                                                          pickupLocationId,
                                                    );
                                                if (error == null) {
                                                  ref.invalidate(
                                                    driverOrderDetailProvider(
                                                      order.id,
                                                    ),
                                                  );
                                                }
                                                return error;
                                              },
                                          onBypassUnavailableItems:
                                              ({
                                                required pickupLocationId,
                                              }) async {
                                                final error = await ref
                                                    .read(
                                                      driverOrdersProvider
                                                          .notifier,
                                                    )
                                                    .bypassUnavailableShoppingItems(
                                                      orderId: order.id,
                                                      pickupLocationId:
                                                          pickupLocationId,
                                                    );
                                                if (error == null) {
                                                  ref.invalidate(
                                                    driverOrderDetailProvider(
                                                      order.id,
                                                    ),
                                                  );
                                                }
                                                return error;
                                              },
                                          onDecideUnavailableItems:
                                              ({
                                                required pickupLocationId,
                                                required action,
                                                required itemIds,
                                              }) async {
                                                final error = await ref
                                                    .read(
                                                      driverOrdersProvider
                                                          .notifier,
                                                    )
                                                    .decideUnavailableShoppingItems(
                                                      orderId: order.id,
                                                      pickupLocationId:
                                                          pickupLocationId,
                                                      action: action,
                                                      itemIds: itemIds,
                                                    );
                                                ref.invalidate(
                                                  driverOrderDetailProvider(
                                                    order.id,
                                                  ),
                                                );
                                                return error;
                                              },
                                          onMarkMerchantOpen:
                                              ({
                                                required pickupLocationId,
                                              }) async {
                                                final error = await ref
                                                    .read(
                                                      driverOrdersProvider
                                                          .notifier,
                                                    )
                                                    .markShoppingMerchantOpen(
                                                      orderId: order.id,
                                                      pickupLocationId:
                                                          pickupLocationId,
                                                    );
                                                if (error == null) {
                                                  ref.invalidate(
                                                    driverOrderDetailProvider(
                                                      order.id,
                                                    ),
                                                  );
                                                }
                                                return error;
                                              },
                                          onMarkMerchantClosed:
                                              ({
                                                required pickupLocationId,
                                                required reason,
                                                storeClosedPhoto,
                                              }) async {
                                                final error = await ref
                                                    .read(
                                                      driverOrdersProvider
                                                          .notifier,
                                                    )
                                                    .recordShoppingPickupFailed(
                                                      orderId: order.id,
                                                      pickupLocationId:
                                                          pickupLocationId,
                                                      reason: reason,
                                                      storeClosedPhoto:
                                                          storeClosedPhoto,
                                                    );
                                                if (error == null) {
                                                  ref.invalidate(
                                                    driverOrderDetailProvider(
                                                      order.id,
                                                    ),
                                                  );
                                                }
                                                return error;
                                              },
                                          onReplaceMerchant: (stop) =>
                                              _replaceShoppingMerchant(
                                                context,
                                                ref,
                                                order,
                                                stop,
                                              ),
                                          onReplaceUnavailableItems: (stop) =>
                                              _replaceUnavailableShoppingItems(
                                                context,
                                                ref,
                                                order,
                                                stop,
                                              ),
                                          onSaveItems:
                                              (items, pickupLocationId) async {
                                                final error = await ref
                                                    .read(
                                                      driverOrdersProvider
                                                          .notifier,
                                                    )
                                                    .updateShoppingItems(
                                                      orderId: order.id,
                                                      items: items,
                                                      pickupLocationId:
                                                          pickupLocationId,
                                                    );

                                                if (error == null) {
                                                  ref.invalidate(
                                                    driverOrderDetailProvider(
                                                      order.id,
                                                    ),
                                                  );
                                                }

                                                return error;
                                              },
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      if ((isSummary || isDropoff) &&
                                          DriverTransferPaymentCard.shouldShow(
                                            order,
                                          )) ...[
                                        DriverTransferPaymentCard(
                                          order: order,
                                          isOrderBusy: isOrderBusy,
                                          isConfirmingQris: isProcessingAction(
                                            DriverOrderActionKeys.confirmQris(
                                              order.id,
                                            ),
                                          ),
                                          isRejectingQris: isProcessingAction(
                                            DriverOrderActionKeys.rejectQris(
                                              order.id,
                                            ),
                                          ),
                                          onConfirmTransfer:
                                              ({required amount}) async {
                                                final error = await ref
                                                    .read(
                                                      driverOrdersProvider
                                                          .notifier,
                                                    )
                                                    .confirmTransferPayment(
                                                      orderId: order.id,
                                                      amount: amount,
                                                    );

                                                if (!context.mounted) {
                                                  return;
                                                }

                                                _showActionSnackBar(
                                                  context,
                                                  message:
                                                      error ??
                                                      'Pembayaran QRIS berhasil diverifikasi.',
                                                  isError: error != null,
                                                );
                                                if (error == null) {
                                                  ref.invalidate(
                                                    driverOrderDetailProvider(
                                                      order.id,
                                                    ),
                                                  );
                                                }
                                              },
                                          onRejectTransfer:
                                              ({required reason}) async {
                                                final error = await ref
                                                    .read(
                                                      driverOrdersProvider
                                                          .notifier,
                                                    )
                                                    .rejectTransferPayment(
                                                      orderId: order.id,
                                                      reason: reason,
                                                    );

                                                if (!context.mounted) {
                                                  return;
                                                }

                                                _showActionSnackBar(
                                                  context,
                                                  message:
                                                      error ??
                                                      'Bukti QRIS ditolak.',
                                                  isError: error != null,
                                                );
                                                if (error == null) {
                                                  ref.invalidate(
                                                    driverOrderDetailProvider(
                                                      order.id,
                                                    ),
                                                  );
                                                }
                                              },
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      if (isSummary) ...[
                                        DriverOrderTimelineCard(
                                          timeline: order.statusTimeline,
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              _buildSheetFooter(
                                context,
                                order: order,
                                selectedPoint: selectedPoint,
                                activePoint: activePoint,
                                selectedStop: selectedStop,
                                isOrderBusy: isOrderBusy,
                                isProcessingAction: isProcessingAction,
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
          },
        ),
        bottomNavigationBar: _buildBackNavigationGuard(),
      ),
    );
  }

  Future<String?> _replaceShoppingMerchant(
    BuildContext context,
    WidgetRef ref,
    DriverOrderModel order,
    DriverShoppingStopModel stop,
  ) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DriverShoppingChangeWizardScreen(
          order: order,
          stop: stop,
          replaceMerchant: true,
        ),
      ),
    );
    if (changed == true && context.mounted) {
      ref.invalidate(driverOrderDetailProvider(order.id));
      ref.invalidate(driverOrdersProvider);
      _showActionSnackBar(
        context,
        message: 'Toko/resto berhasil diganti. Rute dan ongkir diperbarui.',
      );
    }
    return null;
  }

  Future<String?> _replaceUnavailableShoppingItems(
    BuildContext context,
    WidgetRef ref,
    DriverOrderModel order,
    DriverShoppingStopModel stop,
  ) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DriverShoppingChangeWizardScreen(
          order: order,
          stop: stop,
          replaceMerchant: false,
        ),
      ),
    );
    if (changed == true && context.mounted) {
      ref.invalidate(driverOrderDetailProvider(order.id));
      ref.invalidate(driverOrdersProvider);
      _showActionSnackBar(
        context,
        message: 'Item tidak tersedia berhasil diganti.',
      );
    }
    return null;
  }

  // Kept temporarily as a compatibility reference while the staged wizard is
  // exercised by existing widget tests.
  // ignore: unused_element
  Future<String?> _replaceShoppingMerchantLegacy(
    BuildContext context,
    WidgetRef ref,
    DriverOrderModel order,
    DriverShoppingStopModel stop,
  ) async {
    final pickerResult = await context.push<ShoppingMerchantPickerResult>(
      AppRoutes.shoppingMerchantMapPickerPath(order.id),
      extra: ShoppingMerchantMapPickerArgs(
        initialLatitude: stop.merchant.latitude,
        initialLongitude: stop.merchant.longitude,
      ),
    );
    if (pickerResult == null || !context.mounted) {
      return null;
    }

    final items = stop.items
        .map(
          (item) => ShoppingItemDraftPayload(
            merchantId: pickerResult.merchantId,
            merchantPlace: pickerResult.isOfficial ? null : pickerResult.place,
            itemSource: 'MANUAL',
            name: item.name,
            quantity: item.quantity <= 0 ? 1 : item.quantity,
            notes: item.notes,
          ),
        )
        .toList(growable: false);

    try {
      final repository = ref.read(driverOrderRepositoryProvider);
      final preview = await repository.previewShoppingMerchantReplacement(
        orderId: order.id,
        pickupLocationId: stop.pickupLocationId,
        expectedVersion: stop.stateVersion,
        merchantId: pickerResult.merchantId,
        merchantPlace: pickerResult.isOfficial ? null : pickerResult.place,
        items: items,
      );
      if (!context.mounted) {
        return null;
      }
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Review ganti toko/resto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${preview.oldMerchantName} → ${preview.newMerchantName}',
                    ),
                    const SizedBox(height: 8),
                    Text('${preview.items.length} item baru dipilih.'),
                    const SizedBox(height: 12),
                    Text(
                      'Ongkir aktif: ${formatCurrency(preview.activeDeliveryFee)}',
                    ),
                    if (preview.failedTripCompensation > 0)
                      Text(
                        'Kompensasi gagal: ${formatCurrency(preview.failedTripCompensation)}',
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Total transport: ${formatCurrency(preview.totalTransport)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text('Percobaan berikutnya ${preview.nextAttemptNo}/3.'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Ganti toko/resto'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) {
        return null;
      }

      await repository.replaceShoppingMerchant(
        orderId: order.id,
        pickupLocationId: stop.pickupLocationId,
        expectedVersion: preview.expectedVersion,
        idempotencyKey:
            '${order.id}-${stop.pickupLocationId}-${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 32)}',
        merchantId: pickerResult.merchantId,
        merchantPlace: pickerResult.isOfficial ? null : pickerResult.place,
        items: items,
      );
      ref.invalidate(driverOrderDetailProvider(order.id));
      ref.invalidate(driverOrdersProvider);
      if (context.mounted) {
        _showActionSnackBar(
          context,
          message: 'Toko/resto berhasil diganti. Rute dan ongkir diperbarui.',
        );
      }
      return null;
    } on DriverOrderApiException catch (error) {
      if (error.statusCode == 409) {
        ref.invalidate(driverOrderDetailProvider(order.id));
        ref.invalidate(driverOrdersProvider);
        return 'Keputusan toko/resto sudah diambil pihak lain. Detail order dimuat ulang.';
      }
      return error.message;
    } catch (error) {
      return error.toString();
    }
  }

  Widget _buildStickyActionBar(
    BuildContext context,
    WidgetRef ref,
    DriverOrderModel order,
    bool isProcessing,
    bool isSavingShoppingCheckout, {
    bool compactForSheet = false,
  }) {
    return DriverOrderStickyActionBar(
      key: _stickyActionBarKey,
      order: order,
      isProcessing: isProcessing,
      isSavingShoppingCheckout: isSavingShoppingCheckout,
      compactForSheet: compactForSheet,
      singlePrimaryAction: compactForSheet,
      onSaveShoppingCheckout: () async {
        final error = await ref
            .read(driverOrdersProvider.notifier)
            .updateShoppingCheckout(
              orderId: order.id,
              items: _shoppingCheckoutItemPayload(order),
            );

        if (!context.mounted) {
          return;
        }

        if (error == null) {
          _showActionSnackBar(
            context,
            message: 'Checkout nitip berhasil disimpan.',
          );
          ref.invalidate(driverOrderDetailProvider(order.id));
          try {
            await ref.read(driverOrderDetailProvider(order.id).future);
          } catch (_) {
            if (!context.mounted) {
              return;
            }

            _showActionSnackBar(
              context,
              message:
                  'Checkout tersimpan, tapi detail order belum berhasil dimuat ulang. Tarik layar untuk refresh.',
              isError: true,
            );
          }
          return;
        }

        _showActionSnackBar(context, message: error, isError: true);
      },
      onTapAction: (action) => _executeOrderAction(context, order, action),
    );
  }

  Future<void> _executeOrderAction(
    BuildContext context,
    DriverOrderModel order,
    DriverOrderActionModel action,
  ) async {
    final notifier = ref.read(driverOrdersProvider.notifier);

    String? error;
    if (action.isCodCollection) {
      error = await notifier.collectCod(
        orderId: order.id,
        amount: order.totalPrice,
        note:
            normalizeServiceTypeCode(order.serviceTypeCode) ==
                ServiceTypeCodes.courier
            ? 'Pembayaran courier dicatat saat pickup dari app driver.'
            : 'Pembayaran COD dicatat dari app driver.',
      );
    } else {
      error = await notifier.transitionOrderStatus(
        orderId: order.id,
        actionCode: action.actionCode,
        targetStatusCode: action.targetStatusCode,
      );
    }

    if (!context.mounted) {
      return;
    }

    if (error == null) {
      _showActionSnackBar(context, message: '${action.label} berhasil.');
      ref.invalidate(driverOrderDetailProvider(order.id));
      if (action.targetStatusCode != null &&
          !isDriverRunningOrderStatus(action.targetStatusCode!)) {
        context.go(AppRoutes.driverOrders);
      }
      return;
    }

    _showActionSnackBar(context, message: error, isError: true);
  }

  bool _isServerOrderId(String raw) {
    return RegExp(r'^\d+$').hasMatch(raw.trim());
  }

  String _mapDetailError(Object error) {
    if (error is DriverOrderApiException) {
      if (error.statusCode == 404) {
        return 'Order tidak ditemukan di server. Coba refresh daftar order.';
      }

      return error.message;
    }

    return error.toString();
  }

  List<Map<String, dynamic>> _shoppingCheckoutItemPayload(
    DriverOrderModel order,
  ) {
    return order.shoppingItems
        .map(
          (item) => <String, dynamic>{
            'id': item.id,
            'quantity': item.quantity,
            'is_available': item.isAvailable,
            'notes': item.notes,
          },
        )
        .toList(growable: false);
  }
}
