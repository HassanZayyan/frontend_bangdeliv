class AddressLocationPickerResult {
  const AddressLocationPickerResult({
    required this.latitude,
    required this.longitude,
    this.source = 'map_pin',
  });

  final double latitude;
  final double longitude;
  final String source;
}
