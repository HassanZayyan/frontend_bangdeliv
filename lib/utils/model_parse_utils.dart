import 'app_time.dart';

class ModelParseUtils {
  const ModelParseUtils._();

  static String normalizedStatus(dynamic value, {String fallback = 'NONE'}) {
    final status = value?.toString().trim().toUpperCase() ?? '';
    return status.isEmpty ? fallback : status;
  }

  static String? normalizedText(dynamic value) {
    final text = optionalText(value);
    return text?.toUpperCase();
  }

  static bool boolValue(dynamic value, {bool fallback = false}) {
    return boolOrNull(value) ?? fallback;
  }

  static bool? boolOrNull(dynamic value) {
    if (value == null || value == '') return null;
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    return null;
  }

  static int? intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final raw = value.toString().trim();
    return raw.isEmpty ? null : int.tryParse(raw);
  }

  static double? doubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final raw = value.toString().trim();
    return raw.isEmpty ? null : double.tryParse(raw);
  }

  static String? optionalText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == '-' ? null : text;
  }

  static DateTime? backendDateTime(dynamic value) {
    return parseBackendDateTime(value);
  }
}
