import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../utils/service_type.dart';

class ServiceVisualIcon extends StatelessWidget {
  const ServiceVisualIcon({
    super.key,
    required this.serviceCode,
    this.width = 72,
    this.height = 64,
    this.frameSize = 54,
    this.iconWidth = 76,
    this.iconHeight = 60,
    this.frameRadius = 10,
  });

  final String serviceCode;
  final double width;
  final double height;
  final double frameSize;
  final double iconWidth;
  final double iconHeight;
  final double frameRadius;

  @override
  Widget build(BuildContext context) {
    final normalizedCode = normalizeServiceTypeCode(serviceCode);
    final frameTop = ((height - frameSize).clamp(0.0, height) * 0.9).toDouble();

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: frameTop,
            child: Container(
              width: frameSize,
              height: frameSize,
              decoration: BoxDecoration(
                color: _frameColor(normalizedCode),
                borderRadius: BorderRadius.circular(frameRadius),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.85),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.035),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Image.asset(
              _assetPath(normalizedCode),
              width: iconWidth,
              height: iconHeight,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ],
      ),
    );
  }

  Color _frameColor(String normalizedCode) {
    return AppColors.white.withValues(alpha: 0.88);
  }

  String _assetPath(String normalizedCode) {
    switch (normalizedCode) {
      case ServiceTypeCodes.ride:
        return 'assets/images/services/service_ride_motor_simplified.png';
      case ServiceTypeCodes.shopping:
        return 'assets/images/services/service_shopping_basket_simplified.png';
      case ServiceTypeCodes.courier:
      default:
        return 'assets/images/services/service_courier_box_simplified.png';
    }
  }
}
