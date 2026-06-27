import 'package:flutter/material.dart';

enum BangChatBubbleSide { left, right }

const double _tailWidth = 10;
const double _tailHeight = 14;

class BangChatBubble extends StatelessWidget {
  const BangChatBubble({
    super.key,
    required this.side,
    required this.color,
    required this.child,
    this.borderColor,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.showTail = true,
  });

  final BangChatBubbleSide side;
  final Color color;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius borderRadius;
  final bool? showTail;
  final Widget child;

  bool get _isRight => side == BangChatBubbleSide.right;
  bool get _effectiveShowTail => showTail ?? true;

  @override
  Widget build(BuildContext context) {
    final tailPadding = EdgeInsets.only(
      left: _isRight ? 0 : _tailWidth,
      right: _isRight ? _tailWidth : 0,
    );

    return Padding(
      padding: margin,
      child: CustomPaint(
        painter: _BangChatBubblePainter(
          side: side,
          color: color,
          borderColor: borderColor,
          borderRadius: borderRadius,
          showTail: _effectiveShowTail,
        ),
        child: Padding(
          padding: tailPadding,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _tailHeight),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class _BangChatBubblePainter extends CustomPainter {
  const _BangChatBubblePainter({
    required this.side,
    required this.color,
    required this.borderRadius,
    required this.showTail,
    this.borderColor,
  });

  final BangChatBubbleSide side;
  final Color color;
  final BorderRadius borderRadius;
  final Color? borderColor;
  final bool showTail;

  bool get _isRight => side == BangChatBubbleSide.right;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyRect = Rect.fromLTRB(
      _isRight ? 0 : _tailWidth,
      0,
      _isRight ? size.width - _tailWidth : size.width,
      size.height,
    );
    final bodyPath = Path()..addRRect(borderRadius.toRRect(bodyRect));
    final tailPath = Path();

    if (showTail) {
      if (_isRight) {
        tailPath
          ..moveTo(bodyRect.right - 2, 0)
          ..lineTo(size.width, 0)
          ..quadraticBezierTo(size.width - 2, 3, size.width - 5, 6)
          ..quadraticBezierTo(
            size.width - 8,
            9,
            bodyRect.right - 2,
            _tailHeight,
          )
          ..close();
      } else {
        tailPath
          ..moveTo(bodyRect.left + 2, 0)
          ..lineTo(0, 0)
          ..quadraticBezierTo(2, 3, 5, 6)
          ..quadraticBezierTo(8, 9, bodyRect.left + 2, _tailHeight)
          ..close();
      }
    }

    final path = showTail
        ? Path.combine(PathOperation.union, bodyPath, tailPath)
        : bodyPath;

    canvas.drawPath(path, Paint()..color = color);

    final borderColor = this.borderColor;
    if (borderColor != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BangChatBubblePainter oldDelegate) {
    return oldDelegate.side != side ||
        oldDelegate.color != color ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.showTail != showTail;
  }
}
