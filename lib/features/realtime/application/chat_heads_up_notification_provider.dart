import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_router.dart';
import '../../../config/app_routes.dart';
import '../../../models/order_chat_model.dart';
import '../../../services/firebase_notification_service.dart';
import '../../auth/application/auth_session_provider.dart';
import 'order_realtime_hub_provider.dart';

final chatHeadsUpNotificationProvider = Provider<void>((ref) {
  final session = ref.watch(authSessionProvider);
  final profile = session.profile;
  if (!session.isAuthenticated ||
      profile == null ||
      (session.role != SessionUserRole.customer &&
          session.role != SessionUserRole.driver)) {
    return;
  }

  final router = ref.watch(appRouterProvider);
  final subscription = ref
      .watch(orderRealtimeHubProvider)
      .events
      .where((event) => event.type == OrderRealtimeEventType.chat)
      .listen((event) {
        final message = event.chatMessage;
        if (message == null ||
            !message.hasServerId ||
            message.senderUserId == profile.id) {
          return;
        }

        final route = AppRoutes.orderChatPath(event.orderId);
        final currentRoute = router.routeInformationProvider.value.uri
            .toString();
        if (currentRoute == route) {
          return;
        }

        unawaited(
          FirebaseNotificationService.showLocalOrderChatNotification(
            orderId: event.orderId,
            messageId: message.id,
            title: _notificationTitle(message),
            body: _notificationBody(message),
          ),
        );
      });

  ref.onDispose(() {
    unawaited(subscription.cancel());
  });
});

String _notificationTitle(OrderChatMessageModel message) {
  final role = message.senderRole == 'driver' ? 'Driver' : 'Customer';
  final name = message.senderName.trim();
  if (name.isEmpty) {
    return 'Pesan dari $role';
  }

  return 'Pesan dari $role $name';
}

String _notificationBody(OrderChatMessageModel message) {
  final body = message.body.trim();
  if (body.isNotEmpty) {
    return body;
  }

  return message.hasAttachment ? 'Mengirim foto.' : 'Pesan chat baru.';
}
