import 'app_env.dart';

class PaymentAssets {
  PaymentAssets._();

  static const String qrisPath = '/images/payments/qris-bangdeliv';

  static String get qrisUrl => '${AppEnv.backendOrigin}$qrisPath';
}
