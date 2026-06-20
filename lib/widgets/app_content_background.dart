import 'package:flutter/material.dart';

import '../config/app_colors.dart';

class AppContentBackground extends StatelessWidget {
  const AppContentBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.white, AppColors.background],
          stops: [0, 0.42],
        ),
      ),
      child: child,
    );
  }
}
