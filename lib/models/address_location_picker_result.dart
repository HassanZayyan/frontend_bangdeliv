class AddressLocationPickerResult {
  const AddressLocationPickerResult({
    required this.latitude,
    required this.longitude,
    this.source = 'map_pin',
    this.address,
  });

  final double latitude;
  final double longitude;
  final String source;
  final String? address;
}
