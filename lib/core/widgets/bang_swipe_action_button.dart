import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_colors.dart';

class BangSwipeActionButton extends StatefulWidget {
  const BangSwipeActionButton({
    super.key,
    required this.label,
    required this.onSubmit,
    this.loadingLabel = 'Memproses...',
    this.isLoading = false,
    this.isEnabled = true,
    this.height = 52,
    this.color = AppColors.primary,
  });

  final String label;
  final Future<void> Function()? onSubmit;
  final String loadingLabel;
  final bool isLoading;
  final bool isEnabled;
  final double height;
  final Color color;

  @override
  State<BangSwipeActionButton> createState() => _BangSwipeActionButtonState();
}

class _BangSwipeActionButtonState extends State<BangSwipeActionButton> {
  static const double _completeThreshold = 0.78;
  static const double _knobInset = 4;

  double _dragProgress = 0;
  bool _isDragging = false;
  bool _isCompleting = false;

  bool get _isBusy => widget.isLoading || _isCompleting;

  bool get _isInteractive =>
      widget.isEnabled && !_isBusy && widget.onSubmit != null;

  @override
  void didUpdateWidget(covariant BangSwipeActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isBusy && (!widget.isEnabled || oldWidget.isLoading)) {
      _dragProgress = 0;
      _isDragging = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.isEnabled
        ? widget.color
        : AppColors.textMuted;
    final label = _isBusy ? widget.loadingLabel : widget.label;

    return SizedBox(
      width: double.infinity,
      child: Semantics(
        button: true,
        enabled: _isInteractive,
        label: label,
        hint: 'Geser tombol sampai kanan untuk menjalankan aksi.',
        onTap: _isInteractive ? () => unawaited(_complete()) : null,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = widget.height;
            final knobSize = height - (_knobInset * 2);
            final maxDrag = math.max(
              0.0,
              constraints.maxWidth - knobSize - (_knobInset * 2),
            );
            final knobLeft = _knobInset + (maxDrag * _dragProgress);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: _isInteractive
                  ? (_) => setState(() => _isDragging = true)
                  : null,
              onHorizontalDragUpdate: _isInteractive
                  ? (details) => _handleDragUpdate(details, maxDrag)
                  : null,
              onHorizontalDragEnd: _isInteractive ? _handleDragEnd : null,
              onHorizontalDragCancel: _isInteractive ? _reset : null,
              child: SizedBox(
                height: height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: effectiveColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: effectiveColor.withValues(alpha: 0.68),
                          ),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: _isDragging
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: knobLeft + knobSize + _knobInset,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: ColoredBox(
                          color: effectiveColor.withValues(alpha: 0.11),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: knobSize + 18,
                          right: 14,
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              maxLines: 1,
                              style: TextStyle(
                                color: widget.isEnabled
                                    ? AppColors.primaryDark
                                    : AppColors.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: _isDragging
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      left: knobLeft,
                      top: _knobInset,
                      width: knobSize,
                      height: knobSize,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: effectiveColor,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.keyboard_double_arrow_right_rounded,
                                  color: AppColors.white,
                                  size: 26,
                                ),
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
    );
  }

  void _handleDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (maxDrag <= 0) {
      return;
    }

    final delta = details.primaryDelta ?? 0;
    setState(() {
      _dragProgress = (_dragProgress + (delta / maxDrag)).clamp(0.0, 1.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    setState(() => _isDragging = false);

    if (_dragProgress >= _completeThreshold) {
      unawaited(_complete());
      return;
    }

    _reset();
  }

  Future<void> _complete() async {
    if (!_isInteractive) {
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _dragProgress = 1;
      _isCompleting = true;
      _isDragging = false;
    });

    try {
      await widget.onSubmit?.call();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'bang_swipe_action_button',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _dragProgress = 0;
          _isCompleting = false;
        });
      }
    }
  }

  void _reset() {
    if (!mounted) {
      return;
    }

    setState(() {
      _dragProgress = 0;
      _isDragging = false;
    });
  }
}
