import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/application/app_lifecycle_provider.dart';
import '../../../models/driver_order_model.dart';
import '../../../utils/order_status.dart';
import '../../../core/di/app_providers.dart';
import '../../auth/application/auth_session_provider.dart';
import 'driver_order_providers.dart';

Duration driverLocationReportInterval = const Duration(seconds: 10);

final driverLocationSourceProvider = Provider<DriverLocationSource>((ref) {
  return GeolocatorDriverLocationSource();
});

final driverLocationReporterProvider =
    NotifierProvider<
      DriverLocationReporterNotifier,
      DriverLocationReporterState
    >(DriverLocationReporterNotifier.new);

class DriverLocationReporterState {
  const DriverLocationReporterState({
    this.activeOrderId,
    this.latestPosition,
    this.reporting = false,
    this.permissionGranted = false,
    this.errorMessage,
  });

  final String? activeOrderId;
  final DriverLocationSnapshot? latestPosition;
  final bool reporting;
  final bool permissionGranted;
  final String? errorMessage;
}

class DriverLocationSnapshot {
  DriverLocationSnapshot({
    required this.latitude,
    required this.longitude,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final double latitude;
  final double longitude;
  final DateTime updatedAt;

  factory DriverLocationSnapshot.fromPosition(Position position) {
    return DriverLocationSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      updatedAt: position.timestamp,
    );
  }
}

abstract class DriverLocationSource {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<DriverLocationSnapshot> getCurrentPosition();
  Stream<DriverLocationSnapshot> getPositionStream();
}

class GeolocatorDriverLocationSource implements DriverLocationSource {
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 8,
  );

  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  @override
  Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }

  @override
  Future<DriverLocationSnapshot> getCurrentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: _locationSettings,
    );

    return DriverLocationSnapshot.fromPosition(position);
  }

  @override
  Stream<DriverLocationSnapshot> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).map(DriverLocationSnapshot.fromPosition);
  }
}

class DriverLocationReporterNotifier
    extends Notifier<DriverLocationReporterState> {
  StreamSubscription<DriverLocationSnapshot>? _positionSubscription;
  Timer? _sendTimer;
  String? _activeOrderId;
  DriverLocationSnapshot? _latestPosition;
  bool _permissionGranted = false;
  bool _sendInFlight = false;
  String? _errorMessage;

  @override
  DriverLocationReporterState build() {
    ref.onDispose(_dispose);

    final lifecycle = ref.watch(appLifecycleStateProvider);
    final session = ref.watch(authSessionProvider);
    final orders = ref.watch(driverOrdersProvider).asData?.value;
    final target = isAppLifecycleResumed(lifecycle)
        ? _trackableOrder(session, orders)
        : null;

    scheduleMicrotask(() {
      if (ref.mounted) {
        unawaited(_syncTarget(target?.id));
      }
    });

    return _snapshot(target?.id);
  }

  DriverOrderModel? _trackableOrder(
    AuthSessionState session,
    DriverOrdersState? orders,
  ) {
    if (!session.isAuthenticated ||
        session.role != SessionUserRole.driver ||
        session.profile == null ||
        orders == null) {
      return null;
    }

    for (final order in orders.running) {
      if (isDriverLocationTrackable(
        order.statusCode,
        statusLabel: order.statusDisplayName,
      )) {
        return order;
      }
    }

    return null;
  }

  Future<void> _syncTarget(String? nextOrderId) async {
    if (nextOrderId == null || nextOrderId.trim().isEmpty) {
      _stopTracking();
      _emit(nextOrderId);
      return;
    }

    if (_activeOrderId == nextOrderId && _positionSubscription != null) {
      _emit(nextOrderId);
      return;
    }

    _stopTracking();
    _activeOrderId = nextOrderId;
    _errorMessage = null;
    _emit(nextOrderId);

    await _startTracking(nextOrderId);
  }

  Future<void> _startTracking(String orderId) async {
    try {
      final source = ref.read(driverLocationSourceProvider);
      final serviceEnabled = await source.isLocationServiceEnabled();
      if (!serviceEnabled || _activeOrderId != orderId || !ref.mounted) {
        if (!serviceEnabled) {
          _errorMessage = 'Layanan lokasi belum aktif.';
          _emit(orderId);
        }
        return;
      }

      var permission = await source.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await source.requestPermission();
      }

      if (_activeOrderId != orderId || !ref.mounted) {
        return;
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _permissionGranted = false;
        _errorMessage = 'Izin lokasi driver belum diberikan.';
        _emit(orderId);
        return;
      }

      _permissionGranted = true;
      _latestPosition = await source.getCurrentPosition();
      _emit(orderId);
      await _sendLatestPosition(orderId: orderId);

      if (_activeOrderId != orderId || !ref.mounted) {
        return;
      }

      _positionSubscription = source.getPositionStream().listen((position) {
        if (_activeOrderId != orderId || !ref.mounted) {
          return;
        }

        _latestPosition = position;
        _errorMessage = null;
        _emit(orderId);
      });

      _sendTimer = Timer.periodic(driverLocationReportInterval, (_) {
        unawaited(_sendLatestPosition(orderId: orderId));
      });
      _emit(orderId);
    } catch (error) {
      if (_activeOrderId == orderId && ref.mounted) {
        _errorMessage = error.toString();
        _emit(orderId);
      }
    }
  }

  Future<void> _sendLatestPosition({required String orderId}) async {
    final position = _latestPosition;
    if (_sendInFlight ||
        position == null ||
        _activeOrderId != orderId ||
        !ref.mounted) {
      return;
    }

    _sendInFlight = true;
    try {
      await ref
          .read(driverOrderRepositoryProvider)
          .updateDriverLocation(
            orderId: orderId,
            latitude: position.latitude,
            longitude: position.longitude,
            updatedAt: position.updatedAt,
          );
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _sendInFlight = false;
      if (ref.mounted) {
        _emit(orderId);
      }
    }
  }

  void _stopTracking() {
    _sendTimer?.cancel();
    _sendTimer = null;
    unawaited(_positionSubscription?.cancel());
    _positionSubscription = null;
    _activeOrderId = null;
    _permissionGranted = false;
    _errorMessage = null;
  }

  DriverLocationReporterState _snapshot(String? targetOrderId) {
    return DriverLocationReporterState(
      activeOrderId: targetOrderId ?? _activeOrderId,
      latestPosition: _latestPosition,
      reporting:
          _activeOrderId != null &&
          _positionSubscription != null &&
          _sendTimer != null,
      permissionGranted: _permissionGranted,
      errorMessage: _errorMessage,
    );
  }

  void _emit(String? targetOrderId) {
    state = _snapshot(targetOrderId);
  }

  void _dispose() {
    _stopTracking();
  }
}
