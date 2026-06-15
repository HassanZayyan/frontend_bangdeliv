import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/domain/order_domain.dart';
import 'package:frontend_bangdeliv/utils/order_status.dart';
import 'package:frontend_bangdeliv/utils/service_type.dart';

void main() {
  test('service type domain keeps legacy aliases stable', () {
    expect(ServiceTypeCode.normalize('antar jemput'), ServiceTypeCode.ride);
    expect(ServiceTypeCode.normalize('kurir'), ServiceTypeCode.courier);
    expect(
      ServiceTypeCode.normalize('titip belanja'),
      ServiceTypeCode.shopping,
    );
    expect(normalizeServiceTypeCode('nitip'), ServiceTypeCode.shopping);
  });

  test('order status domain remains compatible with existing helpers', () {
    expect(
      OrderStatusCode.normalize(' completed '),
      OrderStatusCodes.completed,
    );
    expect(isTerminalOrderStatus(OrderStatusCode.completed), isTrue);
    expect(isDriverRunningOrderStatus(OrderStatusCode.driverAssigned), isTrue);
  });

  test('payment and proof constants cover main service flow contracts', () {
    expect(PaymentMethodCode.normalize('transfer'), PaymentMethodCode.transfer);
    expect(PaymentMethodCode.normalize(null), PaymentMethodCode.cod);
    expect(ProofTypeCode.pickup, 'pickup');
    expect(ProofTypeCode.receipt, 'receipt');
    expect(DriverActionCode.completeOrder, 'COMPLETE_ORDER');
  });
}
