class UserProfileModel {
  final int id;
  final String name;
  final String phone;
  final String email;
  final String role;
  final DriverProfileModel? driverProfile;
  final UserStatsModel stats;
  final List<SavedAddressModel> addresses;

  const UserProfileModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
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
      role: (json['role'] ?? '').toString(),
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
}

class DriverProfileModel {
  final String registrationStatus;
  final String status;

  const DriverProfileModel({
    required this.registrationStatus,
    required this.status,
  });

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    return DriverProfileModel(
      registrationStatus: (json['registration_status'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
    );
  }
}

class UserStatsModel {
  final int totalOrders;
  final double totalPaid;
  final double rating;

  const UserStatsModel({
    required this.totalOrders,
    required this.totalPaid,
    required this.rating,
  });

  factory UserStatsModel.fromJson(Map<String, dynamic> json) {
    return UserStatsModel(
      totalOrders: _asInt(json['total_orders']),
      totalPaid: _asDouble(json['total_paid']),
      rating: _asDouble(json['rating']),
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
    if (detail.trim().isEmpty) {
      return fullAddress;
    }
    return '$fullAddress, $detail';
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
