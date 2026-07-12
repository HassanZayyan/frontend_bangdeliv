import 'package:flutter/material.dart';

import '../../../../core/widgets/bang_sheet_drag_region.dart';

/// Extends [DraggableScrollableSheet]'s drag surface to a fixed sheet header.
///
/// Only vertical drags are claimed here, so horizontal selectors and tappable
/// controls inside [child] keep their own gestures.
class DriverOrderSheetDragRegion extends StatelessWidget {
  const DriverOrderSheetDragRegion({
    super.key,
    required this.controller,
    required this.minExtent,
    required this.mediumExtent,
    required this.maxExtent,
    required this.child,
    this.snapDuration = const Duration(milliseconds: 220),
  });

  final DraggableScrollableController controller;
  final double minExtent;
  final double mediumExtent;
  final double maxExtent;
  final Duration snapDuration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BangSheetDragRegion(
      controller: controller,
      minExtent: minExtent,
      maxExtent: maxExtent,
      snapExtents: [minExtent, mediumExtent, maxExtent],
      snapDuration: snapDuration,
      child: child,
    );
  }
}
