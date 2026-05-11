import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/services/google_maps_lookup_service.dart';

void main() {
  test('cleanAddress drops generated pin labels and keeps real addresses', () {
    const service = GoogleMapsLookupService();

    expect(service.cleanAddress('Pin -7.123,110.456'), isNull);
    expect(service.cleanAddress('  Jalan Mawar 1  '), 'Jalan Mawar 1');
    expect(service.cleanAddress(''), isNull);
  });
}
