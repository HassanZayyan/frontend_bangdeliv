import 'package:flutter/material.dart';

import '../../config/app_colors.dart';

enum BangActionButtonVariant { filled, outlined }

class BangActionButton extends StatelessWidget {
  const BangActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = BangActionButtonVariant.filled,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
    this.style,
    this.progressColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final BangActionButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isEnabled;
  final ButtonStyle? style;
  final Color? progressColor;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isEnabled && !isLoading ? onPressed : null;
    final child = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color:
                  progressColor ??
                  (variant == BangActionButtonVariant.filled
                      ? AppColors.white
                      : AppColors.primary),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    return switch (variant) {
      BangActionButtonVariant.filled => FilledButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
      BangActionButtonVariant.outlined => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
    };
  }
}
