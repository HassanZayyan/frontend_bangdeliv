import 'app_time.dart';

export 'app_time.dart'
    show parseBackendDateTime, toBackendWibIsoString, toWib, wibNow;

String formatCurrency(num value) {
  final whole = value.round().toString();
  final withDots = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => '.',
  );

  return 'Rp $withDots';
}

String formatShoppingAttemptProgress({
  required int attemptNo,
  required int attemptLimit,
  required int totalFailed,
}) {
  final safeLimit = attemptLimit > 0 ? attemptLimit : 3;
  final safeAttempt = attemptNo.clamp(1, safeLimit);
  final progress = 'Percobaan $safeAttempt/$safeLimit';
  final safeTotalFailed = totalFailed.clamp(0, 1 << 31);

  return safeTotalFailed > 0
      ? '$progress • Total gagal $safeTotalFailed'
      : progress;
}

String formatDateTime(DateTime? value, {bool includeZone = true}) {
  if (value == null) return '-';

  final wib = toWib(value);
  final day = wib.day.toString().padLeft(2, '0');
  final month = wib.month.toString().padLeft(2, '0');
  final year = wib.year.toString();
  final time = formatTime(value, includeZone: false);

  return includeZone
      ? '$day/$month/$year $time WIB'
      : '$day/$month/$year $time';
}

String formatTime(DateTime? value, {bool includeZone = true}) {
  if (value == null) return '-';

  final wib = toWib(value);
  final hour = wib.hour.toString().padLeft(2, '0');
  final minute = wib.minute.toString().padLeft(2, '0');
  final formatted = '$hour:$minute';

  return includeZone ? '$formatted WIB' : formatted;
}

const _indoMonths = [
  '',
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String formatDateMonthTime(DateTime? value) {
  if (value == null) return '-';

  final wib = toWib(value);
  final day = wib.day;
  final month = _indoMonths[wib.month];
  final hour = wib.hour.toString().padLeft(2, '0');
  final minute = wib.minute.toString().padLeft(2, '0');

  return '$day $month, $hour:$minute';
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
