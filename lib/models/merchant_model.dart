import '../config/app_env.dart';

class MerchantModel {
  final String id;
  final String name;
  final String distance;
  final String imageUrl;

  MerchantModel({
    required this.id,
    required this.name,
    required this.distance,
    required this.imageUrl,
  });

  factory MerchantModel.fromApiJson(Map<String, dynamic> json) {
    return MerchantModel(
      id: (json['id'] ?? '').toString(),
      name: json['name']?.toString() ?? '-',
      distance: _distanceLabel(json['distance_km']),
      imageUrl: AppEnv.resolveBackendAssetUrl(json['banner_image']?.toString()),
    );
  }

  static String _distanceLabel(dynamic distanceKm) {
    final value = _toDouble(distanceKm);
    if (value <= 0) {
      return '-';
    }

    if (value < 1.0) {
      final meters = (value * 1000).round();
      return '$meters m';
    }

    return '${value.toStringAsFixed(1)} km';
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
