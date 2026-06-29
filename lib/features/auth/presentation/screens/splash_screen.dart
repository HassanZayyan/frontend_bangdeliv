import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../config/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _brandName = 'Bang Deliv';
  static const _brandStatusBarStyle = SystemUiOverlayStyle(
    statusBarColor: AppColors.white,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _dividerScale;
  late final Animation<double> _textProgress;
  late final Animation<double> _loadingOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward();

    _logoScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.42, curve: Curves.easeOutBack),
    );
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.28, curve: Curves.easeOut),
    );
    _dividerScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.56, curve: Curves.easeOutCubic),
    );
    _textProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.36, 0.92, curve: Curves.easeOut),
    );
    _loadingOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.72, 1, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _brandStatusBarStyle,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final typedLength = _typedLength;
                  final typedText = _brandName.substring(0, typedLength);

                  return Semantics(
                    label: 'Bang Deliv',
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Opacity(
                                  opacity: _logoOpacity.value,
                                  child: Transform.scale(
                                    scale: 0.88 + (_logoScale.value * 0.12),
                                    child: const _BrandMark(),
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Transform.scale(
                                  scaleY: _dividerScale.value,
                                  child: Container(
                                    width: 3,
                                    height: 82,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                SizedBox(
                                  width: 214,
                                  child: ClipRect(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Text(
                                            typedText,
                                            maxLines: 1,
                                            softWrap: false,
                                            strutStyle: const StrutStyle(
                                              fontSize: 42,
                                              height: 1.18,
                                            ),
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 42,
                                              fontWeight: FontWeight.w800,
                                              height: 1.18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 34),
                          Opacity(
                            opacity: _loadingOpacity.value,
                            child: const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  int get _typedLength {
    if (_textProgress.value <= 0) {
      return 0;
    }

    final length = (_brandName.length * _textProgress.value).ceil();
    return math.min(_brandName.length, math.max(1, length));
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryLight, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1AF05B24),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.jpg',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
