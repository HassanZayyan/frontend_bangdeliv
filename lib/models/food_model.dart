import '../config/app_env.dart';
import '../utils/currency_formatter.dart';

class FoodModel {
  final String id;
  final String name;
  final String restaurantName;
  final double? price;
  final String imageUrl;

  FoodModel({
    required this.id,
    required this.name,
    required this.restaurantName,
    required this.price,
    required this.imageUrl,
  });

  factory FoodModel.fromApiJson(
    Map<String, dynamic> json, {
    required String restaurantName,
  }) {
    return FoodModel(
      id: (json['id'] ?? '').toString(),
      name: json['name']?.toString() ?? '-',
      restaurantName: restaurantName,
      price: _toNullableDouble(json['price']),
      imageUrl: AppEnv.resolveBackendAssetUrl(json['image']?.toString()),
    );
  }

  String get formattedPrice {
    return formatMenuPriceOrPending(price);
  }

  bool get hasReferencePrice {
    return hasMenuReferencePrice(price);
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
}
