import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/register_driver_screen.dart';
import '../features/auth/presentation/screens/register_success_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/driver_orders/presentation/screens/driver_home_screen.dart';
import '../features/driver_orders/presentation/screens/driver_orders_screen.dart';
import '../features/driver_orders/presentation/screens/driver_history_screen.dart';
import '../features/driver_orders/presentation/screens/driver_order_history_detail_screen.dart';
import '../features/profile/presentation/screens/driver_profile_screen.dart';
import '../features/driver_orders/presentation/screens/driver_active_order_screen.dart';
import '../features/profile/presentation/screens/driver_verification_status_screen.dart';
import '../features/orders/presentation/screens/activity_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/chatbot/presentation/screens/chatbot_screen.dart';
import '../features/orders/presentation/screens/order_history_screen.dart';
import '../features/orders/presentation/screens/order_chat_screen.dart';
import '../features/shopping/presentation/screens/shopping_add_item_screen.dart';
import '../features/shopping/presentation/screens/shopping_merchant_map_picker_screen.dart';
import '../features/tracking/presentation/screens/track_order_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/profile/presentation/screens/change_password_screen.dart';
import '../features/addresses/presentation/screens/saved_addresses_screen.dart';
import '../features/addresses/presentation/screens/add_address_screen.dart';
import '../features/addresses/presentation/screens/address_location_picker_screen.dart';
import '../features/addresses/presentation/screens/route_location_picker_screen.dart';
import '../models/user_profile_model.dart';
import '../models/route_location_picker_result.dart';
import '../models/food_model.dart';
import '../models/merchant_model.dart';
import '../models/customer_order_model.dart';
import '../features/auth/application/auth_session_provider.dart';
import '../features/driver_orders/application/driver_order_providers.dart';
import '../features/orders/application/customer_order_providers.dart';
import '../features/orders/application/order_chat_provider.dart';
import '../features/realtime/application/order_realtime_hub_provider.dart';
import '../features/tracking/application/customer_order_tracking_provider.dart';
import '../core/di/app_providers.dart';
import '../features/profile/presentation/screens/notification_settings_screen.dart';
import '../features/profile/presentation/screens/privacy_map_screen.dart';
import '../features/navigation/presentation/screens/main_layout.dart';
import '../features/navigation/presentation/screens/driver_main_layout.dart';
import '../features/home/presentation/screens/menu_detail_screen.dart';
import '../features/home/presentation/screens/merchant_detail_screen.dart';
import '../features/home/presentation/screens/nearby_merchants_screen.dart';
import 'app_routes.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _driverShellNavigatorKey =
    GlobalKey<NavigatorState>();

GoRoute _rootRoute({
  required String path,
  required Widget Function(BuildContext context, GoRouterState state) builder,
}) {
  return GoRoute(
    path: path,
    parentNavigatorKey: _rootNavigatorKey,
    pageBuilder: (context, state) =>
        _buildRootPage(state: state, child: builder(context, state)),
  );
}

CustomTransitionPage<dynamic> _buildRootPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<dynamic>(
    key: state.pageKey,
    opaque: true,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      );
    },
  );
}

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
      _rootRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      _rootRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      _rootRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      _rootRoute(
        path: AppRoutes.registerDriver,
        builder: (context, state) => const RegisterDriverScreen(),
      ),
      _rootRoute(
        path: AppRoutes.registerSuccess,
        builder: (context, state) => const RegisterSuccessScreen(),
      ),
      _rootRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      _rootRoute(
        path: AppRoutes.chatbot,
        builder: (context, state) => const ChatbotScreen(),
      ),
      _rootRoute(
        path: AppRoutes.track,
        builder: (context, state) => const TrackOrderScreen(),
      ),
      _rootRoute(
        path: AppRoutes.orderTrack,
        builder: (context, state) {
          final orderId = int.tryParse(state.pathParameters['orderId'] ?? '');
          if (orderId == null || orderId <= 0) {
            return const Scaffold(
              body: Center(child: Text('Tracking order tidak valid.')),
            );
          }

          return TrackOrderScreen.route(orderId: orderId);
        },
      ),
      _rootRoute(
        path: AppRoutes.shoppingAddItem,
        builder: (context, state) {
          final orderId = int.tryParse(state.pathParameters['orderId'] ?? '');
          final extra = state.extra;
          final detail = extra is ShoppingAddItemRouteArgs
              ? extra.detail
              : extra is CustomerOrderDetailModel
              ? extra
              : null;
          final targetPickupLocationId = extra is ShoppingAddItemRouteArgs
              ? extra.targetPickupLocationId
              : null;

          return ShoppingAddItemScreen(
            orderId: orderId,
            initialDetail: detail,
            targetPickupLocationId: targetPickupLocationId,
          );
        },
      ),
      _rootRoute(
        path: AppRoutes.shoppingMerchantMapPicker,
        builder: (context, state) {
          final extra = state.extra;
          return ShoppingMerchantMapPickerScreen(
            args: extra is ShoppingMerchantMapPickerArgs ? extra : null,
          );
        },
      ),
      _rootRoute(
        path: AppRoutes.chatbotShoppingMerchantMapPicker,
        builder: (context, state) {
          final extra = state.extra;
          return ShoppingMerchantMapPickerScreen(
            args: extra is ShoppingMerchantMapPickerArgs ? extra : null,
          );
        },
      ),
      _rootRoute(
        path: AppRoutes.orderChat,
        builder: (context, state) {
          final orderId = int.tryParse(state.pathParameters['orderId'] ?? '');
          if (orderId == null || orderId <= 0) {
            return const Scaffold(
              body: Center(child: Text('Order chat tidak valid.')),
            );
          }

          return OrderChatScreen(orderId: orderId);
        },
      ),
      _rootRoute(
        path: AppRoutes.menuDetail,
        builder: (context, state) {
          final menuId = state.pathParameters['menuId'] ?? '';
          final extra = state.extra;
          final initialMenu = extra is FoodModel ? extra : null;

          return MenuDetailScreen(menuId: menuId, initialMenu: initialMenu);
        },
      ),
      _rootRoute(
        path: AppRoutes.merchantDetail,
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
      _rootRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      _rootRoute(
        path: AppRoutes.changePassword,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      _rootRoute(
        path: AppRoutes.addresses,
        builder: (context, state) => const SavedAddressesScreen(),
      ),
      _rootRoute(
        path: AppRoutes.addressPicker,
        builder: (context, state) =>
            const SavedAddressesScreen(selectionMode: true),
      ),
      _rootRoute(
        path: AppRoutes.addAddress,
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
      _rootRoute(
        path: AppRoutes.addressLocationPicker,
        builder: (context, state) {
          double? initialLatitude;
          double? initialLongitude;
          var restrictAddressSearchToServiceArea = false;

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

            restrictAddressSearchToServiceArea =
                extra['restrictAddressSearchToServiceArea'] == true;
          }

          return AddressLocationPickerScreen(
            initialLatitude: initialLatitude,
            initialLongitude: initialLongitude,
            restrictAddressSearchToServiceArea:
                restrictAddressSearchToServiceArea,
          );
        },
      ),
      _rootRoute(
        path: AppRoutes.routeLocationPicker,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is RouteLocationPickerArgs) {
            return RouteLocationPickerScreen(args: extra);
          }

          return const Scaffold(
            body: Center(child: Text('Route picker tidak valid.')),
          );
        },
      ),
      _rootRoute(
        path: AppRoutes.notificationSettings,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      _rootRoute(
        path: AppRoutes.privacyMapPreview,
        builder: (context, state) => const PrivacyMapScreen(),
      ),
      _rootRoute(
        path: AppRoutes.driverVerificationStatus,
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
            path: AppRoutes.nearbyMerchants,
            builder: (context, state) => const NearbyMerchantsScreen(),
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
            path: AppRoutes.driverHistoryDetail,
            builder: (context, state) {
              final orderId = state.pathParameters['orderId'] ?? '';
              return DriverOrderHistoryDetailScreen(orderId: orderId);
            },
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
    final authChanged = previous?.isAuthenticated != next.isAuthenticated;
    final roleChanged = previous?.role != next.role;
    final userIdChanged = previous?.profile?.id != next.profile?.id;

    if (authChanged || roleChanged || userIdChanged) {
      ref.invalidate(homeDataProvider);

      ref.invalidate(customerOrdersProvider);
      ref.invalidate(customerOrderDetailProvider);
      ref.invalidate(customerSortedOrdersProvider);
      ref.invalidate(customerCompletedOrdersProvider);
      ref.invalidate(customerActivityOrdersProvider);
      ref.invalidate(customerOngoingOrdersProvider);
      ref.invalidate(customerCancelledOrdersProvider);
      ref.invalidate(customerActiveOrderProvider);
      ref.invalidate(orderRealtimeHubProvider);
      ref.invalidate(customerOrderTrackingProvider);
      ref.invalidate(orderChatProvider);

      ref.invalidate(driverOrdersProvider);
      ref.invalidate(driverHistoryProvider);
      ref.invalidate(driverActiveOrderProvider);
    }

    if (_shouldRefreshRouter(previous, next)) {
      router.refresh();
    }
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
  AppRoutes.shoppingAddItem,
  AppRoutes.shoppingMerchantMapPicker,
  AppRoutes.chatbotShoppingMerchantMapPicker,
  AppRoutes.addresses,
  AppRoutes.addressPicker,
  AppRoutes.addAddress,
  AppRoutes.registerDriver,
};

const Set<String> _driverNonActiveAllowedRoutes = {
  AppRoutes.driverVerificationStatus,
  AppRoutes.driverProfile,
  AppRoutes.editProfile,
  AppRoutes.changePassword,
  AppRoutes.notificationSettings,
  AppRoutes.privacyMapPreview,
};

bool _isDriverRoute(String location) {
  final normalized = location.trim();
  return normalized == AppRoutes.driverVerificationStatus ||
      normalized.startsWith('/driver/');
}

bool _shouldRefreshRouter(AuthSessionState? previous, AuthSessionState next) {
  if (previous == null) {
    return true;
  }

  return previous.initialized != next.initialized ||
      previous.isAuthenticated != next.isAuthenticated ||
      previous.role != next.role ||
      previous.driverAccessState != next.driverAccessState;
}
