import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

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
import '../widgets/driver_transfer_payment_card.dart';
import '../widgets/shopping_fee_breakdown.dart';

InputDecoration _driverDialogInputDecoration({
  String? labelText,
  String? hintText,
  String? prefixText,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.border),
  );

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixText: prefixText,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    labelStyle: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    hintStyle: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );
}

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
    ref.watch(driverOrderTransferProofReconciliationProvider(orderId));
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
                if (normalizeServiceTypeCode(order.serviceTypeCode) ==
                    ServiceTypeCodes.courier) ...[
                  _ProofChecklistCard(
                    order: order,
                    isProcessing: isProcessing,
                    onUploadProof:
                        ({
                          required type,
                          required photo,
                          note,
                          pickupLocationId,
                        }) {
                          return ref
                              .read(driverOrdersProvider.notifier)
                              .uploadProof(
                                orderId: order.id,
                                type: type,
                                photo: photo,
                                note: note,
                                pickupLocationId: pickupLocationId,
                              );
                        },
                  ),
                  const SizedBox(height: 12),
                ],
                _ManualDeliveryFeeCard(
                  order: order,
                  isProcessing: isProcessing,
                  onSave:
                      ({
                        required amount,
                        required reason,
                        required carefulCarryRequired,
                      }) {
                        return ref
                            .read(driverOrdersProvider.notifier)
                            .updateDeliveryFeeOverride(
                              orderId: order.id,
                              amount: amount,
                              reason: reason,
                              carefulCarryRequired: carefulCarryRequired,
                            );
                      },
                ),
                const SizedBox(height: 12),
                if (order.shoppingItems.isNotEmpty) ...[
                  _ShoppingItemsCard(
                    order: order,
                    isProcessing: isProcessing,
                    onUploadReceipt: (photo, note) {
                      return ref
                          .read(driverOrdersProvider.notifier)
                          .uploadProof(
                            orderId: order.id,
                            type: 'receipt',
                            photo: photo,
                            note: note,
                          );
                    },
                    onSave:
                        (
                          items,
                          shoppingTotalAmount,
                          deliveryFeeOverride,
                          receiptNote,
                          receiptPhoto,
                        ) async {
                          final error = await ref
                              .read(driverOrdersProvider.notifier)
                              .updateShoppingCheckout(
                                orderId: order.id,
                                items: items,
                                shoppingTotalAmount: shoppingTotalAmount,
                                deliveryFeeOverride: deliveryFeeOverride,
                                receiptNote: receiptNote,
                                receiptPhoto: receiptPhoto,
                              );

                          if (error == null) {
                            ref.invalidate(driverOrderDetailProvider(order.id));
                            try {
                              await ref.read(
                                driverOrderDetailProvider(order.id).future,
                              );
                            } catch (_) {
                              return 'Checkout tersimpan, tapi detail order belum berhasil dimuat ulang. Tarik layar untuk refresh.';
                            }
                          }

                          return error;
                        },
                  ),
                  const SizedBox(height: 12),
                ],
                if (DriverTransferPaymentCard.shouldShow(order)) ...[
                  DriverTransferPaymentCard(
                    order: order,
                    isProcessing: isProcessing,
                    onConfirmTransfer: ({required amount, required note}) async {
                      final error = await ref
                          .read(driverOrdersProvider.notifier)
                          .confirmTransferPayment(
                            orderId: order.id,
                            amount: amount,
                            note: note,
                          );

                      if (!context.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            error ??
                                'Pembayaran transfer berhasil diverifikasi.',
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
                  ),
                  const SizedBox(height: 12),
                ],
                _TimelineCard(timeline: order.statusTimeline),
                const SizedBox(height: 12),
                _ActionCard(
                  order: order,
                  isProcessing: isProcessing,
                  onReportPickupFailed:
                      ({
                        required pickupLocationId,
                        required reason,
                        required storeClosedPhoto,
                      }) async {
                        final error = await ref
                            .read(driverOrdersProvider.notifier)
                            .recordShoppingPickupFailed(
                              orderId: order.id,
                              pickupLocationId: pickupLocationId,
                              reason: reason,
                              storeClosedPhoto: storeClosedPhoto,
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
    final showRouteUnavailableHint = _shouldShowRouteUnavailableHint();
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
            if (showRouteUnavailableHint)
              Positioned(
                top: 52,
                left: 10,
                right: 10,
                child: const _RouteUnavailableBadge(),
              ),
            if (widget.order.deliveryDistanceLabel.isNotEmpty)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: _MapDistanceBadge(
                  label: widget.order.deliveryDistanceLabel,
                ),
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
        widget.order.route?.orderedPickupLocationIds ?? const <int>[];
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
    final decodedPoints = _decodePolyline(widget.order.route?.encodedPolyline);
    if (decodedPoints.length < 2) {
      return const <Polyline>{};
    }

    return {
      Polyline(
        polylineId: const PolylineId('order_route'),
        points: decodedPoints,
        color: AppColors.primary,
        width: 5,
        geodesic: true,
      ),
    };
  }

  bool _shouldShowRouteUnavailableHint() {
    if (_decodePolyline(widget.order.route?.encodedPolyline).length >= 2) {
      return false;
    }

    return _pickupPoints().isNotEmpty &&
        _latLng(widget.order.dropoffLatitude, widget.order.dropoffLongitude) !=
            null;
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

class _MapDistanceBadge extends StatelessWidget {
  const _MapDistanceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.route_outlined,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Jarak rute $label',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteUnavailableBadge extends StatelessWidget {
  const _RouteUnavailableBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Rute jalan belum tersedia, coba refresh.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
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
                  '${order.paymentMethod.toUpperCase()} ${order.paymentStatus.toUpperCase()}',
                  AppColors.darkBlue.withValues(alpha: 0.08),
                  AppColors.darkBlue,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _routeVisualizer(order),
          if (order.deliveryDistanceLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            _row('Jarak', order.deliveryDistanceLabel),
          ],
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
    addRow('Keamanan', details.safetyLine);
    addRow('Catatan', details.packingNote);

    return rows;
  }

  Widget _buildPricingSummary() {
    final fee = order.fee;
    final total = order.totalPrice.round();
    final pricing = order.shoppingPricing;
    final supportsCarefulCarry = serviceTypeSupportsCarefulCarry(
      order.serviceTypeCode,
    );

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
                if (order.deliveryFee != null && order.deliveryFee! > 0) ...[
                  const Text(
                    'Ongkir',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    formatRupiah(order.deliveryFee!),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if ((order.deliveryFeeSource ?? '').trim().isNotEmpty ||
                      order.manualDeliveryFee != null ||
                      (supportsCarefulCarry && order.carefulCarryRequired))
                    Text(
                      [
                        if ((order.deliveryFeeSource ?? '').trim().isNotEmpty &&
                            (order.deliveryFeeSource ?? '')
                                    .trim()
                                    .toLowerCase() !=
                                'manual')
                          order.deliveryFeeSource!.trim(),
                        if (order.manualDeliveryFee != null) 'manual',
                        if (supportsCarefulCarry && order.carefulCarryRequired)
                          'perlu 2 orang',
                      ].join(' - '),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
                ] else if (order.feeBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ShoppingFeeBreakdown(
                    items: order.feeBreakdown
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

class _ProofChecklistCard extends StatelessWidget {
  const _ProofChecklistCard({
    required this.order,
    required this.isProcessing,
    required this.onUploadProof,
  });

  final DriverOrderModel order;
  final bool isProcessing;
  final Future<String?> Function({
    required String type,
    required XFile photo,
    String? note,
    int? pickupLocationId,
  })
  onUploadProof;

  @override
  Widget build(BuildContext context) {
    final requirements = _requirements();

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
          const Row(
            children: [
              Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bukti Foto Order',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...requirements.map(
            (requirement) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _proofRow(context, requirement),
            ),
          ),
        ],
      ),
    );
  }

  List<_ProofRequirement> _requirements() {
    final serviceType = normalizeServiceTypeCode(order.serviceTypeCode);
    final hasStoreClosedProof = order.hasProof('store_closed');

    return <_ProofRequirement>[
      if (serviceType == ServiceTypeCodes.courier) ...[
        const _ProofRequirement(
          type: 'pickup',
          title: 'Pengambilan',
          description: 'Foto saat barang/order diambil.',
        ),
        const _ProofRequirement(
          type: 'delivery',
          title: 'Diterima',
          description: 'Foto saat order selesai diterima.',
        ),
      ],
      if (serviceType == ServiceTypeCodes.shopping)
        const _ProofRequirement(
          type: 'receipt',
          title: 'Struk belanja',
          description: 'Foto struk untuk total belanja nitip.',
        ),
      if (hasStoreClosedProof)
        const _ProofRequirement(
          type: 'store_closed',
          title: 'Toko tutup',
          description: 'Bukti toko tutup/gagal pickup.',
        ),
    ];
  }

  Widget _proofRow(BuildContext context, _ProofRequirement requirement) {
    final uploaded = order.hasProof(requirement.type);
    final proof = _proofFor(requirement.type);
    final proofPhotoUrl = proof?.photoUrl;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            uploaded ? Icons.check_circle : Icons.radio_button_unchecked,
            color: uploaded ? AppColors.success : AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requirement.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  requirement.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (proofPhotoUrl != null) ...[
            InkWell(
              onTap: () => _showProofPreview(context, proof!),
              borderRadius: BorderRadius.circular(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  proofPhotoUrl,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 44,
                    height: 44,
                    color: AppColors.white,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          OutlinedButton.icon(
            onPressed: isProcessing
                ? null
                : () => _handleUpload(context, requirement),
            icon: const Icon(Icons.upload_file, size: 16),
            label: Text(uploaded ? 'Ganti' : 'Upload'),
          ),
        ],
      ),
    );
  }

  DriverOrderProofModel? _proofFor(String type) {
    final normalized = type.trim().toLowerCase();
    for (final proof in order.proofs) {
      if (proof.type == normalized) {
        return proof;
      }
    }

    return null;
  }

  void _showProofPreview(BuildContext context, DriverOrderProofModel proof) {
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

  Future<void> _handleUpload(
    BuildContext context,
    _ProofRequirement requirement,
  ) async {
    final photo = await _pickImage(context);
    if (photo == null) {
      return;
    }

    final error = await onUploadProof(
      type: requirement.type,
      photo: photo,
      note: requirement.title,
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? '${requirement.title} berhasil diupload.'),
        backgroundColor: error == null ? null : AppColors.error,
      ),
    );
  }
}

class _ProofRequirement {
  const _ProofRequirement({
    required this.type,
    required this.title,
    required this.description,
  });

  final String type;
  final String title;
  final String description;
}

class _ManualDeliveryFeeCard extends StatelessWidget {
  const _ManualDeliveryFeeCard({
    required this.order,
    required this.isProcessing,
    required this.onSave,
  });

  final DriverOrderModel order;
  final bool isProcessing;
  final Future<String?> Function({
    required double amount,
    required String reason,
    required bool carefulCarryRequired,
  })
  onSave;

  @override
  Widget build(BuildContext context) {
    final manualReason = (order.manualDeliveryFeeReason ?? '').trim();
    final supportsCarefulCarry = serviceTypeSupportsCarefulCarry(
      order.serviceTypeCode,
    );

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
              const Icon(Icons.edit_road_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ongkir Driver',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: isProcessing ? null : () => _openDialog(context),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip(
                'Jarak',
                order.deliveryDistanceLabel.isEmpty
                    ? '-'
                    : order.deliveryDistanceLabel,
              ),
              _summaryChip(
                'Ongkir sistem',
                order.deliveryFee == null
                    ? '-'
                    : formatRupiah(order.deliveryFee!),
              ),
              _summaryChip(
                'Manual',
                order.manualDeliveryFee == null
                    ? '-'
                    : formatRupiah(order.manualDeliveryFee!),
              ),
              if (supportsCarefulCarry && order.carefulCarryRequired)
                _summaryChip('Perlu 2 orang', 'aktif'),
            ],
          ),
          if (manualReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              manualReason,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _openDialog(BuildContext context) async {
    final supportsCarefulCarry = serviceTypeSupportsCarefulCarry(
      order.serviceTypeCode,
    );

    final result = await showDialog<_ManualDeliveryFeeInput>(
      context: context,
      builder: (context) => _ManualDeliveryFeeDialog(
        initialAmount: order.manualDeliveryFee ?? order.deliveryFee,
        initialReason: order.manualDeliveryFeeReason ?? '',
        initialCarefulCarryRequired:
            supportsCarefulCarry && order.carefulCarryRequired,
        supportsCarefulCarry: supportsCarefulCarry,
        systemDeliveryFee: order.deliveryFee,
      ),
    );

    if (result == null) {
      return;
    }

    final error = await onSave(
      amount: result.amount,
      reason: result.reason,
      carefulCarryRequired: result.carefulCarryRequired,
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Ongkir manual berhasil disimpan.'),
        backgroundColor: error == null ? null : AppColors.error,
      ),
    );
  }
}

class _ManualDeliveryFeeDialog extends StatefulWidget {
  const _ManualDeliveryFeeDialog({
    required this.initialAmount,
    required this.initialReason,
    required this.initialCarefulCarryRequired,
    required this.supportsCarefulCarry,
    required this.systemDeliveryFee,
  });

  final double? initialAmount;
  final String initialReason;
  final bool initialCarefulCarryRequired;
  final bool supportsCarefulCarry;
  final double? systemDeliveryFee;

  @override
  State<_ManualDeliveryFeeDialog> createState() =>
      _ManualDeliveryFeeDialogState();
}

class _ManualDeliveryFeeDialogState extends State<_ManualDeliveryFeeDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _reasonController;
  late bool _carefulCarryRequired;
  bool _amountTouchedByUser = false;

  @override
  void initState() {
    super.initState();
    final initialAmount = widget.initialAmount ?? 0;
    _amountController = TextEditingController(
      text: initialAmount > 0 ? initialAmount.round().toString() : '',
    );
    _reasonController = TextEditingController(text: widget.initialReason);
    _carefulCarryRequired =
        widget.supportsCarefulCarry && widget.initialCarefulCarryRequired;
  }

  @override
  void dispose() {
    _amountController.dispose();
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
                      'Edit Ongkir Manual',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _amountTouchedByUser = true,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: _driverDialogInputDecoration(
                        labelText: 'Ongkir dasar manual',
                        prefixText: 'Rp ',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _reasonController,
                      minLines: 2,
                      maxLines: 3,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: _driverDialogInputDecoration(
                        labelText: 'Alasan edit',
                        hintText: 'Contoh: rute sistem kurang akurat',
                      ),
                    ),
                    if (widget.supportsCarefulCarry) ...[
                      const SizedBox(height: 6),
                      CheckboxListTile(
                        value: _carefulCarryRequired,
                        onChanged: _handleCarefulCarryChanged,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Perlu 2 orang / hati-hati'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _close,
                          child: const Text('Batal'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _submit,
                          child: const Text('Simpan'),
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

  void _handleCarefulCarryChanged(bool? value) {
    setState(() {
      _carefulCarryRequired = value ?? false;
      final systemDeliveryFee = widget.systemDeliveryFee;
      if (_carefulCarryRequired &&
          !_amountTouchedByUser &&
          systemDeliveryFee != null &&
          systemDeliveryFee > 0) {
        _amountController.text = systemDeliveryFee.round().toString();
      }

      if (_carefulCarryRequired && _reasonController.text.trim().isEmpty) {
        _reasonController.text = 'Perlu 2 orang / barang harus hati-hati';
      }
    });
  }

  void _close() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop();
  }

  void _submit() {
    final amount = _parseCurrencyInput(_amountController.text);
    final reason = _reasonController.text.trim();
    if (amount <= 0 || reason.isEmpty) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(
      _ManualDeliveryFeeInput(
        amount: amount,
        reason: reason,
        carefulCarryRequired:
            widget.supportsCarefulCarry && _carefulCarryRequired,
      ),
    );
  }
}

class _ManualDeliveryFeeInput {
  const _ManualDeliveryFeeInput({
    required this.amount,
    required this.reason,
    required this.carefulCarryRequired,
  });

  final double amount;
  final String reason;
  final bool carefulCarryRequired;
}

class _ShoppingItemsCard extends StatefulWidget {
  final DriverOrderModel order;
  final bool isProcessing;
  final Future<String?> Function(XFile photo, String? note) onUploadReceipt;
  final Future<String?> Function(
    List<Map<String, dynamic>> items,
    double shoppingTotalAmount,
    double? deliveryFeeOverride,
    String? receiptNote,
    XFile? receiptPhoto,
  )
  onSave;

  const _ShoppingItemsCard({
    required this.order,
    required this.isProcessing,
    required this.onUploadReceipt,
    required this.onSave,
  });

  @override
  State<_ShoppingItemsCard> createState() => _ShoppingItemsCardState();
}

class _ShoppingItemsCardState extends State<_ShoppingItemsCard> {
  final TextEditingController _shoppingTotalController =
      TextEditingController();
  final TextEditingController _deliveryFeeOverrideController =
      TextEditingController();
  final TextEditingController _receiptNoteController = TextEditingController();
  final Map<int, bool> _availability = {};
  final Map<int, bool> _heavy = {};
  final Set<int> _dirtyAvailabilityIds = {};
  final Set<int> _dirtyHeavyIds = {};
  bool _isUploadingReceipt = false;

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
    _shoppingTotalController.dispose();
    _deliveryFeeOverrideController.dispose();
    _receiptNoteController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    final activeIds = widget.order.shoppingItems.map((item) => item.id).toSet();
    final staleIds = _availability.keys
        .where((id) => !activeIds.contains(id))
        .toList(growable: false);
    for (final id in staleIds) {
      _availability.remove(id);
      _heavy.remove(id);
      _dirtyAvailabilityIds.remove(id);
      _dirtyHeavyIds.remove(id);
    }

    for (final item in widget.order.shoppingItems) {
      if (!_availability.containsKey(item.id)) {
        _dirtyAvailabilityIds.remove(item.id);
        _availability[item.id] = item.isAvailable;
      } else if (_dirtyAvailabilityIds.contains(item.id)) {
        if (_availability[item.id] == item.isAvailable) {
          _dirtyAvailabilityIds.remove(item.id);
        }
      } else {
        _availability[item.id] = item.isAvailable;
      }

      if (!_heavy.containsKey(item.id)) {
        _dirtyHeavyIds.remove(item.id);
        _heavy[item.id] = item.isHeavy;
      } else if (_dirtyHeavyIds.contains(item.id)) {
        if (_heavy[item.id] == item.isHeavy) {
          _dirtyHeavyIds.remove(item.id);
        }
      } else {
        _heavy[item.id] = item.isHeavy;
      }
    }

    _primeCheckoutControllers();
  }

  void _primeCheckoutControllers() {
    if (_shoppingTotalController.text.trim().isEmpty) {
      final subtotal =
          widget.order.shoppingPricing?.subtotal ??
          widget.order.shoppingItems.fold<double>(
            0,
            (sum, item) => sum + item.subtotal,
          );
      if (subtotal > 0) {
        _shoppingTotalController.text = subtotal.round().toString();
      }
    }

    if (_deliveryFeeOverrideController.text.trim().isEmpty &&
        widget.order.manualDeliveryFee != null &&
        widget.order.manualDeliveryFee! > 0) {
      _deliveryFeeOverrideController.text = widget.order.manualDeliveryFee!
          .round()
          .toString();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  'Checkout Belanja',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Text(
                'Total dari struk',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.order.shoppingStops.isEmpty) ...[
            _buildHeavyToggleForItems(widget.order.shoppingItems),
            const SizedBox(height: 8),
            ...widget.order.shoppingItems.map(_buildItemEditor),
          ] else
            ...widget.order.shoppingStops
                .where((stop) => !stop.isSkipped && !stop.isReplaced)
                .map(_buildStopSection),
          if (_shoppingProofs().isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildProofPreviewStrip(_shoppingProofs()),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _shoppingTotalController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            decoration: _driverDialogInputDecoration(
              labelText: 'Total belanja di struk',
              prefixText: 'Rp ',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _deliveryFeeOverrideController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            decoration: _driverDialogInputDecoration(
              labelText: 'Edit ongkir nitip (opsional)',
              prefixText: 'Rp ',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: widget.isProcessing || _isUploadingReceipt
                ? null
                : _uploadReceiptPhoto,
            icon: _isUploadingReceipt
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(
              _isUploadingReceipt
                  ? 'Mengupload Struk...'
                  : !widget.order.hasProof('receipt')
                  ? 'Upload Foto Struk'
                  : 'Foto Struk Siap',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _receiptNoteController,
            minLines: 1,
            maxLines: 3,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            decoration: _driverDialogInputDecoration(
              labelText: 'Catatan nota',
              hintText: 'Contoh: satu item kosong, diganti ukuran lain',
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.isProcessing || _isUploadingReceipt
                  ? null
                  : _save,
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
              label: const Text('Simpan Checkout Nitip'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemEditor(DriverShoppingItemModel item) {
    final isAvailable = _availability[item.id] ?? item.isAvailable;

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
                    _dirtyAvailabilityIds.add(item.id);
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
        ],
      ),
    );
  }

  Widget _buildStopSection(DriverShoppingStopModel stop) {
    final activeItems = stop.items;

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
          _buildHeavyToggleForItems(activeItems),
          const SizedBox(height: 8),
          ...activeItems.map(_buildItemEditor),
        ],
      ),
    );
  }

  Widget _buildHeavyToggleForItems(List<DriverShoppingItemModel> items) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final availableItems = items
        .where((item) => _availability[item.id] ?? item.isAvailable)
        .toList(growable: false);
    final targetItems = availableItems.isEmpty ? items : availableItems;
    final isHeavy = targetItems.any((item) => _heavy[item.id] ?? item.isHeavy);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: CheckboxListTile(
        value: isHeavy,
        onChanged: (value) {
          final nextValue = value ?? false;
          setState(() {
            for (final item in items) {
              _dirtyHeavyIds.add(item.id);
              _heavy[item.id] = nextValue;
            }
          });
        },
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
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
    );
  }

  List<DriverOrderProofModel> _shoppingProofs() {
    return widget.order.proofs
        .where(
          (proof) =>
              (proof.type == 'receipt' || proof.type == 'store_closed') &&
              (proof.photoUrl ?? '').trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  Widget _buildProofPreviewStrip(List<DriverOrderProofModel> proofs) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: proofs
          .map(
            (proof) => InkWell(
              onTap: () => _showProofPreview(proof),
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        proof.photoUrl!,
                        width: 96,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 96,
                          height: 72,
                          color: AppColors.background,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      proof.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  void _showProofPreview(DriverOrderProofModel proof) {
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

  Future<void> _uploadReceiptPhoto() async {
    final photo = await _pickImage(context);
    if (photo == null || !mounted) {
      return;
    }

    setState(() => _isUploadingReceipt = true);
    final error = await widget.onUploadReceipt(
      photo,
      _receiptNoteController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() => _isUploadingReceipt = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Foto struk berhasil diupload.'),
        backgroundColor: error == null ? null : AppColors.error,
      ),
    );
  }

  Future<void> _save() async {
    final shoppingTotalAmount = _parseCurrencyInput(
      _shoppingTotalController.text,
    );
    final deliveryFeeOverrideRaw = _deliveryFeeOverrideController.text.trim();
    final deliveryFeeOverride = deliveryFeeOverrideRaw.isEmpty
        ? null
        : _parseCurrencyInput(deliveryFeeOverrideRaw);

    if (shoppingTotalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Total belanja di struk wajib diisi.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!widget.order.hasProof('receipt')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload foto struk dulu.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final payload = widget.order.shoppingItems
        .map(
          (item) => <String, dynamic>{
            'id': item.id,
            'quantity': item.quantity,
            'is_available': _availability[item.id] ?? item.isAvailable,
            'notes': item.notes,
            'is_heavy': _heavy[item.id] ?? item.isHeavy,
          },
        )
        .toList(growable: false);

    final error = await widget.onSave(
      payload,
      shoppingTotalAmount,
      deliveryFeeOverride == null || deliveryFeeOverride <= 0
          ? null
          : deliveryFeeOverride,
      _receiptNoteController.text.trim(),
      null,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Checkout nitip berhasil disimpan.'),
        backgroundColor: error == null ? null : AppColors.error,
      ),
    );

    if (error == null) {
      setState(_syncControllers);
    }
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
    required XFile storeClosedPhoto,
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
                          storeClosedPhoto: report.storeClosedPhoto,
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
                      textStyle: GoogleFonts.nunitoSans(
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
    required this.storeClosedPhoto,
  });

  final int pickupLocationId;
  final String reason;
  final XFile storeClosedPhoto;
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
  XFile? _storeClosedPhoto;

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
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: _driverDialogInputDecoration(
                        labelText: 'Merchant',
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
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: _driverDialogInputDecoration(
                        labelText: 'Alasan',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final photo = await _pickImage(context);
                        if (photo == null || !mounted) {
                          return;
                        }
                        setState(() => _storeClosedPhoto = photo);
                      },
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: Text(
                        _storeClosedPhoto == null
                            ? 'Upload Foto Toko Tutup'
                            : 'Foto Toko Siap',
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
                            final photo = _storeClosedPhoto;
                            if (photo == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Foto toko tutup wajib diupload.',
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              return;
                            }
                            Navigator.of(context).pop(
                              _FailedPickupReport(
                                pickupLocationId: _selectedPickupLocationId,
                                reason: reason,
                                storeClosedPhoto: photo,
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

double _parseCurrencyInput(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleaned.isEmpty) {
    return 0;
  }

  return double.tryParse(cleaned) ?? 0;
}

Future<XFile?> _pickImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil dari kamera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      );
    },
  );

  if (source == null) {
    return null;
  }

  return ImagePicker().pickImage(
    source: source,
    imageQuality: 76,
    maxWidth: 1600,
  );
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
