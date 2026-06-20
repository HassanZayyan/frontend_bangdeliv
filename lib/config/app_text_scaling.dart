import 'package:flutter/widgets.dart';

class AppTextScaling {
  static const double maxScaleFactor = 1.3;
  static const double compactComponentMaxScaleFactor = 1.15;
  static const double denseComponentMaxScaleFactor = 1.12;

  const AppTextScaling._();

  static Widget clamp({required BuildContext context, required Widget child}) {
    final mediaQuery = MediaQuery.of(context);

    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: mediaQuery.textScaler.clamp(maxScaleFactor: maxScaleFactor),
      ),
      child: child,
    );
  }

  static MediaQueryData clampedMediaQueryData(
    BuildContext context, {
    double maxScaleFactor = AppTextScaling.maxScaleFactor,
  }) {
    final mediaQuery = MediaQuery.of(context);

    return mediaQuery.copyWith(
      textScaler: mediaQuery.textScaler.clamp(maxScaleFactor: maxScaleFactor),
    );
  }

  static Widget clampForCompactComponent({
    required BuildContext context,
    required Widget child,
    double maxScaleFactor = compactComponentMaxScaleFactor,
  }) {
    return MediaQuery(
      data: clampedMediaQueryData(context, maxScaleFactor: maxScaleFactor),
      child: child,
    );
  }

  static double effectiveScale(
    BuildContext context, {
    double maxScaleFactor = AppTextScaling.maxScaleFactor,
  }) {
    return MediaQuery.textScalerOf(context).scale(1).clamp(1.0, maxScaleFactor);
  }

  static double scaleProgress(
    BuildContext context, {
    double maxScaleFactor = AppTextScaling.maxScaleFactor,
  }) {
    final denominator = maxScaleFactor - 1;
    if (denominator <= 0) {
      return 0;
    }

    return ((effectiveScale(context, maxScaleFactor: maxScaleFactor) - 1) /
            denominator)
        .clamp(0.0, 1.0);
  }

  static double adaptive(
    BuildContext context, {
    required double normal,
    required double large,
    double maxScaleFactor = AppTextScaling.maxScaleFactor,
  }) {
    final progress = scaleProgress(context, maxScaleFactor: maxScaleFactor);

    return normal + ((large - normal) * progress);
  }
}
