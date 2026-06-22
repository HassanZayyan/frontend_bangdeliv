import 'food_model.dart';
import 'merchant_model.dart';

class MerchantDetailModel {
  const MerchantDetailModel({required this.merchant, required this.menus});

  final MerchantModel merchant;
  final List<FoodModel> menus;
}
