import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/register_success_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/home_screen.dart';
import '../screens/chatbot_screen.dart';
import '../screens/order_history_screen.dart';
import '../screens/track_order_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/change_password_screen.dart';
import '../screens/saved_addresses_screen.dart';
import '../screens/add_address_screen.dart';
import '../models/user_profile_model.dart';
import '../screens/notifications_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/main_layout.dart';
import 'app_routes.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.login,
  routes: [
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
      path: AppRoutes.notifications,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: AppRoutes.notificationSettings,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NotificationSettingsScreen(),
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
          parentNavigatorKey: _shellNavigatorKey,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.orders,
          parentNavigatorKey: _shellNavigatorKey,
          builder: (context, state) => const OrderHistoryScreen(),
        ),
        GoRoute(
          path: AppRoutes.track,
          parentNavigatorKey: _shellNavigatorKey,
          builder: (context, state) => const TrackOrderScreen(),
        ),
        GoRoute(
          path: AppRoutes.profile,
          parentNavigatorKey: _shellNavigatorKey,
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);
