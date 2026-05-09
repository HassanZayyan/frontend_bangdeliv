class DriverVerificationStatusModel {
  final DriverVerificationDriverModel driver;
  final List<DriverVerificationDocumentModel> documents;

  const DriverVerificationStatusModel({
    required this.driver,
    required this.documents,
  });

  factory DriverVerificationStatusModel.fromJson(Map<String, dynamic> json) {
    final rawDriver = (json['driver'] as Map<String, dynamic>?) ?? const {};
    final rawDocuments = (json['documents'] as List?) ?? const [];

    return DriverVerificationStatusModel(
      driver: DriverVerificationDriverModel.fromJson(rawDriver),
      documents: rawDocuments
          .whereType<Map<String, dynamic>>()
          .map(DriverVerificationDocumentModel.fromJson)
          .toList(),
    );
  }

  DriverVerificationDocumentModel? documentByType(String type) {
    final normalizedType = type.trim().toLowerCase();

    for (final document in documents) {
      if (document.documentType.trim().toLowerCase() == normalizedType) {
        return document;
      }
    }

    return null;
  }
}

class DriverVerificationDriverModel {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String vehicleType;
  final String vehicleBrand;
  final String vehicleModel;
  final String vehiclePlate;
  final String licenseNumber;
  final String registrationStatus;
  final String status;
  final DateTime? submittedAt;
  final DateTime? updatedAt;

  const DriverVerificationDriverModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.vehicleType,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehiclePlate,
    required this.licenseNumber,
    required this.registrationStatus,
    required this.status,
    required this.submittedAt,
    required this.updatedAt,
  });

  factory DriverVerificationDriverModel.fromJson(Map<String, dynamic> json) {
    return DriverVerificationDriverModel(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      vehicleType: (json['vehicle_type'] ?? '').toString(),
      vehicleBrand: (json['vehicle_brand'] ?? '').toString(),
      vehicleModel: (json['vehicle_model'] ?? '').toString(),
      vehiclePlate: (json['vehicle_plate'] ?? '').toString(),
      licenseNumber: (json['license_number'] ?? '').toString(),
      registrationStatus: (json['registration_status'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      submittedAt: _parseDateTime(json['submitted_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }
}

class DriverVerificationDocumentModel {
  final String documentType;
  final bool isUploaded;
  final String? filePath;
  final String? fileUrl;
  final bool fileExists;
  final String verificationStatus;
  final String? rejectionReason;
  final DateTime? verifiedAt;
  final String? verifiedBy;

  const DriverVerificationDocumentModel({
    required this.documentType,
    required this.isUploaded,
    required this.filePath,
    required this.fileUrl,
    required this.fileExists,
    required this.verificationStatus,
    required this.rejectionReason,
    required this.verifiedAt,
    required this.verifiedBy,
  });

  factory DriverVerificationDocumentModel.fromJson(Map<String, dynamic> json) {
    return DriverVerificationDocumentModel(
      documentType: (json['document_type'] ?? '').toString(),
      isUploaded: json['is_uploaded'] == true,
      filePath: _nullableString(json['file_path']),
      fileUrl: _nullableString(json['file_url']),
      fileExists: json['file_exists'] == true,
      verificationStatus: (json['verification_status'] ?? '').toString(),
      rejectionReason: _nullableString(json['rejection_reason']),
      verifiedAt: _parseDateTime(json['verified_at']),
      verifiedBy: _nullableString(json['verified_by']),
    );
  }

  String get displayName {
    switch (documentType.trim().toLowerCase()) {
      case 'ktp':
        return 'KTP';
      case 'sim':
        return 'SIM';
      case 'selfie':
        return 'Selfie dengan SIM';
      default:
        return documentType;
    }
  }
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _parseDateTime(dynamic value) {
  final raw = value?.toString() ?? '';
  if (raw.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(raw);
}

String? _nullableString(dynamic value) {
  final raw = value?.toString() ?? '';
  if (raw.trim().isEmpty) {
    return null;
  }

  return raw;
}
