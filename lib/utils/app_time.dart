const Duration wibOffset = Duration(hours: 7);

DateTime wibNow() {
  return DateTime.now().toUtc().add(wibOffset);
}

DateTime toWib(DateTime value) {
  return value.toUtc().add(wibOffset);
}

DateTime? parseBackendDateTime(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;

  final normalized = raw.contains(' ') ? raw.replaceFirst(' ', 'T') : raw;
  final dateOnlyMatch = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})$',
  ).firstMatch(normalized);
  if (dateOnlyMatch != null) {
    return DateTime.utc(
      int.parse(dateOnlyMatch.group(1)!),
      int.parse(dateOnlyMatch.group(2)!),
      int.parse(dateOnlyMatch.group(3)!),
    ).subtract(wibOffset);
  }

  final hasExplicitTimeZone = RegExp(
    r'(Z|[+-]\d{2}:?\d{2})$',
  ).hasMatch(normalized);
  final hasTimeComponent = normalized.contains('T');
  final parseTarget = hasTimeComponent && !hasExplicitTimeZone
      ? '${normalized}Z'
      : normalized;

  return DateTime.tryParse(parseTarget)?.toUtc();
}

String toBackendWibIsoString(DateTime value) {
  final wib = toWib(value);
  final fraction = _fractionalSecond(value);

  return '${_fourDigits(wib.year)}-${_twoDigits(wib.month)}-${_twoDigits(wib.day)}'
      'T${_twoDigits(wib.hour)}:${_twoDigits(wib.minute)}:${_twoDigits(wib.second)}'
      '$fraction+07:00';
}

String _fractionalSecond(DateTime value) {
  if (value.millisecond == 0 && value.microsecond == 0) {
    return '';
  }

  final micros = (value.millisecond * 1000 + value.microsecond)
      .toString()
      .padLeft(6, '0');
  return '.$micros';
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}

String _fourDigits(int value) {
  return value.toString().padLeft(4, '0');
}
