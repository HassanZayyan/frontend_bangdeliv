import '../domain/order_domain.dart';

class ServiceTypeCodes {
  const ServiceTypeCodes._();

  static const ride = ServiceTypeCode.ride;
  static const courier = ServiceTypeCode.courier;
  static const shopping = ServiceTypeCode.shopping;
  static const unknown = ServiceTypeCode.unknown;
}

String normalizeServiceTypeCode(String raw) {
  return ServiceTypeCode.normalize(raw);
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
  return normalizeServiceTypeCode(code) == ServiceTypeCodes.courier;
}
