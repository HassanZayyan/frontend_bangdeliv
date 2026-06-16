import 'package:shared_preferences/shared_preferences.dart';

class NotificationNavigationService {
  NotificationNavigationService._();

  static const String _pendingRouteKey = 'pending_notification_route';
  static String? _memoryPendingRoute;

  static Future<void> queueRoute(String route) async {
    final normalized = normalizeRoute(route);
    if (normalized == null) {
      return;
    }

    _memoryPendingRoute = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingRouteKey, normalized);
  }

  static Future<String?> takePendingRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final route = normalizeRoute(
      _memoryPendingRoute ?? prefs.getString(_pendingRouteKey),
    );

    _memoryPendingRoute = null;
    await prefs.remove(_pendingRouteKey);

    return route;
  }

  static String? normalizeRoute(String? route) {
    final normalized = route?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasAbsolutePath) {
      return null;
    }

    final path = uri.path;
    final isOrderChatRoute = RegExp(r'^/orders/[1-9]\d*/chat$').hasMatch(path);
    final isOrderTrackRoute = RegExp(
      r'^/orders/[1-9]\d*/track$',
    ).hasMatch(path);
    final isDriverActiveOrderRoute = RegExp(
      r'^/driver/orders/[1-9]\d*/active$',
    ).hasMatch(path);
    if (!isOrderChatRoute && !isOrderTrackRoute && !isDriverActiveOrderRoute) {
      return null;
    }

    return uri.hasQuery ? '$path?${uri.query}' : path;
  }
}
