import 'package:flutter/material.dart';

import '../config/app_colors.dart';

class OrderChatBadgeIcon extends StatelessWidget {
  const OrderChatBadgeIcon({
    super.key,
    required this.unreadCount,
    this.iconColor = AppColors.primary,
  });

  final int unreadCount;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final label = unreadCount > 99 ? '99+' : unreadCount.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.sms_outlined, color: iconColor),
        if (unreadCount > 0)
          Positioned(
            top: -5,
            right: -7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
