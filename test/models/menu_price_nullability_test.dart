import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/models/food_model.dart';
import 'package:frontend_bangdeliv/services/customer_order_api_service.dart';

void main() {
  test(
    'food model treats null menu price as pending and zero as reference',
    () {
      final nullPrice = FoodModel.fromApiJson(const <String, dynamic>{
        'id': 1,
        'name': 'Harga Nota',
        'price': null,
      }, restaurantName: 'Resto Test');
      final zeroPrice = FoodModel.fromApiJson(const <String, dynamic>{
        'id': 2,
        'name': 'Level 0',
        'price': 0,
      }, restaurantName: 'Resto Test');

      expect(nullPrice.price, isNull);
      expect(nullPrice.hasReferencePrice, isFalse);
      expect(nullPrice.formattedPrice, 'Harga sesuai nota');
      expect(zeroPrice.price, 0);
      expect(zeroPrice.hasReferencePrice, isTrue);
      expect(zeroPrice.formattedPrice, 'Rp0');
    },
  );

  test('shopping menu option preserves null and zero prices', () {
    final nullPrice = ShoppingMenuOption.fromJson(const <String, dynamic>{
      'id': 1,
      'name': 'Harga Nota',
      'price': null,
    });
    final zeroPrice = ShoppingMenuOption.fromJson(const <String, dynamic>{
      'id': 2,
      'name': 'Level 0',
      'price': 0,
    });

    expect(nullPrice.price, isNull);
    expect(zeroPrice.price, 0);
  });
}
