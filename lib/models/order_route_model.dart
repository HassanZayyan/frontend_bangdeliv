class OrderRouteModel {
  const OrderRouteModel({
    this.orderedPickupLocationIds = const <int>[],
    this.encodedPolyline,
  });

  final List<int> orderedPickupLocationIds;
  final String? encodedPolyline;

  factory OrderRouteModel.fromJson(Map<String, dynamic> json) {
    return OrderRouteModel(
      orderedPickupLocationIds: (json['ordered_pickup_location_ids'] is List)
          ? (json['ordered_pickup_location_ids'] as List)
                .map((value) => int.tryParse(value?.toString() ?? '') ?? 0)
                .where((value) => value > 0)
                .toList(growable: false)
          : const <int>[],
      encodedPolyline: (json['encoded_polyline'] ?? json['encodedPolyline'])
          ?.toString(),
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
}
