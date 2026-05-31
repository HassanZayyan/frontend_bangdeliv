import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/utils/service_type.dart';

void main() {
  test(
    'order proof and careful carry are only enabled for courier/shopping',
    () {
      expect(serviceTypeSupportsOrderProofs('COURIER'), isTrue);
      expect(serviceTypeSupportsOrderProofs('kurir'), isTrue);
      expect(serviceTypeSupportsOrderProofs('SHOPPING'), isTrue);
      expect(serviceTypeSupportsOrderProofs('nitip'), isTrue);

      expect(serviceTypeSupportsOrderProofs('RIDE'), isFalse);
      expect(serviceTypeSupportsOrderProofs('antar_jemput'), isFalse);
      expect(serviceTypeSupportsCarefulCarry('RIDE'), isFalse);
    },
  );
}
