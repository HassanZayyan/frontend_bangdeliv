import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/order_status.dart';
import 'auth_session_provider.dart';
import 'driver_order_providers.dart';

final driverLocationTrackingProvider = NotifierProvider<
    DriverLocationTrackingNotifier, DriverLocationTrackingState>(
  DriverLocationTrackingNotifier.new,
);

class DriverLocationTrackingState {
  final bool isTracking;
  final bool isStarting;
  final bool permissionDenied;
  final String? orderId;
  final double? latitude;
  final double? longitude;
  final DateTime? lastSentAt;
  final String? message;

  const DriverLocationTrackingState({
    required this.isTracking,
    required this.isStarting,
    required this.permissionDenied,
    this.orderId,
    this.latitude,
    this.longitude,
    this.lastSentAt,
    this.message,
  });

  const DriverLocationTrackingState.idle()
      : isTracking = false,
        isStarting = false,
        permissionDenied = false,
        orderId = null,
        latitude = null,
        longitude = null,
        lastSentAt = null,
        message = null;

  DriverLocationTrackingState copyWith({
    bool? isTracking,
    bool? isStarting,
    bool? permissionDenied,
    String? orderId,
    double? latitude,
    double? longitude,
    DateTime? lastSentAt,
    String? message,
    bool clearOrderId = false,
    bool clearMessage = false,
    bool clearLocation = false,
    bool clearLastSentAt = false,
  }) {
    return DriverLocationTrackingState(
      isTracking: isTracking ?? this.isTracking,
      isStarting: isStarting ?? this.isStarting,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      orderId: clearOrderId ? null : (orderId ?? this.orderId),
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      lastSentAt: clearLastSentAt ? null : (lastSentAt ?? this.lastSentAt),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

class DriverLocationTrackingNotifier
    extends Notifier<DriverLocationTrackingState> {
  static const Duration _sendThrottle = Duration(seconds: 10);

  StreamSubscription<Position>? _gpsSubscription;
  DateTime? _lastSentAt;
  String? _activeOrderId;
  bool _sendInFlight = false;
  bool _startInProgress = false;

  @override
  DriverLocationTrackingState build() {
    ref.onDispose(_stopGpsStream);
    ref.listen<AuthSessionState>(authSessionProvider, (previous, next) {
      if (!next.isAuthenticated || next.role != SessionUserRole.driver) {
        stop();
      }
    });
    return const DriverLocationTrackingState.idle();
  }

  void syncForOrder({
    required String? orderId,
    required String? statusCode,
  }) {
    final normalizedOrderId = orderId?.trim();
    final shouldTrack = normalizedOrderId != null &&
        normalizedOrderId.isNotEmpty &&
        RegExp(r'^\d+$').hasMatch(normalizedOrderId) &&
        isDriverLocationTrackable(statusCode);

    if (!shouldTrack) {
      stop();
      return;
    }

    if (_activeOrderId == normalizedOrderId &&
        (_gpsSubscription != null || _startInProgress)) {
      return;
    }

    unawaited(_start(normalizedOrderId));
  }

  void stop() {
    _stopGpsStream();
    _activeOrderId = null;
    _lastSentAt = null;
    _sendInFlight = false;
    _startInProgress = false;
    state = state.copyWith(
      isTracking: false,
      isStarting: false,
      clearOrderId: true,
      clearMessage: true,
      clearLocation: true,
      clearLastSentAt: true,
    );
  }

  Future<void> sendCurrentLocationNow(String orderId) async {
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    await _sendLocation(orderId, position, force: true);
  }

  Future<void> _start(String orderId) async {
    _startInProgress = true;
    _stopGpsStream();
    _activeOrderId = orderId;

    try {
      state = state.copyWith(
        isStarting: true,
        isTracking: false,
        permissionDenied: false,
        orderId: orderId,
        clearMessage: true,
        clearLocation: true,
        clearLastSentAt: true,
      );

      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) {
        if (_activeOrderId != orderId) return;
        state = state.copyWith(
          isTracking: false,
          isStarting: false,
          permissionDenied: true,
          message: 'Izin lokasi belum aktif. Lokasi driver tidak bisa dikirim.',
        );
        return;
      }

      if (_activeOrderId != orderId) return;

      _gpsSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(
        (position) {
          if (_activeOrderId != orderId) return;
          _applyPosition(position);
        unawaited(_sendLocation(orderId, position));
      },
      onError: (_) {
        _stopGpsStream();
        state = state.copyWith(
          isStarting: false,
          isTracking: false,
            message: 'Gagal membaca GPS driver.',
          );
        },
      );

      state = state.copyWith(
        isTracking: true,
        isStarting: false,
        permissionDenied: false,
        clearMessage: true,
      );

      unawaited(sendCurrentLocationNow(orderId));
    } finally {
      if (_activeOrderId == orderId) {
        _startInProgress = false;
      }
    }
  }

  void _applyPosition(Position position) {
    state = state.copyWith(
      latitude: position.latitude,
      longitude: position.longitude,
      clearMessage: true,
    );
  }

  Future<void> _sendLocation(
    String orderId,
    Position position, {
    bool force = false,
  }) async {
    final now = DateTime.now().toUtc();
    if (!force &&
        _lastSentAt != null &&
        now.difference(_lastSentAt!) < _sendThrottle) {
      return;
    }

    if (_sendInFlight) return;

    _sendInFlight = true;
    try {
      final heading = position.heading.isFinite && position.heading >= 0
          ? position.heading
          : 0.0;

      await ref.read(driverOrderServiceProvider).updateLocation(
            orderId,
            position.latitude,
            position.longitude,
            heading,
          );

      _lastSentAt = now;
      state = state.copyWith(lastSentAt: now, clearMessage: true);
    } catch (_) {
      state = state.copyWith(
        message: 'Lokasi driver belum berhasil dikirim ke server.',
      );
    } finally {
      _sendInFlight = false;
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
        permissionDenied: true,
        message: 'GPS belum aktif di perangkat driver.',
      );
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        permissionDenied: true,
        message: 'Izin lokasi driver ditolak.',
      );
      return false;
    }

    return true;
  }

  void _stopGpsStream() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
  }
}
