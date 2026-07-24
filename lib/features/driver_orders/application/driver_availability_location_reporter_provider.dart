import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/application/app_lifecycle_provider.dart';
import '../../../core/di/app_providers.dart';
import '../../auth/application/auth_session_provider.dart';
import 'driver_location_reporter_provider.dart';
import 'driver_order_providers.dart';

Duration driverAvailabilityLocationReportInterval = const Duration(seconds: 60);

final driverAvailabilityLocationReporterProvider =
    NotifierProvider<
      DriverAvailabilityLocationReporterNotifier,
      DriverAvailabilityLocationReporterState
    >(DriverAvailabilityLocationReporterNotifier.new);

class DriverAvailabilityLocationReporterState {
  const DriverAvailabilityLocationReporterState({
    this.latestPosition,
    this.reporting = false,
    this.permissionGranted = false,
    this.errorMessage,
  });

  final DriverLocationSnapshot? latestPosition;
  final bool reporting;
  final bool permissionGranted;
  final String? errorMessage;
}

class DriverAvailabilityLocationReporterNotifier
    extends Notifier<DriverAvailabilityLocationReporterState> {
  StreamSubscription<DriverLocationSnapshot>? _positionSubscription;
  Timer? _sendTimer;
  DriverLocationSnapshot? _latestPosition;
  bool _permissionGranted = false;
  bool _sendInFlight = false;
  bool _desiredReporting = false;
  String? _errorMessage;

  @override
  DriverAvailabilityLocationReporterState build() {
    ref.onDispose(_dispose);

    final lifecycle = ref.watch(appLifecycleStateProvider);
    final isDriverSession = ref.watch(authSessionIdentityProvider).isDriver;
    final availability = isDriverSession
        ? ref.watch(driverAvailabilityProvider).asData?.value
        : null;
    final shouldReport =
        isAppLifecycleResumed(lifecycle) &&
        isDriverSession &&
        (availability?.status.trim().toLowerCase() == 'available');

    scheduleMicrotask(() {
      if (ref.mounted) {
        unawaited(_syncReporting(shouldReport));
      }
    });

    return _snapshot();
  }

  Future<void> _syncReporting(bool shouldReport) async {
    _desiredReporting = shouldReport;

    if (!shouldReport) {
      _stopReporting();
      _emit();
      return;
    }

    if (_sendTimer != null && _positionSubscription != null) {
      _emit();
      return;
    }

    await _startReporting();
  }

  Future<void> _startReporting() async {
    try {
      final source = ref.read(driverLocationSourceProvider);
      final serviceEnabled = await source.isLocationServiceEnabled();
      if (!serviceEnabled || !_desiredReporting || !ref.mounted) {
        if (!serviceEnabled) {
          _errorMessage = 'Layanan lokasi belum aktif.';
          _emit();
        }
        return;
      }

      var permission = await source.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await source.requestPermission();
      }

      if (!_desiredReporting || !ref.mounted) {
        return;
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _permissionGranted = false;
        _errorMessage = 'Izin lokasi driver belum diberikan.';
        _emit();
        return;
      }

      _permissionGranted = true;
      _latestPosition = await source.getCurrentPosition();
      _errorMessage = null;
      _emit();
      await _sendLatestPosition();

      if (!_desiredReporting || !ref.mounted) {
        return;
      }

      _positionSubscription = source.getPositionStream().listen((position) {
        if (!_desiredReporting || !ref.mounted) {
          return;
        }

        _latestPosition = position;
        _errorMessage = null;
        _emit();
      });

      _sendTimer = Timer.periodic(driverAvailabilityLocationReportInterval, (
        _,
      ) {
        unawaited(_sendLatestPosition());
      });
      _emit();
    } catch (error) {
      if (_desiredReporting && ref.mounted) {
        _errorMessage = error.toString();
        _emit();
      }
    }
  }

  Future<void> _sendLatestPosition() async {
    final position = _latestPosition;
    if (_sendInFlight ||
        position == null ||
        !_desiredReporting ||
        !ref.mounted) {
      return;
    }

    _sendInFlight = true;
    try {
      await ref
          .read(driverOrderRepositoryProvider)
          .updateCurrentDriverLocation(
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
        _emit();
      }
    }
  }

  void _stopReporting() {
    _sendTimer?.cancel();
    _sendTimer = null;
    unawaited(_positionSubscription?.cancel());
    _positionSubscription = null;
    _permissionGranted = false;
    _errorMessage = null;
  }

  DriverAvailabilityLocationReporterState _snapshot() {
    return DriverAvailabilityLocationReporterState(
      latestPosition: _latestPosition,
      reporting: _sendTimer != null && _positionSubscription != null,
      permissionGranted: _permissionGranted,
      errorMessage: _errorMessage,
    );
  }

  void _emit() {
    state = _snapshot();
  }

  void _dispose() {
    _stopReporting();
  }
}
