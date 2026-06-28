class UserProfileModel {
  final int id;
  final String name;
  final String phone;
  final String email;
  final String? avatar;
  final String? avatarUrl;
  final String role;
  final String authProvider;
  final bool hasPassword;
  final bool requiresPhoneCompletion;
  final DriverProfileModel? driverProfile;
  final UserStatsModel stats;
  final List<SavedAddressModel> addresses;

  const UserProfileModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.avatar,
    required this.avatarUrl,
    required this.role,
    this.authProvider = 'password',
    this.hasPassword = true,
    this.requiresPhoneCompletion = false,
    required this.driverProfile,
    required this.stats,
    required this.addresses,
  });

  int get addressCount => addresses.length;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawAddresses = (json['addresses'] as List?) ?? [];

    return UserProfileModel(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      avatar: _asNullableString(json['avatar']),
      avatarUrl: _asNullableString(json['avatar_url']),
      role: (json['role'] ?? '').toString(),
      authProvider: (json['auth_provider'] ?? 'password').toString(),
      hasPassword: json['has_password'] != false,
      requiresPhoneCompletion: json['requires_phone_completion'] == true,
      driverProfile: (json['driver_profile'] is Map<String, dynamic>)
          ? DriverProfileModel.fromJson(
              json['driver_profile'] as Map<String, dynamic>,
            )
          : null,
      stats: UserStatsModel.fromJson(
        (json['stats'] as Map<String, dynamic>?) ?? const {},
      ),
      addresses: rawAddresses
          .whereType<Map<String, dynamic>>()
          .map(SavedAddressModel.fromJson)
          .toList(),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _asNullableString(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }

    return raw;
  }
}

class DriverProfileModel {
  final String registrationStatus;
  final String status;
  final String vehicleType;
  final String vehicleBrand;
  final String vehicleModel;
  final String vehiclePlate;
  final int totalDeliveries;

  const DriverProfileModel({
    required this.registrationStatus,
    required this.status,
    required this.vehicleType,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehiclePlate,
    required this.totalDeliveries,
  });

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    return DriverProfileModel(
      registrationStatus: (json['registration_status'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      vehicleType: (json['vehicle_type'] ?? '').toString(),
      vehicleBrand: (json['vehicle_brand'] ?? '').toString(),
      vehicleModel: (json['vehicle_model'] ?? '').toString(),
      vehiclePlate: (json['vehicle_plate'] ?? '').toString(),
      totalDeliveries: _asInt(json['total_deliveries']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class UserStatsModel {
  final int totalOrders;
  final double totalPaid;

  const UserStatsModel({required this.totalOrders, required this.totalPaid});

  factory UserStatsModel.fromJson(Map<String, dynamic> json) {
    return UserStatsModel(
      totalOrders: _asInt(json['total_orders']),
      totalPaid: _asDouble(json['total_paid']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class SavedAddressModel {
  final int id;
  final String label;
  final String recipientName;
  final String phone;
  final String fullAddress;
  final String detail;
  final double latitude;
  final double longitude;
  final bool isDefault;

  const SavedAddressModel({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.fullAddress,
    required this.detail,
    this.latitude = 0,
    this.longitude = 0,
    required this.isDefault,
  });

  String get displayAddress {
    String cleanedAddress = fullAddress
        .replaceAll(RegExp(r'(,\s*)?Indonesia\s*$', caseSensitive: false), '')
        .trim();

    if (detail.trim().isEmpty) {
      return cleanedAddress;
    }
    return '$cleanedAddress, $detail';
  }

  factory SavedAddressModel.fromJson(Map<String, dynamic> json) {
    return SavedAddressModel(
      id: _asInt(json['id']),
      label: (json['label'] ?? '').toString(),
      recipientName: (json['recipient_name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      fullAddress: (json['full_address'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      isDefault: json['is_default'] == true,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
