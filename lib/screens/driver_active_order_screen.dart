import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/driver_order_model.dart';
import '../providers/driver_location_tracking_provider.dart';
import '../providers/order_chat_unread_provider.dart';
import '../providers/driver_order_providers.dart';
import '../services/driver_order_service.dart';
import '../utils/currency_formatter.dart';
import '../utils/courier_package_formatter.dart';
import '../utils/map_marker_icons.dart';
import '../utils/order_formatters.dart' hide formatCurrency;
import '../utils/order_status.dart';
import '../utils/service_type.dart';
import '../widgets/order_chat_badge_icon.dart';
import '../widgets/shopping_fee_breakdown.dart';

class DriverActiveOrderScreen extends ConsumerWidget {
  final String orderId;

  const DriverActiveOrderScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orderId.trim().isEmpty || !_isServerOrderId(orderId)) {
      return const Scaffold(
        body: Center(child: Text('Order ID tidak valid untuk data server.')),
      );
    }

    final detailState = ref.watch(driverOrderDetailProvider(orderId));
    ref.watch(driverOrderDetailRealtimeProvider(orderId));
    final ordersState = ref.watch(driverOrdersProvider);
    final trackingState = ref.watch(driverLocationTrackingProvider);

    final isProcessing = ordersState.maybeWhen(
      data: (value) => value.isProcessing(orderId),
      orElse: () => false,
    );
    final parsedOrderId = int.tryParse(orderId);
    final unreadCountAsync = parsedOrderId == null
        ? const AsyncData<int>(0)
        : ref.watch(orderChatUnreadCountProvider(parsedOrderId));
    final unreadCount = unreadCountAsync.asData?.value ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Order Aktif',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Chat customer',
            icon: OrderChatBadgeIcon(
              unreadCount: unreadCount,
              iconColor: AppColors.textPrimary,
            ),
            onPressed: () => context.push(AppRoutes.orderChatPath(orderId)),
          ),
        ],
      ),
      body: detailState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          return _ErrorState(
            message: _mapDetailError(error),
            onRetry: () {
              ref.invalidate(driverOrderDetailProvider(orderId));
            },
          );
        },
        data: (order) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            ref
                .read(driverLocationTrackingProvider.notifier)
                .syncForOrder(orderId: order.id, statusCode: order.statusCode);
          });

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(driverOrderDetailProvider(orderId));
              await ref.read(driverOrderDetailProvider(orderId).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                _MapCard(order: order, trackingState: trackingState),
                const SizedBox(height: 12),
                _OrderMetaCard(order: order, trackingState: trackingState),
                const SizedBox(height: 12),
                if (order.shoppingItems.isNotEmpty) ...[
                  _ShoppingItemsCard(
                    order: order,
                    isProcessing: isProcessing,
                    onSave: (items, receiptNote) async {
                      return ref
                          .read(driverOrdersProvider.notifier)
                          .updateShoppingItems(
                            orderId: order.id,
                            items: items,
                            receiptNote: receiptNote,
                          );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                _TimelineCard(timeline: order.statusTimeline),
                const SizedBox(height: 12),
                _ActionCard(
                  order: order,
                  isProcessing: isProcessing,
                  onReportPickupFailed:
                      ({required pickupLocationId, required reason}) async {
                        final error = await ref
                            .read(driverOrdersProvider.notifier)
                            .recordShoppingPickupFailed(
                              orderId: order.id,
                              pickupLocationId: pickupLocationId,
                              reason: reason,
                            );

                        if (!context.mounted) {
                          return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error ?? 'Merchant tutup berhasil dicatat.',
                            ),
                            backgroundColor: error == null
                                ? null
                                : AppColors.error,
                          ),
                        );
                        if (error == null) {
                          ref.invalidate(driverOrderDetailProvider(order.id));
                        }
                      },
                  onTapAction: (action) async {
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
                        latitude: trackingState.latitude,
                        longitude: trackingState.longitude,
                      );
                    }

                    if (!context.mounted) {
                      return;
                    }

                    if (error == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${action.label} berhasil.')),
                      );
                      ref.invalidate(driverOrderDetailProvider(order.id));
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
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
}

class _MapCard extends StatefulWidget {
  final DriverOrderModel order;
  final DriverLocationTrackingState trackingState;

  const _MapCard({required this.order, required this.trackingState});

  @override
  State<_MapCard> createState() => _MapCardState();
}

class _MapCardState extends State<_MapCard> {
  BitmapDescriptor? _driverMarkerIcon;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDriverMarkerIcon());
  }

  Future<void> _loadDriverMarkerIcon() async {
    final icon = await buildMotorDriverMarker();
    if (!mounted) {
      return;
    }
    setState(() => _driverMarkerIcon = icon);
  }

  @override
  Widget build(BuildContext context) {
    final pickupPoints = _pickupPoints();
    final pickup = pickupPoints.isEmpty ? null : pickupPoints.first.position;
    final dropoff = _latLng(
      widget.order.dropoffLatitude,
      widget.order.dropoffLongitude,
    );
    final driver = _latLng(
      widget.trackingState.latitude,
      widget.trackingState.longitude,
    );

    if (pickupPoints.isEmpty && dropoff == null && driver == null) {
      return Container(
        height: 220,
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
        child: const Center(
          child: Text(
            'Koordinat map belum tersedia untuk order ini.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final initial = driver ?? pickup ?? dropoff!;
    final markers = <Marker>{
      if (driver != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: driver,
          icon:
              _driverMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Posisi Anda'),
        ),
      for (final pickupPoint in pickupPoints)
        Marker(
          markerId: MarkerId('pickup_${pickupPoint.id}'),
          position: pickupPoint.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: pickupPoint.label),
        ),
      if (dropoff != null)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoff,
          infoWindow: const InfoWindow(title: 'Dropoff'),
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 230,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: initial, zoom: 14),
              markers: markers,
              polylines: _buildPolylines(),
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  EagerGestureRecognizer.new,
                ),
              },
              myLocationButtonEnabled: false,
              mapToolbarEnabled: true,
              zoomControlsEnabled: false,
              compassEnabled: true,
            ),
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: _TrackingBadge(state: widget.trackingState),
            ),
          ],
        ),
      ),
    );
  }

  LatLng? _latLng(double? lat, double? lng) {
    if (lat == null || lng == null) {
      return null;
    }
    return LatLng(lat, lng);
  }

  List<_DriverPickupPoint> _pickupPoints() {
    final orderedIds =
        widget.order.shoppingRoute?.orderedPickupLocationIds ?? const <int>[];
    final activeStops = widget.order.shoppingStops
        .where((stop) => stop.isActive)
        .where(
          (stop) =>
              stop.merchant.latitude != null && stop.merchant.longitude != null,
        )
        .toList(growable: false);
    activeStops.sort((a, b) {
      final aIndex = orderedIds.indexOf(a.pickupLocationId);
      final bIndex = orderedIds.indexOf(b.pickupLocationId);
      if (aIndex >= 0 || bIndex >= 0) {
        return (aIndex < 0 ? 1 << 20 : aIndex).compareTo(
          bIndex < 0 ? 1 << 20 : bIndex,
        );
      }
      return a.sequenceNo.compareTo(b.sequenceNo);
    });

    final stopPoints = activeStops
        .map(
          (stop) => _DriverPickupPoint(
            id: stop.pickupLocationId.toString(),
            label:
                'Merchant ${stop.sequenceNo <= 0 ? 1 : stop.sequenceNo}: ${stop.merchant.name}',
            position: LatLng(stop.merchant.latitude!, stop.merchant.longitude!),
          ),
        )
        .toList(growable: false);

    if (stopPoints.isNotEmpty) {
      return stopPoints;
    }

    final fallback = _latLng(
      widget.order.pickupLatitude,
      widget.order.pickupLongitude,
    );
    if (fallback == null) {
      return const <_DriverPickupPoint>[];
    }

    return [
      _DriverPickupPoint(id: 'default', label: 'Pickup', position: fallback),
    ];
  }

  Set<Polyline> _buildPolylines() {
    final points = _decodePolyline(widget.order.shoppingRoute?.encodedPolyline);
    if (points.length < 2) {
      return const <Polyline>{};
    }

    return {
      Polyline(
        polylineId: const PolylineId('shopping_route'),
        points: points,
        color: AppColors.primary,
        width: 5,
        geodesic: true,
      ),
    };
  }

  List<LatLng> _decodePolyline(String? encoded) {
    final value = (encoded ?? '').trim();
    if (value.isEmpty) {
      return const <LatLng>[];
    }

    final points = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;

    while (index < value.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = value.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < value.length);
      latitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        byte = value.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < value.length);
      longitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      points.add(LatLng(latitude / 1e5, longitude / 1e5));
    }

    return points;
  }
}

class _DriverPickupPoint {
  const _DriverPickupPoint({
    required this.id,
    required this.label,
    required this.position,
  });

  final String id;
  final String label;
  final LatLng position;
}

class _TrackingBadge extends StatelessWidget {
  final DriverLocationTrackingState state;

  const _TrackingBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final hasPosition = state.latitude != null && state.longitude != null;
    final text = state.isTracking
        ? hasPosition
              ? 'GPS aktif - lokasi dikirim realtime'
              : 'GPS aktif - menunggu titik lokasi'
        : state.isStarting
        ? 'Mengaktifkan GPS driver...'
        : 'GPS driver belum aktif';
    final color = state.isTracking
        ? AppColors.success
        : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.my_location, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderMetaCard extends StatelessWidget {
  final DriverOrderModel order;
  final DriverLocationTrackingState trackingState;

  const _OrderMetaCard({required this.order, required this.trackingState});

  @override
  Widget build(BuildContext context) {
    final serviceLabel = serviceTypeLabel(order.serviceTypeCode);
    final packageDetails = buildCourierPackageDetails(order);

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
              _buildAvatar(order.customerName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Order ID: ${order.orderNumber.isEmpty ? order.id : order.orderNumber}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(
                serviceLabel,
                AppColors.primary.withValues(alpha: 0.1),
                AppColors.primaryDark,
              ),
              _pill(
                order.statusDisplayName ?? order.statusCode,
                AppColors.success.withValues(alpha: 0.12),
                AppColors.success,
              ),
              if (order.paymentStatus.isNotEmpty)
                _pill(
                  'COD ${order.paymentStatus.toUpperCase()}',
                  AppColors.darkBlue.withValues(alpha: 0.08),
                  AppColors.darkBlue,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _routeVisualizer(order),
          ..._buildCourierPackageRows(packageDetails),
          if ((trackingState.message ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trackingState.message!.trim(),
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _buildPricingSummary(),
        ],
      ),
    );
  }

  Widget _routeVisualizer(DriverOrderModel order) {
    final activeStops = order.shoppingStops
        .where((stop) => stop.isActive)
        .toList(growable: false);
    final pickupStops = activeStops.isNotEmpty
        ? activeStops
        : <DriverShoppingStopModel>[];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pickupStops.isEmpty)
            _routeStop(
              icon: Icons.storefront_rounded,
              iconColor: AppColors.primary,
              title: 'Jemput',
              value: order.pickupAddress,
            )
          else
            ...pickupStops.map((stop) {
              final sequence = stop.sequenceNo <= 0 ? 1 : stop.sequenceNo;
              final address = (stop.merchant.address ?? '').trim();
              final status = stop.isFailed
                  ? 'Tutup/gagal pickup'
                  : stop.isSkipped
                  ? 'Dilewati'
                  : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _routeStop(
                  icon: Icons.storefront_rounded,
                  iconColor: stop.isFailed
                      ? AppColors.error
                      : AppColors.primary,
                  title: 'Merchant $sequence',
                  value: [
                    stop.merchant.name,
                    if (address.isNotEmpty) address,
                    ?status,
                  ].join('\n'),
                ),
              );
            }),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                  5,
                  (index) => Container(
                    width: 2,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _routeStop(
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFF2563EB),
            title: 'Tujuan',
            value: order.dropoffAddress,
          ),
        ],
      ),
    );
  }

  Widget _routeStop({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.isEmpty || parts.first.isEmpty
        ? '?'
        : parts.length == 1
        ? parts.first.characters.first.toUpperCase()
        : '${parts.first.characters.first}${parts.last.characters.first}'
              .toUpperCase();

    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryLight,
            AppColors.primary.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _row(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 58,
          child: Text(
            title,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Text(
          ':',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCourierPackageRows(CourierPackageDetails details) {
    if (!details.isCourier) {
      return const [];
    }

    final rows = <Widget>[];

    void addRow(String title, String value) {
      if (value.isEmpty) {
        return;
      }

      rows
        ..add(const SizedBox(height: 6))
        ..add(_row(title, value));
    }

    addRow('Barang', details.description);
    addRow('Ukuran', details.sizeLine);
    addRow('Keamanan', details.safetyLine);
    addRow('Catatan', details.packingNote);

    return rows;
  }

  Widget _buildPricingSummary() {
    final fee = order.fee;
    final total = order.totalPrice.round();
    final pricing = order.shoppingPricing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.cardYellow,
            AppColors.primaryLight.withValues(alpha: 0.3),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fee != total) ...[
                  const Text(
                    'Fee Driver',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _formatCurrency(fee),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'Total Pembayaran',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatCurrency(total),
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (pricing != null && pricing.feeBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 8),
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
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.payments_rounded,
              color: AppColors.primaryDark.withValues(alpha: 0.8),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(int amount) {
    return formatRupiah(amount);
  }
}

class _ShoppingItemsCard extends StatefulWidget {
  final DriverOrderModel order;
  final bool isProcessing;
  final Future<String?> Function(
    List<Map<String, dynamic>> items,
    String? receiptNote,
  )
  onSave;

  const _ShoppingItemsCard({
    required this.order,
    required this.isProcessing,
    required this.onSave,
  });

  @override
  State<_ShoppingItemsCard> createState() => _ShoppingItemsCardState();
}

class _ShoppingItemsCardState extends State<_ShoppingItemsCard> {
  final Map<int, TextEditingController> _priceControllers = {};
  final TextEditingController _receiptNoteController = TextEditingController();
  final Map<int, bool> _availability = {};
  final Map<int, bool> _heavy = {};

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _ShoppingItemsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.shoppingItems != widget.order.shoppingItems) {
      _syncControllers();
    }
  }

  @override
  void dispose() {
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    _receiptNoteController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    final activeIds = widget.order.shoppingItems.map((item) => item.id).toSet();
    final staleIds = _priceControllers.keys
        .where((id) => !activeIds.contains(id))
        .toList(growable: false);
    for (final id in staleIds) {
      _priceControllers.remove(id)?.dispose();
      _availability.remove(id);
      _heavy.remove(id);
    }

    for (final item in widget.order.shoppingItems) {
      _availability[item.id] = item.isAvailable;
      _heavy[item.id] = item.isHeavy;
      _priceControllers.putIfAbsent(
        item.id,
        () => TextEditingController(
          text: item.unitPrice > 0 ? item.unitPrice.round().toString() : '',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = widget.order.shoppingItems
        .where((item) => item.isPricePending)
        .length;

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
              const Expanded(
                child: Text(
                  'Daftar Belanja',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (pendingCount > 0)
                Text(
                  '$pendingCount harga pending',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.order.shoppingStops.isEmpty)
            ...widget.order.shoppingItems.map(_buildItemEditor)
          else
            ...widget.order.shoppingStops
                .where((stop) => !stop.isSkipped && !stop.isReplaced)
                .map(_buildStopSection),
          const SizedBox(height: 8),
          TextField(
            controller: _receiptNoteController,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Catatan nota',
              hintText: 'Contoh: satu item kosong, diganti ukuran lain',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.isProcessing ? null : _save,
              icon: widget.isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.receipt_long, size: 18),
              label: const Text('Simpan Harga Nota'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemEditor(DriverShoppingItemModel item) {
    final isAvailable = _availability[item.id] ?? item.isAvailable;
    final controller = _priceControllers[item.id]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${item.quantity}x ${item.name}',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    decoration: isAvailable
                        ? TextDecoration.none
                        : TextDecoration.lineThrough,
                  ),
                ),
              ),
              Checkbox(
                value: isAvailable,
                onChanged: (value) {
                  setState(() {
                    _availability[item.id] = value ?? true;
                  });
                },
              ),
            ],
          ),
          if ((item.notes ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                item.notes!.trim(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          TextField(
            controller: controller,
            enabled: isAvailable,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: item.isManual ? 'Harga aktual' : 'Harga item',
              prefixText: 'Rp ',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 6),
          CheckboxListTile(
            value: _heavy[item.id] ?? item.isHeavy,
            onChanged: (value) {
              setState(() {
                _heavy[item.id] = value ?? false;
              });
            },
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Item berat',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            subtitle: const Text(
              'Tambahan biaya Rp6.000 sekali per order',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopSection(DriverShoppingStopModel stop) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${stop.sequenceNo <= 0 ? 1 : stop.sequenceNo}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stop.merchant.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (stop.isFailed || stop.isSkipped || stop.isReplaced)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    stop.isFailed
                        ? 'Gagal'
                        : stop.isReplaced
                        ? 'Diganti'
                        : 'Dilewati',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if ((stop.merchant.address ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                stop.merchant.address!.trim(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
          if ((stop.failureReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                stop.failureReason!.trim(),
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          ...stop.items.map(_buildItemEditor),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final payload = widget.order.shoppingItems
        .map((item) {
          final rawPrice = _priceControllers[item.id]?.text.trim() ?? '';
          final unitPrice = double.tryParse(rawPrice.replaceAll('.', '')) ?? 0;

          return <String, dynamic>{
            'id': item.id,
            'quantity': item.quantity,
            'unit_price': unitPrice,
            'is_available': _availability[item.id] ?? item.isAvailable,
            'notes': item.notes,
            'is_heavy': _heavy[item.id] ?? item.isHeavy,
          };
        })
        .toList(growable: false);

    final error = await widget.onSave(
      payload,
      _receiptNoteController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Harga nota berhasil disimpan.'),
        backgroundColor: error == null ? null : AppColors.error,
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final List<DriverOrderTimelineItemModel> timeline;

  const _TimelineCard({required this.timeline});

  @override
  Widget build(BuildContext context) {
    final statusTimeline = timeline
        .where((item) => item.eventType.toUpperCase() == 'STATUS_CHANGE')
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
            children: [
              Icon(Icons.history_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Riwayat Status',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (statusTimeline.isEmpty)
            const Text(
              'Belum ada histori status.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            ...List.generate(statusTimeline.length, (index) {
              final item = statusTimeline[index];
              final isLast = index == statusTimeline.length - 1;
              final statusText = item.statusDisplayName ?? item.statusCode;
              final timeText = item.createdAt == null
                  ? 'Waktu belum tersedia'
                  : formatTime(item.createdAt);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    child: Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: isLast
                                ? AppColors.white
                                : AppColors.textSecondary.withValues(
                                    alpha: 0.2,
                                  ),
                            border: isLast
                                ? Border.all(color: AppColors.primary, width: 4)
                                : null,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 34,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusText,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: isLast
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 12,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeText,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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
}

class _ActionCard extends StatelessWidget {
  final DriverOrderModel order;
  final bool isProcessing;
  final Future<void> Function({
    required int pickupLocationId,
    required String reason,
  })?
  onReportPickupFailed;
  final Future<void> Function(DriverOrderActionModel action) onTapAction;

  const _ActionCard({
    required this.order,
    required this.isProcessing,
    required this.onReportPickupFailed,
    required this.onTapAction,
  });

  @override
  Widget build(BuildContext context) {
    final actions = order.availableActions;
    final hasCodCollection = actions.any((action) => action.isCodCollection);
    final isCourier =
        normalizeServiceTypeCode(order.serviceTypeCode) ==
        ServiceTypeCodes.courier;
    final codMessage = isCourier
        ? 'Cek barang lebih dulu, lalu tagih ${formatRupiah(order.totalPrice)} saat pickup sebelum menekan Paket Diambil.'
        : 'Tagih COD sebesar ${formatRupiah(order.totalPrice)} sebelum menyelesaikan order.';
    final pricing = order.shoppingPricing;
    final canReportPickupFailed = _canReportPickupFailed();

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
            children: [
              Icon(Icons.touch_app_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Aksi Driver',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (canReportPickupFailed) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isProcessing || onReportPickupFailed == null
                    ? null
                    : () async {
                        final report = await _showFailedPickupDialog(context);
                        if (report == null) {
                          return;
                        }
                        await onReportPickupFailed?.call(
                          pickupLocationId: report.pickupLocationId,
                          reason: report.reason,
                        );
                      },
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('Merchant Tutup / Gagal Pickup'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
            if (pricing != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 10),
                child: Text(
                  'Percobaan gagal ${pricing.failedAttemptCount}/${pricing.failedAttemptThreshold}. Fee cancel aktif setelah batas tercapai.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              const SizedBox(height: 10),
          ],
          if (hasCodCollection) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.16),
                ),
              ),
              child: Text(
                codMessage,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (actions.isEmpty)
            const Text(
              'Tidak ada aksi yang tersedia pada status ini.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            ...actions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    onPressed: isProcessing || action.blocked
                        ? null
                        : () async {
                            await onTapAction(action);
                          },
                    child: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : Text(action.label),
                  ),
                ),
              ),
            ),
          if (actions.any((action) => action.blocked))
            Text(
              actions.firstWhere((action) => action.blocked).blockedReason ??
                  'Aksi masih terkunci.',
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
        ],
      ),
    );
  }

  bool _canReportPickupFailed() {
    if (onReportPickupFailed == null ||
        normalizeServiceTypeCode(order.serviceTypeCode) !=
            ServiceTypeCodes.shopping ||
        order.shoppingStops.where((stop) => stop.isActive).isEmpty ||
        order.shoppingPricing?.canCancelWithFee == true) {
      return false;
    }

    final status = normalizeOrderStatusCode(order.statusCode);
    return status == OrderStatusCodes.driverAssigned ||
        status == OrderStatusCodes.arrivedMerchant;
  }

  Future<_FailedPickupReport?> _showFailedPickupDialog(BuildContext context) {
    return showDialog<_FailedPickupReport>(
      context: context,
      builder: (context) => _FailedPickupDialog(
        stops: order.shoppingStops
            .where((stop) => stop.isActive)
            .toList(growable: false),
      ),
    );
  }
}

class _FailedPickupReport {
  const _FailedPickupReport({
    required this.pickupLocationId,
    required this.reason,
  });

  final int pickupLocationId;
  final String reason;
}

class _FailedPickupDialog extends StatefulWidget {
  const _FailedPickupDialog({required this.stops});

  final List<DriverShoppingStopModel> stops;

  @override
  State<_FailedPickupDialog> createState() => _FailedPickupDialogState();
}

class _FailedPickupDialogState extends State<_FailedPickupDialog> {
  final TextEditingController _reasonController = TextEditingController(
    text: 'Merchant tutup saat driver tiba.',
  );
  late int _selectedPickupLocationId;

  @override
  void initState() {
    super.initState();
    _selectedPickupLocationId = widget.stops.first.pickupLocationId;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: viewInsets.bottom + 16,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Merchant Tutup',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedPickupLocationId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Merchant',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.stops
                          .map(
                            (stop) => DropdownMenuItem<int>(
                              value: stop.pickupLocationId,
                              child: Text(
                                '${stop.sequenceNo <= 0 ? 1 : stop.sequenceNo}. ${stop.merchant.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _selectedPickupLocationId = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reasonController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Alasan',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Batal'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            final reason = _reasonController.text.trim();
                            if (reason.isEmpty) {
                              return;
                            }
                            Navigator.of(context).pop(
                              _FailedPickupReport(
                                pickupLocationId: _selectedPickupLocationId,
                                reason: reason,
                              ),
                            );
                          },
                          child: const Text('Catat'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
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
            const Icon(Icons.error_outline, color: AppColors.error, size: 32),
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
