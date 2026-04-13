import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile_model.dart';
import '../services/auth_service.dart';

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
  bool _isInitializing = false;

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

  Future<void> refreshSession() async {
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
      await AuthService.clearLocalSession();
      state = const AuthSessionState.guest();
    } catch (_) {
      await AuthService.clearLocalSession();
      state = const AuthSessionState.guest();
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    state = const AuthSessionState.guest();
  }
}

final authSessionProvider =
    NotifierProvider<AuthSessionNotifier, AuthSessionState>(
      AuthSessionNotifier.new,
    );
