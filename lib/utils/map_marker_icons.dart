import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/app_colors.dart';

final Map<String, Future<BitmapDescriptor>> _markerCache =
    <String, Future<BitmapDescriptor>>{};

const String _driverMapIconAsset = 'assets/images/icon_driver_map.png';

Future<BitmapDescriptor> buildMotorDriverMarker({double size = 42}) {
  final pixelRatio = _devicePixelRatio();
  final key = 'motor-asset:$_driverMapIconAsset:$size:$pixelRatio';

  return _markerCache.putIfAbsent(
    key,
    () => _buildMotorDriverMarker(size: size, pixelRatio: pixelRatio),
  );
}

Future<BitmapDescriptor> _buildMotorDriverMarker({
  required double size,
  required double pixelRatio,
}) async {
  try {
    return BitmapDescriptor.asset(
      ImageConfiguration(devicePixelRatio: pixelRatio, size: Size(size, size)),
      _driverMapIconAsset,
      width: size,
      height: size,
    );
  } catch (_) {
    return _buildFallbackMotorDriverMarker(size: size, pixelRatio: pixelRatio);
  }
}

Future<BitmapDescriptor> _buildFallbackMotorDriverMarker({
  required double size,
  required double pixelRatio,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
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

Future<BitmapDescriptor> buildOfficialMerchantMarker(
  String? merchantType, {
  double size = 42,
}) {
  final normalizedType = (merchantType ?? '').trim().toLowerCase();
  final pixelRatio = _devicePixelRatio();
  final key = 'merchant:$normalizedType:$size:$pixelRatio';
  final icon = normalizedType == 'warung'
      ? Icons.storefront_outlined
      : Icons.restaurant_outlined;

  return _markerCache.putIfAbsent(
    key,
    () => _buildCircularIconMarker(icon, size: size, pixelRatio: pixelRatio),
  );
}

Future<BitmapDescriptor> _buildCircularIconMarker(
  IconData icon, {
  required double size,
  required double pixelRatio,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
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
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: markerSize * 0.50,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
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

double _devicePixelRatio() {
  return ui.PlatformDispatcher.instance.views.isEmpty
      ? 1.0
      : ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
}
