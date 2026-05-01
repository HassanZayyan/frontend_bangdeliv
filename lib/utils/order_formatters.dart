String formatCurrency(num value) {
  final whole = value.round().toString();
  final withDots = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => '.',
  );

  return 'Rp $withDots';
}

const Duration _wibOffset = Duration(hours: 7);

DateTime wibNow() {
  return DateTime.now().toUtc().add(_wibOffset);
}

DateTime toWib(DateTime value) {
  return value.toUtc().add(_wibOffset);
}

DateTime? parseBackendDateTime(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;

  final normalized = raw.contains(' ') ? raw.replaceFirst(' ', 'T') : raw;
  final dateOnlyMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$')
      .firstMatch(normalized);
  if (dateOnlyMatch != null) {
    return DateTime.utc(
      int.parse(dateOnlyMatch.group(1)!),
      int.parse(dateOnlyMatch.group(2)!),
      int.parse(dateOnlyMatch.group(3)!),
    ).subtract(_wibOffset);
  }

  final hasExplicitTimeZone =
      RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(normalized);
  final hasTimeComponent = normalized.contains('T');
  final parseTarget =
      hasTimeComponent && !hasExplicitTimeZone ? '${normalized}Z' : normalized;

  return DateTime.tryParse(parseTarget)?.toUtc();
}

String formatDateTime(DateTime? value, {bool includeZone = true}) {
  if (value == null) return '-';

  final wib = toWib(value);
  final day = wib.day.toString().padLeft(2, '0');
  final month = wib.month.toString().padLeft(2, '0');
  final year = wib.year.toString();
  final time = formatTime(value, includeZone: false);

  return includeZone ? '$day/$month/$year $time WIB' : '$day/$month/$year $time';
}

String formatTime(DateTime? value, {bool includeZone = true}) {
  if (value == null) return '-';

  final wib = toWib(value);
  final hour = wib.hour.toString().padLeft(2, '0');
  final minute = wib.minute.toString().padLeft(2, '0');
  final formatted = '$hour:$minute';

  return includeZone ? '$formatted WIB' : formatted;
}

String currentWibHourMinute({bool includeZone = false}) {
  final now = wibNow();
  final hour = now.hour.toString().padLeft(2, '0');
  final minute = now.minute.toString().padLeft(2, '0');
  final formatted = '$hour:$minute';

  return includeZone ? '$formatted WIB' : formatted;
}

String formatBackendTimeText(String? value, {bool includeZone = true}) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return '-';
  if (raw.toUpperCase().endsWith('WIB')) return raw;

  final parsed = parseBackendDateTime(raw);
  if (parsed != null) {
    return formatTime(parsed, includeZone: includeZone);
  }

  return includeZone ? '$raw WIB' : raw;
}
