class TrackingFocusTarget {
  const TrackingFocusTarget._(this.value, {this.pickupLocationId});

  static const String payment = 'payment';
  static const String deliveryFee = 'delivery_fee';
  static const String shoppingPrice = 'shopping_price';

  final String value;
  final int? pickupLocationId;

  String get signature =>
      pickupLocationId == null ? value : '$value:$pickupLocationId';

  bool get isPayment => value == payment;
  bool get isDeliveryFee => value == deliveryFee;
  bool get isShoppingPrice => value == shoppingPrice;

  static TrackingFocusTarget? fromUri(Uri uri) {
    final focus = (uri.queryParameters['focus'] ?? '').trim().toLowerCase();

    return switch (focus) {
      payment => const TrackingFocusTarget._(payment),
      deliveryFee => const TrackingFocusTarget._(deliveryFee),
      shoppingPrice => TrackingFocusTarget._(
        shoppingPrice,
        pickupLocationId: int.tryParse(
          uri.queryParameters['pickup_location_id'] ?? '',
        ),
      ),
      _ => null,
    };
  }

  static String query({required String focus, int? pickupLocationId}) {
    final params = <String, String>{'focus': focus};
    if (focus == shoppingPrice && pickupLocationId != null) {
      params['pickup_location_id'] = pickupLocationId.toString();
    }

    return Uri(queryParameters: params).query;
  }
}
