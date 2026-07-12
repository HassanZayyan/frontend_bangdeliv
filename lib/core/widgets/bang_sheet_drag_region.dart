import 'dart:async';

import 'package:flutter/material.dart';

/// Extends a [DraggableScrollableSheet] drag surface to a fixed header.
///
/// Only vertical drags are claimed, so horizontal selectors and tappable
/// controls inside [child] keep their own gestures.
class BangSheetDragRegion extends StatelessWidget {
  const BangSheetDragRegion({
    super.key,
    required this.controller,
    required this.minExtent,
    required this.maxExtent,
    required this.snapExtents,
    required this.child,
    this.snapDuration = const Duration(milliseconds: 220),
  });

  final DraggableScrollableController controller;
  final double minExtent;
  final double maxExtent;
  final List<double> snapExtents;
  final Duration snapDuration;
  final Widget child;

  static const double _strongVelocityThreshold = 600;
  static const double _snapEpsilon = 0.001;

  List<double> get _resolvedSnapExtents {
    final extents = <double>{
      minExtent,
      maxExtent,
      ...snapExtents.map(
        (extent) => extent.clamp(minExtent, maxExtent).toDouble(),
      ),
    }.toList()..sort();
    return extents;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (!controller.isAttached) return;

    final delta = details.primaryDelta;
    if (delta == null || delta == 0) return;

    final currentPixels = controller.sizeToPixels(controller.size);
    final nextSize = controller
        .pixelsToSize(currentPixels - delta)
        .clamp(minExtent, maxExtent)
        .toDouble();
    controller.jumpTo(nextSize);
  }

  void _handleVerticalDragEnd(BuildContext context, DragEndDetails details) {
    if (!controller.isAttached) return;

    final targetSize = _targetSnapExtent(
      currentSize: controller.size,
      velocity: details.primaryVelocity ?? 0,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpTo(targetSize);
      return;
    }

    unawaited(_animateTo(targetSize));
  }

  double _targetSnapExtent({
    required double currentSize,
    required double velocity,
  }) {
    final extents = _resolvedSnapExtents;
    if (velocity <= -_strongVelocityThreshold) {
      return extents.firstWhere(
        (extent) => extent > currentSize + _snapEpsilon,
        orElse: () => maxExtent,
      );
    }
    if (velocity >= _strongVelocityThreshold) {
      return extents.lastWhere(
        (extent) => extent < currentSize - _snapEpsilon,
        orElse: () => minExtent,
      );
    }

    return extents.reduce(
      (nearest, extent) =>
          (extent - currentSize).abs() < (nearest - currentSize).abs()
          ? extent
          : nearest,
    );
  }

  Future<void> _animateTo(double targetSize) async {
    if (!controller.isAttached) return;
    try {
      await controller.animateTo(
        targetSize,
        duration: snapDuration,
        curve: Curves.easeOutCubic,
      );
    } on FlutterError {
      // The route can close while the snap animation is still in progress.
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _handleVerticalDragUpdate,
      onVerticalDragEnd: (details) => _handleVerticalDragEnd(context, details),
      child: child,
    );
  }
}
