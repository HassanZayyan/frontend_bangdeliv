import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_colors.dart';
import '../models/driver_order_model.dart';
import '../providers/driver_order_providers.dart';
import '../utils/order_formatters.dart';
import '../utils/order_status.dart';
import '../utils/order_ui_helpers.dart';
import '../utils/service_type.dart';

class DriverOrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;

  const DriverOrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<DriverOrderDetailScreen> createState() =>
      _DriverOrderDetailScreenState();
}

class _DriverOrderDetailScreenState
    extends ConsumerState<DriverOrderDetailScreen> {
  static const int _locationThrottleSeconds = 10;
  DateTime? _lastLocationSentAt;

  // ── Self-view GPS stream ───────────────────────────────────────────────────
  StreamSubscription<Position>? _gpsSubscription;
  double? _selfLat;
  double? _selfLng;

  // ── Map controller ────────────────────────────────────────────────────────
  GoogleMapController? _mapController;

  // ── Action processing guard ───────────────────────────────────────────────
  bool _isUpdating = false;

  static const LatLng _fallbackCenter = LatLng(-7.0503, 110.4370);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncTrackingServices();
    });
  }

  @override
  void deactivate() {
    _stopAllTracking();
    super.deactivate();
  }

  @override
  void dispose() {
    _stopAllTracking();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Tracking lifecycle ────────────────────────────────────────────────────

  void _syncTrackingServices([DriverOrderModel? order]) {
    order ??= _getOrder();
    final statusCode = normalizeOrderStatusCode(order?.statusCode);
    final shouldTrack = statusCode == OrderStatusCodes.driverAssigned;

    if (shouldTrack) {
      _startGpsStream(order!.id);
    } else {
      _stopAllTracking();
    }
  }

  void _startGpsStream(String orderId) {
    if (_gpsSubscription != null) return;

    _gpsSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      (position) {
        if (!mounted) return;
        setState(() {
          _selfLat = position.latitude;
          _selfLng = position.longitude;
        });
        _sendLocationToBackend(orderId, position: position);
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
        );
      },
      onError: (_) {},
    );
  }

  void _stopAllTracking() {
    _lastLocationSentAt = null;
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
  }

  Future<void> _sendLocationToBackend(
    String orderId, {
    Position? position,
  }) async {
    try {
      final now = DateTime.now();
      if (_lastLocationSentAt != null &&
          now.difference(_lastLocationSentAt!).inSeconds <
              _locationThrottleSeconds) {
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final current = position ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          );

      await ref.read(driverOrderServiceProvider).updateLocation(
            orderId,
            current.latitude,
            current.longitude,
            current.heading,
          );
      _lastLocationSentAt = now;
    } catch (_) {}
  }

  // ── Order helper ──────────────────────────────────────────────────────────

  DriverOrderModel? _getOrder() {
    final state = ref.read(driverOrdersProvider).asData?.value;
    return _findRunningOrder(state);
  }

  // ── Server-driven action handler ──────────────────────────────────────────

  Future<void> _executeAction(DriverOrderAction action) async {
    if (_isUpdating || action.blocked) return;
    setState(() => _isUpdating = true);

    try {
      await ref.read(driverOrderServiceProvider).transitionOrderStatus(
            widget.orderId,
            action.actionCode,
          );
      await ref.read(driverOrdersProvider.notifier).refresh();
      _syncTrackingServices();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${action.label} berhasil.')),
      );

      // Pop screen if order is now terminal (no more actions)
      final updatedOrder = _getOrder();
      final isTerminal = updatedOrder == null ||
          (updatedOrder.availableActions.isEmpty &&
              isTerminalOrderStatus(updatedOrder.statusCode));
      if (isTerminal) {
        _stopAllTracking();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // ── Maps navigation ───────────────────────────────────────────────────────

  Future<void> _openMaps(String query) async {
    final uri = Uri.parse('google.navigation:q=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final fallback = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
      );
      if (await canLaunchUrl(fallback)) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<DriverOrdersState>>(driverOrdersProvider, (
      previous,
      next,
    ) {
      _syncTrackingServices(_findRunningOrder(next.asData?.value));
    });

    final ordersState = ref.watch(driverOrdersProvider);
    final data = ordersState.asData?.value;
    final order = _findRunningOrder(data);

    if (order == null) {
      if (ordersState.isLoading) {
        return Scaffold(
          appBar: AppBar(title: const Text('Detail Order')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      return Scaffold(
        appBar: AppBar(title: const Text('Detail Order')),
        body: const Center(child: Text('Order tidak ditemukan atau selesai.')),
      );
    }

    final isDriverAssigned =
        normalizeOrderStatusCode(order.statusCode) == OrderStatusCodes.driverAssigned;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Order #${order.id}'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Self-view map (only when DRIVER_ASSIGNED) ───────────────
            if (isDriverAssigned) ...[
              _buildSelfViewMap(order),
              const SizedBox(height: 16),
            ],

            // ── Service type badge + status card ──────────────────────────
            _buildStatusCard(order),
            const SizedBox(height: 16),

            // ── Route info card ───────────────────────────────────────────
            _buildRouteCard(order),
            const SizedBox(height: 16),

            // ── Order info card ───────────────────────────────────────────
            _buildOrderInfoCard(order),
            const SizedBox(height: 24),

            // ── Server-driven action buttons ──────────────────────────────
            ..._buildActionButtons(order),
          ],
        ),
      ),
    );
  }

  DriverOrderModel? _findRunningOrder(DriverOrdersState? state) {
    if (state == null) return null;

    for (final order in state.running) {
      if (order.id == widget.orderId) return order;
    }

    return null;
  }

  // ── Status card ───────────────────────────────────────────────────────────

  Widget _buildStatusCard(DriverOrderModel order) {
    final serviceLabel = serviceTypeLabel(order.serviceTypeCode);
    final serviceIcon = serviceTypeLeadingIcon(order.serviceTypeCode);
    final serviceColor = serviceTypeColor(order.serviceTypeCode);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: serviceColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(serviceIcon, color: serviceColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceLabel,
                  style: TextStyle(
                    color: serviceColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.statusCode.replaceAll('_', ' '),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          _infoChip(Icons.person_outline, order.customerName),
        ],
      ),
    );
  }

  // ── Route card ────────────────────────────────────────────────────────────

  Widget _buildRouteCard(DriverOrderModel order) {
    final serviceCode = normalizeServiceTypeCode(order.serviceTypeCode);
    final pickupLabel = serviceCode == ServiceTypeCodes.shopping
        ? 'Toko / Merchant'
        : serviceCode == ServiceTypeCodes.ride
            ? 'Titik Jemput'
            : 'Titik Pickup';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _pointRow(
            Icons.radio_button_checked,
            pickupLabel,
            order.pickupAddress,
            AppColors.primary,
            () => _openMaps(order.pickupAddress),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              children: List.generate(
                3,
                (_) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  width: 2,
                  height: 4,
                  color: AppColors.border,
                ),
              ),
            ),
          ),
          _pointRow(
            Icons.location_on,
            'Tujuan',
            order.dropoffAddress,
            AppColors.error,
            () => _openMaps(order.dropoffAddress),
          ),
        ],
      ),
    );
  }

  // ── Order info card ───────────────────────────────────────────────────────

  Widget _buildOrderInfoCard(DriverOrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _infoRow(Icons.shopping_bag_outlined, 'Total Item', '${order.itemCount} item'),
          const Divider(height: 20),
          _infoRow(
            Icons.monetization_on_outlined,
            'Estimasi Fee',
            formatCurrency(order.fee),
          ),
          if (order.acceptedAt != null) ...[
            const Divider(height: 20),
            _infoRow(Icons.access_time, 'Diterima', order.acceptedAt!),
          ],
        ],
      ),
    );
  }

  // ── Server-driven action buttons ──────────────────────────────────────────

  List<Widget> _buildActionButtons(DriverOrderModel order) {
    final actions = order.availableActions;

    if (actions.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, color: AppColors.success),
              SizedBox(width: 8),
              Text(
                'Order selesai atau tidak ada aksi tersedia.',
                style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ];
    }

    return actions.map((action) {
      final isBlocked = action.blocked;
      final isCod = action.actionCode == 'COLLECT_COD';

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: isCod
                    ? Colors.amber.shade700
                    : isBlocked
                        ? AppColors.textSecondary.withValues(alpha: 0.4)
                        : AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: isBlocked ? 0 : 2,
              ),
              onPressed: (_isUpdating || isBlocked) ? null : () => _executeAction(action),
              child: _isUpdating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isBlocked)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.lock_outline, color: Colors.white, size: 18),
                          ),
                        Text(
                          action.label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
            if (isBlocked && action.blockedReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  action.blockedReason!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.error.withValues(alpha: 0.8),
                  ),
                ),
              ),
          ],
        ),
      );
    }).toList();
  }

  // ── Self-view map ─────────────────────────────────────────────────────────

  Widget _buildSelfViewMap(DriverOrderModel order) {
    final hasSelf = _selfLat != null && _selfLng != null;
    final initialTarget = hasSelf ? LatLng(_selfLat!, _selfLng!) : _fallbackCenter;

    final markers = <Marker>{};

    if (hasSelf) {
      markers.add(
        Marker(
          markerId: const MarkerId('self'),
          position: LatLng(_selfLat!, _selfLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Posisi Anda'),
        ),
      );
    }

    if (order.dropoffLatitude != null && order.dropoffLongitude != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(order.dropoffLatitude!, order.dropoffLongitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Tujuan'),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialTarget,
                zoom: 15,
              ),
              markers: markers,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              onMapCreated: (c) => _mapController = c,
            ),
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.93),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  hasSelf ? '📍 Lokasi Anda sedang dilacak' : '⏳ Menunggu sinyal GPS...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 22),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _pointRow(
    IconData icon,
    String label,
    String address,
    Color iconColor,
    VoidCallback onNav,
  ) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                address,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.navigation_outlined, color: AppColors.primary, size: 20),
          onPressed: onNav,
          tooltip: 'Buka Navigasi',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ],
    );
  }

  // ── Service type helpers ──────────────────────────────────────────────────

}
