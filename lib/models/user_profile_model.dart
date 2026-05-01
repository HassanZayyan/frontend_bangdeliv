class UserProfileModel {
  final int id;
  final String name;
  final String phone;
  final String email;
  final String? avatar;
  final String? avatarUrl;
  final String role;
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
  final String vehiclePlate;
  final String licenseNumber;
  final double avgRating;
  final int totalDeliveries;

  const DriverProfileModel({
    required this.registrationStatus,
    required this.status,
    required this.vehiclePlate,
    required this.licenseNumber,
    required this.avgRating,
    required this.totalDeliveries,
  });

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    return DriverProfileModel(
      registrationStatus: (json['registration_status'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      vehiclePlate: (json['vehicle_plate'] ?? '').toString(),
      licenseNumber: (json['license_number'] ?? '').toString(),
      avgRating: _asDouble(json['avg_rating']),
      totalDeliveries: _asInt(json['total_deliveries']),
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
    String cleanedAddress = fullAddress.replaceAll(RegExp(r'(,\s*)?Indonesia\s*$', caseSensitive: false), '').trim();
    
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
