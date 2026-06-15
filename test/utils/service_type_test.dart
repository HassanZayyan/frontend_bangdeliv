import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/utils/service_type.dart';

void main() {
  test('order proof is courier/shopping and careful carry is courier only', () {
    expect(serviceTypeSupportsOrderProofs('COURIER'), isTrue);
    expect(serviceTypeSupportsOrderProofs('kurir'), isTrue);
    expect(serviceTypeSupportsOrderProofs('SHOPPING'), isTrue);
    expect(serviceTypeSupportsOrderProofs('nitip'), isTrue);

    expect(serviceTypeSupportsOrderProofs('RIDE'), isFalse);
    expect(serviceTypeSupportsOrderProofs('antar_jemput'), isFalse);
    expect(serviceTypeSupportsCarefulCarry('COURIER'), isTrue);
    expect(serviceTypeSupportsCarefulCarry('SHOPPING'), isFalse);
    expect(serviceTypeSupportsCarefulCarry('nitip'), isFalse);
    expect(serviceTypeSupportsCarefulCarry('RIDE'), isFalse);
  });
}
