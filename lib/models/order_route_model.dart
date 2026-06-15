class OrderRouteModel {
  const OrderRouteModel({
    this.orderedPickupLocationIds = const <int>[],
    this.encodedPolyline,
    this.distanceMeters,
    this.distanceKm,
    this.distanceText,
  });

  final List<int> orderedPickupLocationIds;
  final String? encodedPolyline;
  final int? distanceMeters;
  final double? distanceKm;
  final String? distanceText;

  factory OrderRouteModel.fromJson(Map<String, dynamic> json) {
    final meters = _asIntOrNull(
      json['distance_meters'] ?? json['distanceMeters'],
    );
    final kilometers =
        _asDoubleOrNull(json['distance_km'] ?? json['distanceKm']) ??
        (meters == null ? null : meters / 1000);

    return OrderRouteModel(
      orderedPickupLocationIds: (json['ordered_pickup_location_ids'] is List)
          ? (json['ordered_pickup_location_ids'] as List)
                .map((value) => int.tryParse(value?.toString() ?? '') ?? 0)
                .where((value) => value > 0)
                .toList(growable: false)
          : const <int>[],
      encodedPolyline: (json['encoded_polyline'] ?? json['encodedPolyline'])
          ?.toString(),
      distanceMeters: meters,
      distanceKm: kilometers,
      distanceText: _normalizeText(
        json['distance_text'] ?? json['distanceText'],
      ),
    );
  }

  static OrderRouteModel? fromRaw(
    dynamic raw, [
    Map<String, dynamic> shoppingOrder = const <String, dynamic>{},
  ]) {
    final direct = raw is Map<String, dynamic> ? raw : null;
    final snapshot = shoppingOrder['pricing_snapshot'] is Map<String, dynamic>
        ? shoppingOrder['pricing_snapshot'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final nested = snapshot['shopping_route'] is Map<String, dynamic>
        ? snapshot['shopping_route'] as Map<String, dynamic>
        : null;
    final source = direct ?? nested;

    return source == null ? null : OrderRouteModel.fromJson(source);
  }

  static int? _asIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _asDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String? _normalizeText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
