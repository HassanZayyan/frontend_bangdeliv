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
import '../utils/order_formatters.dart' hide formatCurrency;
import '../utils/service_type.dart';
import '../widgets/order_chat_badge_icon.dart';

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
                _TimelineCard(timeline: order.statusTimeline),
                const SizedBox(height: 12),
                _ActionCard(
                  order: order,
                  isProcessing: isProcessing,
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

class _MapCard extends StatelessWidget {
  final DriverOrderModel order;
  final DriverLocationTrackingState trackingState;

  const _MapCard({required this.order, required this.trackingState});

  @override
  Widget build(BuildContext context) {
    final pickup = _latLng(order.pickupLatitude, order.pickupLongitude);
    final dropoff = _latLng(order.dropoffLatitude, order.dropoffLongitude);
    final driver = _latLng(trackingState.latitude, trackingState.longitude);

    if (pickup == null && dropoff == null && driver == null) {
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
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: const InfoWindow(title: 'Posisi Anda'),
        ),
      if (pickup != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          infoWindow: const InfoWindow(title: 'Pickup'),
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
              child: _TrackingBadge(state: trackingState),
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
          _routeVisualizer(order.pickupAddress, order.dropoffAddress),
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

  Widget _routeVisualizer(String pickup, String dropoff) {
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jemput',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pickup,
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
          ),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 14,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tujuan',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dropoff,
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
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.isEmpty || parts.first.isEmpty
        ? '?'
        : parts.length == 1
            ? parts.first.characters.first.toUpperCase()
            : '${parts.first.characters.first}${parts.last.characters.first}'.toUpperCase();

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

class _TimelineCard extends StatelessWidget {
  final List<DriverOrderTimelineItemModel> timeline;

  const _TimelineCard({required this.timeline});

  @override
  Widget build(BuildContext context) {
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
          if (timeline.isEmpty)
            const Text(
              'Belum ada histori status.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            ...List.generate(timeline.length, (index) {
              final item = timeline[index];
              final isLast = index == timeline.length - 1;
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
                              color: AppColors.textSecondary.withValues(alpha: 0.2),
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
  final Future<void> Function(DriverOrderActionModel action) onTapAction;

  const _ActionCard({
    required this.order,
    required this.isProcessing,
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
