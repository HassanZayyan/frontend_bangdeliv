import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/app_colors.dart';

Future<BitmapDescriptor> buildMotorDriverMarker({double size = 42}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final pixelRatio = ui.PlatformDispatcher.instance.views.isEmpty
      ? 1.0
      : ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
  final markerSize = (size * pixelRatio).roundToDouble();
  final center = Offset(markerSize / 2, markerSize / 2);
  final radius = markerSize / 2;

  final shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.18)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  canvas.drawCircle(
    center.translate(0, markerSize * 0.06),
    radius * 0.82,
    shadowPaint,
  );

  final outerPaint = Paint()..color = AppColors.primary;
  canvas.drawCircle(center, radius * 0.78, outerPaint);

  final innerPaint = Paint()..color = AppColors.white;
  canvas.drawCircle(center, radius * 0.58, innerPaint);

  final textPainter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(Icons.two_wheeler_rounded.codePoint),
      style: TextStyle(
        fontSize: markerSize * 0.52,
        fontFamily: Icons.two_wheeler_rounded.fontFamily,
        package: Icons.two_wheeler_rounded.fontPackage,
        color: AppColors.primary,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  textPainter.paint(
    canvas,
    center - Offset(textPainter.width / 2, textPainter.height / 2),
  );

  final image = await recorder.endRecording().toImage(
    markerSize.round(),
    markerSize.round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final data = bytes?.buffer.asUint8List() ?? Uint8List(0);
  if (data.isEmpty) {
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
  }

  return BitmapDescriptor.bytes(
    data,
    imagePixelRatio: pixelRatio,
    width: size,
    height: size,
  );
}
