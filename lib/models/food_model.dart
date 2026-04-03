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

  String get formattedPrice {
    // Format simpel ke Rupiah. Nanti bisa disempurnakan dengan package intl
    return "Rp ${price.toInt()}"; 
  }
}
