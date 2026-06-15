import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'driver UI and profile models no longer expose inactive rating fields',
    () {
      final driverHome = File(
        'lib/features/driver_orders/presentation/screens/driver_home_screen.dart',
      ).readAsStringSync();
      final driverProfile = File(
        'lib/features/profile/presentation/screens/driver_profile_screen.dart',
      ).readAsStringSync();
      final userProfileModel = File(
        'lib/models/user_profile_model.dart',
      ).readAsStringSync();
      final orderModel = File('lib/models/order_model.dart').readAsStringSync();

      expect(driverHome, isNot(contains('Rating')));
      expect(driverHome, isNot(contains('star_border')));
      expect(driverProfile, isNot(contains('Rating')));
      expect(userProfileModel, isNot(contains('avgRating')));
      expect(userProfileModel, isNot(contains('avg_rating')));
      expect(userProfileModel, isNot(contains('final double rating')));
      expect(orderModel, isNot(contains('rating')));
    },
  );
}
