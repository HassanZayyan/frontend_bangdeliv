import '../utils/currency_formatter.dart';

class OrderModel {
  final String id;
  final String restaurantName;
  final String items;
  final double price;
  final String date;
  final String status; // 'Selesai', 'Diantar', 'Dibatalkan'
  final int rating; // 0 jika belum dirating

  OrderModel({
    required this.id,
    required this.restaurantName,
    required this.items,
    required this.price,
    required this.date,
    required this.status,
    this.rating = 0,
  });

  String get formattedPrice {
    return formatRupiah(price);
  }
}
