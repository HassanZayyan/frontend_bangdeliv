import 'package:flutter/material.dart';

import '../../config/app_colors.dart';

class BangNegotiationCancelOption {
  const BangNegotiationCancelOption({
    required this.action,
    required this.label,
    required this.icon,
  });

  final String action;
  final String label;
  final IconData icon;
}

Future<String?> showBangNegotiationCancelSheet(
  BuildContext context, {
  required List<BangNegotiationCancelOption> options,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in options)
              ListTile(
                leading: Icon(option.icon),
                title: Text(option.label),
                onTap: () => Navigator.of(sheetContext).pop(option.action),
              ),
          ],
        ),
      );
    },
  );
}
