class AddressFormPresenter {
  const AddressFormPresenter._();

  static String normalizeAddressLabel(String rawLabel) {
    final normalized = rawLabel.trim().toLowerCase();
    if (normalized.contains('kantor') || normalized.contains('office')) {
      return 'Kantor';
    }
    if (normalized.isEmpty ||
        normalized.contains('rumah') ||
        normalized.contains('home')) {
      return 'Rumah';
    }
    return 'Lainnya';
  }

  static bool isCoordinatePairValid(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return false;
    }

    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return false;
    }

    if (latitude == 0 && longitude == 0) {
      return false;
    }

    return true;
  }
}
