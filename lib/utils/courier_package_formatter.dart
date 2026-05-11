import '../models/driver_order_model.dart';
import 'service_type.dart';

class CourierPackageDetails {
  const CourierPackageDetails({
    required this.isCourier,
    required this.description,
    required this.sizeLine,
    required this.safetyLine,
    required this.packingNote,
  });

  final bool isCourier;
  final String description;
  final String sizeLine;
  final String safetyLine;
  final String packingNote;

  bool get hasDetails =>
      description.isNotEmpty ||
      sizeLine.isNotEmpty ||
      safetyLine.isNotEmpty ||
      packingNote.isNotEmpty;
}

CourierPackageDetails buildCourierPackageDetails(DriverOrderModel order) {
  return CourierPackageDetails(
    isCourier:
        normalizeServiceTypeCode(order.serviceTypeCode) ==
        ServiceTypeCodes.courier,
    description: (order.packageDescription ?? '').trim(),
    sizeLine: _buildPackageSizeLine(order),
    safetyLine: _buildPackageSafetyLine(order),
    packingNote: (order.packagePackingNote ?? '').trim(),
  );
}

String _buildPackageSizeLine(DriverOrderModel order) {
  final parts = <String>[];

  if (order.packageEstimatedWeightKg != null) {
    parts.add('${_formatWeight(order.packageEstimatedWeightKg!)} kg');
  }

  final length = order.packageLengthCm;
  final width = order.packageWidthCm;
  final height = order.packageHeightCm;
  if (length != null && width != null && height != null) {
    parts.add('${length}x${width}x$height cm');
  }

  final sizeClass = (order.packageSizeClass ?? '').trim();
  if (sizeClass.isNotEmpty) {
    parts.add(_localizeSizeClass(sizeClass));
  }

  return parts.join(' - ');
}

String _buildPackageSafetyLine(DriverOrderModel order) {
  final status = (order.packageSafetyStatus ?? '').trim();
  final reason = (order.packageSafetyReason ?? '').trim();

  if (status.isEmpty) return _localizeSafetyReason(reason);

  final localizedStatus = _localizeSafetyStatus(status);
  final localizedReason = _localizeSafetyReason(reason);
  if (localizedReason.isEmpty) return localizedStatus;
  return '$localizedStatus - $localizedReason';
}

String _formatWeight(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

String _localizeSizeClass(String raw) {
  switch (raw.trim().toUpperCase()) {
    case 'SMALL':
      return 'Kecil';
    case 'MEDIUM':
      return 'Sedang';
    case 'LARGE':
      return 'Besar';
    case 'XL':
    case 'EXTRA_LARGE':
      return 'Sangat Besar';
    default:
      return _titleize(raw);
  }
}

String _localizeSafetyStatus(String raw) {
  switch (raw.trim().toUpperCase()) {
    case 'ALLOWED':
    case 'SAFE':
      return 'Aman';
    case 'RESTRICTED':
    case 'LIMITED':
      return 'Terbatas';
    case 'FORBIDDEN':
    case 'PROHIBITED':
    case 'NOT_ALLOWED':
      return 'Dilarang';
    case 'CHECK_REQUIRED':
    case 'REVIEW_REQUIRED':
      return 'Perlu Pemeriksaan';
    default:
      return _titleize(raw);
  }
}

String _localizeSafetyReason(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return '';

  switch (text.toUpperCase()) {
    case 'PACKAGE IS SAFE FOR MOTORBIKE COURIER SERVICE.':
    case 'PACKAGE IS SAFE FOR COURIER SERVICE.':
      return 'Paket aman untuk layanan kurir.';
    default:
      return text;
  }
}

String _titleize(String raw) {
  return raw
      .trim()
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
