class ServiceTypeCodes {
  const ServiceTypeCodes._();

  static const ride = 'RIDE';
  static const courier = 'COURIER';
  static const shopping = 'SHOPPING';
  static const unknown = 'UNKNOWN';
}

String normalizeServiceTypeCode(String raw) {
  final normalized = raw
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  switch (normalized) {
    case ServiceTypeCodes.ride:
    case 'ANTAR_JEMPUT':
    case 'ANTAR_JEMPUT_ORANG':
      return ServiceTypeCodes.ride;
    case ServiceTypeCodes.courier:
    case 'KURIR':
    case 'ANTAR_BARANG':
      return ServiceTypeCodes.courier;
    case ServiceTypeCodes.shopping:
    case 'NITIP':
    case 'TITIP_BELANJA':
      return ServiceTypeCodes.shopping;
    default:
      return normalized.isEmpty ? ServiceTypeCodes.unknown : normalized;
  }
}

String serviceTypeLabel(String code) {
  switch (normalizeServiceTypeCode(code)) {
    case ServiceTypeCodes.ride:
      return 'Antar Jemput';
    case ServiceTypeCodes.courier:
      return 'Kurir';
    case ServiceTypeCodes.shopping:
      return 'Nitip';
    default:
      return 'Kurir';
  }
}

bool serviceTypeSupportsOrderProofs(String code) {
  final normalized = normalizeServiceTypeCode(code);
  return normalized == ServiceTypeCodes.courier ||
      normalized == ServiceTypeCodes.shopping;
}

bool serviceTypeSupportsCarefulCarry(String code) {
  return serviceTypeSupportsOrderProofs(code);
}
