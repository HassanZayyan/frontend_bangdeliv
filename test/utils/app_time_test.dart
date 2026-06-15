import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/utils/app_time.dart';

void main() {
  test('toBackendWibIsoString sends UTC instant as explicit WIB offset', () {
    final utcTime = DateTime.utc(2026, 6, 15, 13, 31, 34);

    expect(toBackendWibIsoString(utcTime), '2026-06-15T20:31:34+07:00');
  });

  test('toBackendWibIsoString normalizes local DateTime objects to WIB', () {
    final localTime = DateTime.utc(2026, 6, 15, 13, 31, 34).toLocal();

    expect(toBackendWibIsoString(localTime), '2026-06-15T20:31:34+07:00');
  });
}
