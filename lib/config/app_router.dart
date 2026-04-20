import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/register_driver_screen.dart';
import '../screens/register_success_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/driver_home_screen.dart';
import '../screens/driver_orders_screen.dart';
import '../screens/driver_history_screen.dart';
import '../screens/driver_profile_screen.dart';
import '../screens/driver_active_order_screen.dart';
import '../screens/driver_verification_status_screen.dart';
import '../screens/activity_screen.dart';
import '../screens/home_screen.dart';
import '../screens/chatbot_screen.dart';
import '../screens/order_history_screen.dart';
import '../screens/track_order_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/change_password_screen.dart';
import '../screens/saved_addresses_screen.dart';
import '../screens/add_address_screen.dart';
import '../screens/address_location_picker_screen.dart';
import '../models/user_profile_model.dart';
import '../models/food_model.dart';
import '../models/merchant_model.dart';
import '../providers/auth_session_provider.dart';
import '../screens/notifications_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/privacy_map_screen.dart';
import '../screens/main_layout.dart';
import '../screens/driver_main_layout.dart';
import '../screens/menu_detail_screen.dart';
import '../screens/merchant_detail_screen.dart';
import 'app_routes.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _driverShellNavigatorKey =
    GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final session = ref.read(authSessionProvider);
      final location = state.matchedLocation;

      return _resolveRedirect(
        session: session,
        location: location,
        fullLocation: state.uri.toString(),
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.registerDriver,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RegisterDriverScreen(),
      ),
      GoRoute(
        path: AppRoutes.registerSuccess,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RegisterSuccessScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.chatbot,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ChatbotScreen(),
      ),
      GoRoute(
        path: AppRoutes.track,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TrackOrderScreen(),
      ),
      GoRoute(
        path: AppRoutes.menuDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final menuId = state.pathParameters['menuId'] ?? '';
          final extra = state.extra;
          final initialMenu = extra is FoodModel ? extra : null;

          return MenuDetailScreen(menuId: menuId, initialMenu: initialMenu);
        },
      ),
      GoRoute(
        path: AppRoutes.merchantDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final merchantId = state.pathParameters['merchantId'] ?? '';
          final extra = state.extra;
          final initialMerchant = extra is MerchantModel ? extra : null;

          return MerchantDetailScreen(
            merchantId: merchantId,
            initialMerchant: initialMerchant,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.addresses,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SavedAddressesScreen(),
      ),
      GoRoute(
        path: AppRoutes.addAddress,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          SavedAddressModel? initialAddress;
          final extra = state.extra;

          if (extra is SavedAddressModel) {
            initialAddress = extra;
          } else if (extra is Map) {
            initialAddress = SavedAddressModel.fromJson(
              Map<String, dynamic>.from(extra),
            );
          }

          return AddAddressScreen(initialAddress: initialAddress);
        },
      ),
      GoRoute(
        path: AppRoutes.addressLocationPicker,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          double? initialLatitude;
          double? initialLongitude;

          final extra = state.extra;
          if (extra is Map) {
            final rawLat = extra['latitude'];
            final rawLng = extra['longitude'];

            if (rawLat is num) {
              initialLatitude = rawLat.toDouble();
            } else if (rawLat is String) {
              initialLatitude = double.tryParse(rawLat);
            }

            if (rawLng is num) {
              initialLongitude = rawLng.toDouble();
            } else if (rawLng is String) {
              initialLongitude = double.tryParse(rawLng);
            }
          }

          return AddressLocationPickerScreen(
            initialLatitude: initialLatitude,
            initialLongitude: initialLongitude,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.notificationSettings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacyMapPreview,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PrivacyMapScreen(),
      ),
      GoRoute(
        path: AppRoutes.driverVerificationStatus,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DriverVerificationStatusScreen(),
      ),
      // ShellRoute untuk menu yang punya BottomNavigationBar
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainLayout(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.activity,
            builder: (context, state) => const ActivityScreen(),
          ),
          GoRoute(
            path: AppRoutes.history,
            builder: (context, state) => const OrderHistoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      ShellRoute(
        navigatorKey: _driverShellNavigatorKey,
        builder: (context, state, child) {
          return DriverMainLayout(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.driverHome,
            builder: (context, state) => const DriverHomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.driverOrders,
            builder: (context, state) => const DriverOrdersScreen(),
          ),
          GoRoute(
            path: AppRoutes.driverOrderActive,
            builder: (context, state) {
              final orderId = state.pathParameters['orderId'] ?? '';
              return DriverActiveOrderScreen(orderId: orderId);
            },
          ),
          GoRoute(
            path: AppRoutes.driverHistory,
            builder: (context, state) => const DriverHistoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.driverProfile,
            builder: (context, state) => const DriverProfileScreen(),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  ref.listen<AuthSessionState>(authSessionProvider, (previous, next) {
    router.refresh();
  });

  return router;
});

String? _resolveRedirect({
  required AuthSessionState session,
  required String location,
  required String fullLocation,
}) {
  if (!session.initialized) {
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }

  final isPublicRoute = _publicRoutes.contains(location);
  final isGuestAccessibleRoute = _guestAccessibleRoutes.contains(location);

  if (!session.isAuthenticated) {
    if (location == AppRoutes.splash) {
      return AppRoutes.home;
    }

    if (isPublicRoute || isGuestAccessibleRoute) {
      return null;
    }

    return _buildLoginRouteWithReturnTo(fullLocation);
  }

  if (location == AppRoutes.splash || isPublicRoute) {
    return _defaultRouteFor(session);
  }

  if (session.role == SessionUserRole.customer) {
    if (_isDriverRoute(location)) {
      return AppRoutes.home;
    }

    return null;
  }

  if (session.role == SessionUserRole.driver) {
    final isDriverActive =
        session.driverAccessState == DriverAccessState.active;

    if (isDriverActive) {
      if (_customerOnlyRoutes.contains(location)) {
        return AppRoutes.driverHome;
      }

      if (location == AppRoutes.profile) {
        return AppRoutes.driverHome;
      }

      return null;
    }

    if (_driverNonActiveAllowedRoutes.contains(location)) {
      return null;
    }

    return AppRoutes.driverVerificationStatus;
  }

  if (session.role == SessionUserRole.admin) {
    if (location == AppRoutes.profile) {
      return null;
    }

    return AppRoutes.profile;
  }

  return AppRoutes.login;
}

String _buildLoginRouteWithReturnTo(String targetLocation) {
  final normalizedTarget = targetLocation.trim();
  if (normalizedTarget.isEmpty ||
      !normalizedTarget.startsWith('/') ||
      normalizedTarget.startsWith(AppRoutes.login)) {
    return AppRoutes.login;
  }

  final encoded = Uri.encodeComponent(normalizedTarget);
  return '${AppRoutes.login}?returnTo=$encoded';
}

String _defaultRouteFor(AuthSessionState session) {
  switch (session.role) {
    case SessionUserRole.customer:
      return AppRoutes.home;
    case SessionUserRole.driver:
      return session.driverAccessState == DriverAccessState.active
          ? AppRoutes.driverHome
          : AppRoutes.driverVerificationStatus;
    case SessionUserRole.admin:
      return AppRoutes.profile;
    case SessionUserRole.guest:
    case SessionUserRole.unknown:
      return AppRoutes.login;
  }
}

const Set<String> _publicRoutes = {
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.registerSuccess,
  AppRoutes.forgotPassword,
};

const Set<String> _guestAccessibleRoutes = {
  AppRoutes.home,
  AppRoutes.menuDetail,
  AppRoutes.merchantDetail,
};

const Set<String> _customerOnlyRoutes = {
  AppRoutes.home,
  AppRoutes.activity,
  AppRoutes.history,
  AppRoutes.track,
  AppRoutes.addresses,
  AppRoutes.addAddress,
  AppRoutes.registerDriver,
};

const Set<String> _driverNonActiveAllowedRoutes = {
  AppRoutes.driverVerificationStatus,
  AppRoutes.editProfile,
  AppRoutes.changePassword,
};

bool _isDriverRoute(String location) {
  final normalized = location.trim();
  return normalized == AppRoutes.driverVerificationStatus ||
      normalized.startsWith('/driver/');
}
