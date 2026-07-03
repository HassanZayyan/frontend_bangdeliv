import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../core/widgets/bang_async_state.dart';
import '../../../../models/driver_order_model.dart';
import '../../../navigation/presentation/widgets/bang_floating_bottom_nav_bar.dart';
import '../../application/driver_dispatch_presenter.dart';
import '../../application/driver_order_providers.dart';
import '../../../../utils/courier_package_formatter.dart';
import '../../../../utils/order_formatters.dart';
import '../../../../utils/order_ui_helpers.dart';
import '../../../../utils/service_type.dart';
import '../../../../widgets/bang_ui.dart' show BangIllustrationEmptyState;
import '../../../../widgets/profile_avatar.dart';

class DriverOrdersScreen extends ConsumerWidget {
  const DriverOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersState = ref.watch(driverOrdersProvider);
    final availabilityState = ref.watch(driverAvailabilityProvider);
    final availabilityStatus =
        availabilityState.asData?.value.status ?? 'offline';
    final canReceiveIncomingOrders = _canReceiveIncomingOrders(
      availabilityStatus,
    );
    final activeOrder = ordersState.asData?.value.running.firstOrNull;
    if (activeOrder != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(AppRoutes.driverOrderActivePath(activeOrder.id));
        }
      });

      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Orderan Driver',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        automaticallyImplyLeading: false,
      ),
      body: ordersState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          return BangErrorState(
            message: error.toString(),
            onRetry: () {
              ref.read(driverOrdersProvider.notifier).refresh();
            },
          );
        },
        data: (data) {
          return _IncomingOrdersList(
            orders: data.incoming,
            processingOrderIds: data.processingOrderIds,
            canReceiveIncomingOrders: canReceiveIncomingOrders,
            availabilityStatus: availabilityStatus,
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

class _IncomingOrdersList extends ConsumerWidget {
  final List<DriverOrderModel> orders;
  final Set<String> processingOrderIds;
  final bool canReceiveIncomingOrders;
  final String availabilityStatus;

  const _IncomingOrdersList({
    required this.orders,
    required this.processingOrderIds,
    required this.canReceiveIncomingOrders,
    required this.availabilityStatus,
  });

  bool _isServerOrderId(String orderId) {
    return RegExp(r'^\d+$').hasMatch(orderId.trim());
  }

  String _acceptErrorMessage(DriverOrderAcceptResult result) {
    if (result.isStaleOrder) {
      return 'Orderan ini sudah diambil driver lain.';
    }

    return result.error ?? 'Gagal menerima order.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      final normalizedStatus = availabilityStatus.trim().toLowerCase();
      final isBusy = normalizedStatus == 'busy';

      if (canReceiveIncomingOrders) {
        return const BangIllustrationEmptyState(
          title: 'Belum ada orderan masuk',
          subtitle: '',
          titleFontSize: 13,
          titleFontWeight: FontWeight.w500,
          titleColor: AppColors.textSecondary,
        );
      }

      return _EmptyOrderState(
        icon: isBusy ? Icons.delivery_dining : Icons.power_settings_new,
        title: isBusy ? 'Sedang menjalankan order' : 'Status kerja offline',
        action: isBusy
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
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          BangFloatingBottomNavBar.scrollClearance,
        ),
        itemCount: orders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final order = orders[index];
          final isProcessing = processingOrderIds.contains(order.id);

          return _OrderCard(
            order: order,
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
                        await ref.read(driverOrdersProvider.notifier).refresh();
                        final activeOrder = ref.read(driverActiveOrderProvider);
                        if (!context.mounted) {
                          return;
                        }
                        if (activeOrder != null &&
                            _isServerOrderId(activeOrder.id)) {
                          context.go(
                            AppRoutes.driverOrderActivePath(activeOrder.id),
                          );
                        }
                      }
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_acceptErrorMessage(result)),
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

class _OrderCard extends StatelessWidget {
  final DriverOrderModel order;
  final bool isProcessing;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _OrderCard({
    required this.order,
    this.isProcessing = false,
    this.onAccept,
    this.onReject,
  });

  String get _displayOrderId {
    final number = order.orderNumber.trim();
    if (number.isNotEmpty) {
      return number.startsWith('#') ? number : '#$number';
    }
    return '#${order.id}';
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (sheetContext) {
        return _IncomingOrderDetailSheet(
          order: order,
          displayOrderId: _displayOrderId,
          isProcessing: isProcessing,
          onAccept: onAccept,
          onReject: onReject,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final serviceLabel = serviceTypeLabel(order.serviceTypeCode);
    final quantityLabel = _orderQuantityLabel(order);

    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _ServiceTypeLabel(
                label: serviceLabel,
                icon: serviceTypeLeadingIcon(order.serviceTypeCode),
                fontSize: 15,
                fontWeight: FontWeight.w900,
                iconSize: 18,
                maxWidth: 240,
                textColor: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _CustomerAvatar(
                  name: order.customerName,
                  avatarUrl: order.customerAvatarUrl,
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (quantityLabel != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          quantityLabel,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _OrderRoutePreview(order: order),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _InlineDistanceText(dispatch: order.dispatch)),
                const SizedBox(width: 12),
                Text(
                  formatCurrency(order.fee),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => _showDetail(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.2),
                minimumSize: const Size.fromHeight(40),
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
              child: const Text('Lihat Detail'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingOrderDetailSheet extends StatelessWidget {
  final DriverOrderModel order;
  final String displayOrderId;
  final bool isProcessing;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _IncomingOrderDetailSheet({
    required this.order,
    required this.displayOrderId,
    required this.isProcessing,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final packageDetails = buildCourierPackageDetails(order);
    final serviceLabel = serviceTypeLabel(order.serviceTypeCode);
    final quantityLabel = _orderQuantityLabel(order);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Detail Order',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textSecondary,
                  tooltip: 'Tutup',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ServiceTypeLabel(
                          label: serviceLabel,
                          icon: serviceTypeLeadingIcon(order.serviceTypeCode),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          iconSize: 18,
                          maxWidth: 240,
                          textColor: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _OrderNumberText(label: displayOrderId),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _CustomerAvatar(
                        name: order.customerName,
                        avatarUrl: order.customerAvatarUrl,
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            if (quantityLabel != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                quantityLabel,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InlineDistanceText(dispatch: order.dispatch),
                  const SizedBox(height: 18),
                  _DetailSectionTitle('Rute'),
                  const SizedBox(height: 10),
                  _OrderRouteSection(
                    order: order,
                    framed: false,
                    initiallyExpanded: true,
                    showExpandButton: false,
                  ),
                  if (packageDetails.isCourier) ...[
                    const SizedBox(height: 18),
                    _CourierPackageSection(packageDetails: packageDetails),
                  ],
                  const SizedBox(height: 18),
                  _FeeSummaryRow(fee: order.fee),
                ],
              ),
            ),
          ),
          _OrderDecisionBar(
            isProcessing: isProcessing,
            onReject: onReject == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    onReject?.call();
                  },
            onAccept: onAccept == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    onAccept?.call();
                  },
          ),
        ],
      ),
    );
  }
}

class _DetailSectionTitle extends StatelessWidget {
  final String text;

  const _DetailSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _OrderDecisionBar extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _OrderDecisionBar({
    required this.isProcessing,
    this.onAccept,
    this.onReject,
  });

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
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Row(
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: GoogleFonts.inter(
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
                    elevation: 0,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: GoogleFonts.inter(
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
          ),
        ),
      ),
    );
  }
}

class _OrderRoutePreview extends StatelessWidget {
  final DriverOrderModel order;

  const _OrderRoutePreview({required this.order});

  @override
  Widget build(BuildContext context) {
    final stops = _incomingRouteStops(order);
    final visibleStops = stops.length <= 2
        ? stops
        : <_IncomingRouteStop>[stops.first, stops.last];

    return Column(
      children: [
        for (var index = 0; index < visibleStops.length; index++) ...[
          _RoutePreviewLine(stop: visibleStops[index]),
          if (index < visibleStops.length - 1) const SizedBox(height: 7),
        ],
      ],
    );
  }
}

class _RoutePreviewLine extends StatelessWidget {
  final _IncomingRouteStop stop;

  const _RoutePreviewLine({required this.stop});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(stop.icon, size: 16, color: stop.iconColor),
        const SizedBox(width: 8),
        SizedBox(
          width: 54,
          child: Text(
            stop.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _singleLineAddress(stop.value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineDistanceText extends StatelessWidget {
  final DriverDispatchModel? dispatch;

  const _InlineDistanceText({required this.dispatch});

  @override
  Widget build(BuildContext context) {
    final viewData = DriverDispatchPresenter.present(dispatch);
    final color = _distanceColor(viewData.bucket);
    final label = _compactDistanceLabel(viewData.label);

    return Semantics(
      label: 'Jarak driver ke titik jemput ${viewData.label}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.near_me_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _distanceColor(String bucket) {
    switch (bucket) {
      case 'NEAR':
        return AppColors.success;
      case 'MEDIUM':
        return AppColors.warning;
      case 'FAR':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _compactDistanceLabel(String label) {
    final normalized = label.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return 'Jarak belum tersedia';
    }
    return normalized;
  }
}

class _ServiceTypeLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final double fontSize;
  final FontWeight fontWeight;
  final double iconSize;
  final double maxWidth;
  final Color textColor;

  const _ServiceTypeLabel({
    required this.label,
    required this.icon,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w800,
    this.iconSize = 14,
    this.maxWidth = 180,
    this.textColor = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: AppColors.primary),
          SizedBox(width: fontSize >= 14 ? 6 : 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: fontSize,
                fontWeight: fontWeight,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderNumberText extends StatelessWidget {
  final String label;

  const _OrderNumberText({required this.label});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          height: 1.1,
        ),
      ),
    );
  }
}

class _FeeSummaryRow extends StatelessWidget {
  final int fee;

  const _FeeSummaryRow({required this.fee});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.payments_outlined,
            size: 18,
            color: AppColors.textSecondary,
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
            formatCurrency(fee),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;

  const _CustomerAvatar({required this.name, this.avatarUrl, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return ProfileAvatar(
      name: name,
      avatarUrl: avatarUrl,
      size: size,
      backgroundColor: AppColors.surfaceAlt,
      initialColor: AppColors.primaryDark,
      borderColor: AppColors.border,
      borderWidth: 1,
      imageScale: 1.12,
    );
  }
}

List<_IncomingRouteStop> _incomingRouteStops(DriverOrderModel order) {
  if (normalizeServiceTypeCode(order.serviceTypeCode) ==
          ServiceTypeCodes.shopping &&
      order.shoppingStops.isNotEmpty) {
    final stops = List<DriverShoppingStopModel>.from(order.shoppingStops)
      ..sort((left, right) {
        final leftSequence = left.sequenceNo <= 0 ? 999 : left.sequenceNo;
        final rightSequence = right.sequenceNo <= 0 ? 999 : right.sequenceNo;
        final sequenceCompare = leftSequence.compareTo(rightSequence);
        if (sequenceCompare != 0) {
          return sequenceCompare;
        }
        return left.pickupLocationId.compareTo(right.pickupLocationId);
      });

    return [
      for (var index = 0; index < stops.length; index++)
        _IncomingRouteStop(
          icon: Icons.radio_button_checked,
          iconColor: AppColors.primary,
          label: 'Tempat ${index + 1}',
          value: _merchantStopText(stops[index]),
        ),
      _IncomingRouteStop(
        icon: Icons.location_on_rounded,
        iconColor: const Color(0xFF2563EB),
        label: 'Antar',
        value: order.dropoffAddress,
      ),
    ];
  }

  return [
    _IncomingRouteStop(
      icon: Icons.radio_button_checked,
      iconColor: AppColors.primary,
      label: 'Jemput',
      value: order.pickupAddress,
    ),
    _IncomingRouteStop(
      icon: Icons.location_on_rounded,
      iconColor: const Color(0xFF2563EB),
      label: 'Antar',
      value: order.dropoffAddress,
    ),
  ];
}

String _merchantStopText(DriverShoppingStopModel stop) {
  final address = (stop.merchant.address ?? '').trim();
  final itemSummary = _shoppingItemSummary(stop.items);
  return [
    stop.merchant.name.trim().isEmpty ? '-' : stop.merchant.name.trim(),
    if (address.isNotEmpty) address,
    if (itemSummary.isNotEmpty) itemSummary,
  ].join('\n');
}

String _shoppingItemSummary(List<DriverShoppingItemModel> items) {
  if (items.isEmpty) {
    return '';
  }

  return items
      .map((item) {
        final name = item.name.trim();
        if (name.isEmpty || name == '-') {
          return '';
        }
        return '${item.quantity}x $name';
      })
      .where((text) => text.isNotEmpty)
      .join(', ');
}

String _singleLineAddress(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  return normalized.isEmpty ? '-' : normalized;
}

String? _orderQuantityLabel(DriverOrderModel order) {
  final count = order.itemCount;
  if (count <= 0) {
    return null;
  }

  switch (normalizeServiceTypeCode(order.serviceTypeCode)) {
    case ServiceTypeCodes.ride:
      return null;
    case ServiceTypeCodes.courier:
      return '$count paket';
    case ServiceTypeCodes.shopping:
      return '$count barang';
    default:
      return null;
  }
}

class _OrderRouteSection extends StatefulWidget {
  final DriverOrderModel order;
  final bool framed;
  final bool initiallyExpanded;
  final bool showExpandButton;

  const _OrderRouteSection({
    required this.order,
    this.framed = true,
    this.initiallyExpanded = false,
    this.showExpandButton = true,
  });

  @override
  State<_OrderRouteSection> createState() => _OrderRouteSectionState();
}

class _OrderRouteSectionState extends State<_OrderRouteSection> {
  late bool _expanded;

  static const int _collapsedMaxLines = 2;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  List<_IncomingRouteStop> get _routeStops => _incomingRouteStops(widget.order);

  bool get _canExpand =>
      widget.showExpandButton &&
      _routeStops.any((stop) {
        final value = stop.value.trim();
        return value.isNotEmpty && value != '-';
      });

  @override
  Widget build(BuildContext context) {
    final routeStops = _routeStops;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < routeStops.length; index++) ...[
          _routeStop(stop: routeStops[index]),
          if (index < routeStops.length - 1) const SizedBox(height: 8),
        ],
        if (_canExpand) ...[
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
              label: Text(_expanded ? 'Tutup alamat' : 'Lihat alamat lengkap'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    if (!widget.framed) {
      return content;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: content,
    );
  }

  Widget _routeStop({required _IncomingRouteStop stop}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          child: Icon(stop.icon, size: 16, color: stop.iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stop.label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stop.value,
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

class _IncomingRouteStop {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _IncomingRouteStop({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });
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
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 16,
                color: AppColors.textSecondary,
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
            Text(
              packageDetails.description,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.3,
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
  final Widget? action;

  const _EmptyOrderState({
    required this.icon,
    required this.title,
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
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
