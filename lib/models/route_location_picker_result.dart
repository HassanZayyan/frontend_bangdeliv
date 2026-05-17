class RouteLocationPickerArgs {
  const RouteLocationPickerArgs({
    required this.serviceType,
    required this.pickupTarget,
    required this.destinationTarget,
    required this.pickupLabel,
    required this.destinationLabel,
    required this.title,
    required this.confirmLabel,
    this.defaultPickupAddress,
    this.defaultPickupLatitude,
    this.defaultPickupLongitude,
    this.pickupInitialLatitude,
    this.pickupInitialLongitude,
    this.pickupInitialAddress,
    this.destinationInitialLatitude,
    this.destinationInitialLongitude,
    this.destinationInitialAddress,
  });

  final String serviceType;
  final String pickupTarget;
  final String destinationTarget;
  final String pickupLabel;
  final String destinationLabel;
  final String title;
  final String confirmLabel;
  final String? defaultPickupAddress;
  final double? defaultPickupLatitude;
  final double? defaultPickupLongitude;
  final double? pickupInitialLatitude;
  final double? pickupInitialLongitude;
  final String? pickupInitialAddress;
  final double? destinationInitialLatitude;
  final double? destinationInitialLongitude;
  final String? destinationInitialAddress;
}

class RouteLocationPickerPoint {
  const RouteLocationPickerPoint({
    required this.target,
    required this.latitude,
    required this.longitude,
    required this.source,
    this.address,
  });

  final String target;
  final double latitude;
  final double longitude;
  final String source;
  final String? address;
}

class RouteLocationPickerResult {
  const RouteLocationPickerResult({required this.locations});

  final List<RouteLocationPickerPoint> locations;
}
