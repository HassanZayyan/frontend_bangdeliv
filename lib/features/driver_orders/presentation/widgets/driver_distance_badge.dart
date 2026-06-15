import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../models/driver_order_model.dart';
import '../../application/driver_dispatch_presenter.dart';

class DriverDistanceBadge extends StatelessWidget {
  const DriverDistanceBadge({required this.dispatch, super.key});

  final DriverDispatchModel? dispatch;

  @override
  Widget build(BuildContext context) {
    final viewData = DriverDispatchPresenter.present(dispatch);
    final colors = _colorsFor(viewData.bucket);

    return Semantics(
      label: 'Jarak driver ke titik jemput ${viewData.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: colors.foreground.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.near_me_outlined, size: 13, color: colors.foreground),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                viewData.label,
                style: TextStyle(
                  color: colors.foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _BadgeColors _colorsFor(String bucket) {
    switch (bucket) {
      case 'NEAR':
        return _BadgeColors(
          background: AppColors.success.withValues(alpha: 0.12),
          foreground: AppColors.success,
        );
      case 'MEDIUM':
        return _BadgeColors(
          background: AppColors.warning.withValues(alpha: 0.14),
          foreground: const Color(0xFFB45309),
        );
      case 'FAR':
        return _BadgeColors(
          background: AppColors.error.withValues(alpha: 0.10),
          foreground: AppColors.error,
        );
      default:
        return _BadgeColors(
          background: AppColors.surfaceAlt,
          foreground: AppColors.textSecondary,
        );
    }
  }
}

class _BadgeColors {
  const _BadgeColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}
