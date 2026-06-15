import '../../models/user_profile_model.dart';
import '../../services/auth_service.dart';

abstract class AddressRepository {
  Future<List<SavedAddressModel>> fetchSavedAddresses();

  Future<AddressValidationResult> validateSavedAddress({
    required String fullAddress,
  });

  Future<SavedAddressModel> createSavedAddress({
    required String label,
    required String recipientName,
    required String phone,
    required String fullAddress,
    String detail = '',
    double? latitude,
    double? longitude,
    bool isDefault = false,
  });

  Future<SavedAddressModel> updateSavedAddress({
    required int addressId,
    required String label,
    required String recipientName,
    required String phone,
    required String fullAddress,
    String detail = '',
    double? latitude,
    double? longitude,
    bool isDefault = false,
  });

  Future<void> deleteSavedAddress({required int addressId});
}

class AuthAddressRepository implements AddressRepository {
  const AuthAddressRepository();

  @override
  Future<List<SavedAddressModel>> fetchSavedAddresses() {
    return AuthService.fetchSavedAddresses();
  }

  @override
  Future<AddressValidationResult> validateSavedAddress({
    required String fullAddress,
  }) {
    return AuthService.validateSavedAddress(fullAddress: fullAddress);
  }

  @override
  Future<SavedAddressModel> createSavedAddress({
    required String label,
    required String recipientName,
    required String phone,
    required String fullAddress,
    String detail = '',
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) {
    return AuthService.createSavedAddress(
      label: label,
      recipientName: recipientName,
      phone: phone,
      fullAddress: fullAddress,
      detail: detail,
      latitude: latitude,
      longitude: longitude,
      isDefault: isDefault,
    );
  }

  @override
  Future<SavedAddressModel> updateSavedAddress({
    required int addressId,
    required String label,
    required String recipientName,
    required String phone,
    required String fullAddress,
    String detail = '',
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) {
    return AuthService.updateSavedAddress(
      addressId: addressId,
      label: label,
      recipientName: recipientName,
      phone: phone,
      fullAddress: fullAddress,
      detail: detail,
      latitude: latitude,
      longitude: longitude,
      isDefault: isDefault,
    );
  }

  @override
  Future<void> deleteSavedAddress({required int addressId}) {
    return AuthService.deleteSavedAddress(addressId: addressId);
  }
}
