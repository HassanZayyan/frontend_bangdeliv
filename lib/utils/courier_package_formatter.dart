import '../models/driver_order_model.dart';
import 'service_type.dart';

class CourierPackageDetails {
  const CourierPackageDetails({
    required this.isCourier,
    required this.description,
  });

  final bool isCourier;
  final String description;

  bool get hasDetails => description.isNotEmpty;
}

CourierPackageDetails buildCourierPackageDetails(DriverOrderModel order) {
  return CourierPackageDetails(
    isCourier:
        normalizeServiceTypeCode(order.serviceTypeCode) ==
        ServiceTypeCodes.courier,
    description: (order.packageDescription ?? '').trim(),
  );
}
