import 'category_model.dart';
import 'food_model.dart';
import 'merchant_model.dart';

class HomeDataModel {
  final List<CategoryModel> categories;
  final List<FoodModel> popularMenus;
  final List<MerchantModel> nearbyMerchants;

  const HomeDataModel({
    required this.categories,
    required this.popularMenus,
    required this.nearbyMerchants,
  });
}
