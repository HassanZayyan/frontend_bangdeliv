class FoodModel {
  final String id;
  final String name;
  final String restaurantName;
  final double price;
  final double rating;
  final String imageUrl;

  FoodModel({
    required this.id,
    required this.name,
    required this.restaurantName,
    required this.price,
    required this.rating,
    required this.imageUrl,
  });

  factory FoodModel.fromApiJson(
    Map<String, dynamic> json, {
    required String restaurantName,
    required double restaurantRating,
  }) {
    return FoodModel(
      id: (json['id'] ?? '').toString(),
      name: json['name']?.toString() ?? '-',
      restaurantName: restaurantName,
      price: _toDouble(json['price']),
      rating: restaurantRating,
      imageUrl: json['image']?.toString() ?? '',
    );
  }

  String get formattedPrice {
    return 'Rp ${price.toInt()}';
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
