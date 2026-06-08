import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/utils/courier_package_formatter.dart';
import 'package:frontend_bangdeliv/utils/service_type.dart';

void main() {
  test(
    'buildCourierPackageDetails returns minimal courier package details',
    () {
      const order = DriverOrderModel(
        id: '1',
        customerName: 'Customer',
        serviceTypeCode: ServiceTypeCodes.courier,
        pickupAddress: 'Pickup',
        dropoffAddress: 'Dropoff',
        etaMinutes: 5,
        fee: 10000,
        itemCount: 1,
        packageDescription: 'Dokumen',
      );

      final details = buildCourierPackageDetails(order);

      expect(details.isCourier, isTrue);
      expect(details.hasDetails, isTrue);
      expect(details.description, 'Dokumen');
    },
  );
}
