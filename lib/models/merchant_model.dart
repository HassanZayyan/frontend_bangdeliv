import '../config/app_env.dart';

class MerchantModel {
  final String id;
  final String name;
  final String distance;
  final double rating;
  final String imageUrl;

  MerchantModel({
    required this.id,
    required this.name,
    required this.distance,
    required this.rating,
    required this.imageUrl,
  });

  factory MerchantModel.fromApiJson(Map<String, dynamic> json) {
    return MerchantModel(
      id: (json['id'] ?? '').toString(),
      name: json['name']?.toString() ?? '-',
      distance: _distanceLabel(json['distance_km']),
      rating: _toDouble(json['avg_rating']),
      imageUrl: AppEnv.resolveBackendAssetUrl(json['banner_image']?.toString()),
    );
  }

  static String _distanceLabel(dynamic distanceKm) {
    final value = _toDouble(distanceKm);
    if (value <= 0) {
      return '-';
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
