import '../models/user_profile_model.dart';

bool hasUsableSavedAddress(Iterable<SavedAddressModel> addresses) {
  return addresses.any(isUsableSavedAddress);
}

bool isUsableSavedAddress(SavedAddressModel address) {
  final fullAddress = address.fullAddress.trim();
  final latitude = address.latitude;
  final longitude = address.longitude;

  return fullAddress.isNotEmpty &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      !(latitude == 0 && longitude == 0);
}

SavedAddressModel? defaultUsableSavedAddress(
  Iterable<SavedAddressModel> addresses,
) {
  final usable = addresses.where(isUsableSavedAddress).toList(growable: false);
  if (usable.isEmpty) {
    return null;
  }

  for (final address in usable) {
    if (address.isDefault) {
      return address;
    }
  }

  return usable.first;
}
