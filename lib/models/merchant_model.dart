import '../config/app_env.dart';

class MerchantModel {
  final String id;
  final String name;
  final String distance;
  final String imageUrl;
  final List<String> galleryImageUrls;
  final String merchantType;
  final String address;
  final String phone;
  final double? latitude;
  final double? longitude;

  MerchantModel({
    required this.id,
    required this.name,
    required this.distance,
    required this.imageUrl,
    this.galleryImageUrls = const <String>[],
    this.merchantType = '',
    this.address = '',
    this.phone = '',
    this.latitude,
    this.longitude,
  });

  factory MerchantModel.fromApiJson(Map<String, dynamic> json) {
    final imageUrl = AppEnv.resolveBackendAssetUrl(
      json['banner_image']?.toString(),
    );

    return MerchantModel(
      id: (json['id'] ?? '').toString(),
      name: json['name']?.toString() ?? '-',
      distance: _distanceLabel(json['distance_km']),
      imageUrl: imageUrl,
      galleryImageUrls: _galleryImageUrls(json['gallery_images'], imageUrl),
      merchantType: json['merchant_type']?.toString() ?? '',
      address:
          (json['address'] ?? json['full_address'] ?? json['fullAddress'])
              ?.toString() ??
          '',
      phone: json['phone']?.toString() ?? '',
      latitude: _toNullableDouble(json['latitude']),
      longitude: _toNullableDouble(json['longitude']),
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

  static double? _toNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static List<String> _galleryImageUrls(
    dynamic value,
    String fallbackImageUrl,
  ) {
    final urls = <String>[];

    if (value is List<dynamic>) {
      for (final item in value) {
        final url = AppEnv.resolveBackendAssetUrl(item?.toString());
        if (url.isNotEmpty && !urls.contains(url)) {
          urls.add(url);
        }
      }
    }

    if (urls.isEmpty && fallbackImageUrl.isNotEmpty) {
      urls.add(fallbackImageUrl);
    }

    return urls;
  }
}
