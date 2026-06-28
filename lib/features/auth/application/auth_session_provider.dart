import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user_profile_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/firebase_notification_service.dart';
import '../../../core/di/app_providers.dart';

enum SessionUserRole { guest, customer, driver, admin, unknown }

enum DriverAccessState { none, active, pending, rejected, suspended, unknown }

class AuthSessionState {
  final bool initialized;
  final bool isAuthenticated;
  final SessionUserRole role;
  final DriverAccessState driverAccessState;
  final UserProfileModel? profile;

  const AuthSessionState({
    required this.initialized,
    required this.isAuthenticated,
    required this.role,
    required this.driverAccessState,
    required this.profile,
  });

  const AuthSessionState.uninitialized()
    : initialized = false,
      isAuthenticated = false,
      role = SessionUserRole.guest,
      driverAccessState = DriverAccessState.none,
      profile = null;

  const AuthSessionState.guest()
    : initialized = true,
      isAuthenticated = false,
      role = SessionUserRole.guest,
      driverAccessState = DriverAccessState.none,
      profile = null;

  factory AuthSessionState.fromProfile(UserProfileModel profile) {
    final role = _mapRole(profile.role);
    final driverAccessState = _mapDriverAccessState(
      profile.driverProfile?.registrationStatus,
    );

    return AuthSessionState(
      initialized: true,
      isAuthenticated: true,
      role: role,
      driverAccessState: role == SessionUserRole.driver
          ? driverAccessState
          : DriverAccessState.none,
      profile: profile,
    );
  }

  static SessionUserRole _mapRole(String value) {
    final normalized = value.trim().toLowerCase();

    switch (normalized) {
      case 'customer':
        return SessionUserRole.customer;
      case 'driver':
        return SessionUserRole.driver;
      case 'admin':
        return SessionUserRole.admin;
      case '':
        return SessionUserRole.guest;
      default:
        return SessionUserRole.unknown;
    }
  }

  static DriverAccessState _mapDriverAccessState(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();

    switch (normalized) {
      case 'active':
        return DriverAccessState.active;
      case 'pending':
        return DriverAccessState.pending;
      case 'rejected':
        return DriverAccessState.rejected;
      case 'suspended':
        return DriverAccessState.suspended;
      case '':
        return DriverAccessState.none;
      default:
        return DriverAccessState.unknown;
    }
  }
}

class AuthSessionNotifier extends Notifier<AuthSessionState> {
  static const Duration _logoutCleanupTimeout = Duration(seconds: 3);

  bool _isInitializing = false;
  bool _isLoggingOut = false;

  @override
  AuthSessionState build() {
    return const AuthSessionState.uninitialized();
  }

  Future<void> initialize() async {
    if (_isInitializing || state.initialized) {
      return;
    }

    _isInitializing = true;
    try {
      await refreshSession();
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> handleLoginSuccess() async {
    await refreshSession();
  }

  void syncProfile(UserProfileModel profile) {
    state = AuthSessionState.fromProfile(profile);
  }

  Future<void> refreshSession() async {
    await _refreshSession(clearLocalSessionOnFailure: true);
  }

  Future<void> refreshSessionPreservingExisting() async {
    await _refreshSession(clearLocalSessionOnFailure: false);
  }

  Future<void> _refreshSession({
    required bool clearLocalSessionOnFailure,
  }) async {
    bool hasToken = false;
    try {
      hasToken = await AuthService.hasAccessToken();
    } catch (_) {
      state = const AuthSessionState.guest();
      return;
    }

    if (!hasToken) {
      state = const AuthSessionState.guest();
      return;
    }

    try {
      final profile = await AuthService.fetchCurrentUserProfile();
      state = AuthSessionState.fromProfile(profile);
    } on AuthException {
      await _handleRefreshFailure(
        clearLocalSessionOnFailure: clearLocalSessionOnFailure,
      );
    } catch (_) {
      await _handleRefreshFailure(
        clearLocalSessionOnFailure: clearLocalSessionOnFailure,
      );
    }
  }

  Future<void> _handleRefreshFailure({
    required bool clearLocalSessionOnFailure,
  }) async {
    if (!clearLocalSessionOnFailure && state.isAuthenticated) {
      return;
    }

    await AuthService.clearLocalSession();
    FirebaseNotificationService.clearBackendTokenSync();
    state = const AuthSessionState.guest();
  }

  Future<void> logout() async {
    if (_isLoggingOut) {
      return;
    }

    _isLoggingOut = true;
    Map<String, String>? logoutHeaders;
    try {
      logoutHeaders = await AuthService.authorizedHeaders();
    } catch (_) {
      logoutHeaders = null;
    }

    try {
      state = const AuthSessionState.guest();
      await AuthService.clearLocalSession();
      FirebaseNotificationService.clearBackendTokenSync();
      unawaited(AuthService.signOutFromGoogle());

      unawaited(_cleanupRemoteLogout(headers: logoutHeaders));
    } finally {
      _isLoggingOut = false;
    }
  }

  Future<void> _cleanupRemoteLogout({Map<String, String>? headers}) async {
    try {
      await FirebaseNotificationService.unregisterCurrentToken(
        unregisterToken: (token) {
          return ref
              .read(deviceTokenApiServiceProvider)
              .unregisterDeviceToken(token: token, headers: headers);
        },
      ).timeout(_logoutCleanupTimeout);
    } catch (_) {
      // Local logout has already completed. Remote token cleanup is best effort.
    }

    try {
      await AuthService.logout(headers: headers).timeout(_logoutCleanupTimeout);
    } catch (_) {
      // Local logout has already completed. Remote session revoke is best effort.
    }
  }
}

final authSessionProvider =
    NotifierProvider<AuthSessionNotifier, AuthSessionState>(
      AuthSessionNotifier.new,
    );
