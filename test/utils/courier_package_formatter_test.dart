import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/utils/courier_package_formatter.dart';
import 'package:frontend_bangdeliv/utils/service_type.dart';

void main() {
  test('buildCourierPackageDetails localizes courier package metadata', () {
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
      packageEstimatedWeightKg: 1.5,
      packageLengthCm: 10,
      packageWidthCm: 20,
      packageHeightCm: 5,
      packageSizeClass: 'SMALL',
      packageSafetyStatus: 'SAFE',
      packageSafetyReason: 'PACKAGE IS SAFE FOR COURIER SERVICE.',
      packagePackingNote: 'Plastik',
    );

    final details = buildCourierPackageDetails(order);

    expect(details.isCourier, isTrue);
    expect(details.hasDetails, isTrue);
    expect(details.description, 'Dokumen');
    expect(details.sizeLine, '1.5 kg - 10x20x5 cm - Kecil');
    expect(details.safetyLine, 'Aman - Paket aman untuk layanan kurir.');
    expect(details.packingNote, 'Plastik');
  });
}
