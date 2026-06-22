import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/features/shopping/presentation/widgets/shopping_widget_helpers.dart';

void main() {
  test('shoppingMerchantTypeFromPlace maps warung and market-like places', () {
    expect(
      shoppingMerchantTypeFromPlace(
        name: 'Warung Bunda Dhia',
        types: const ['food', 'establishment'],
      ),
      'warung',
    );
    expect(
      shoppingMerchantTypeFromPlace(
        name: 'Hypermart Salatiga',
        types: const ['store', 'establishment'],
      ),
      'convenience_store',
    );
    expect(
      shoppingMerchantTypeFromPlace(
        name: 'Kopi Contoh',
        types: const ['cafe', 'food', 'establishment'],
      ),
      'restaurant',
    );
  });

  test('shoppingMerchantTypeLabel uses neutral label for general places', () {
    expect(shoppingMerchantTypeLabel('restaurant'), 'Resto');
    expect(shoppingMerchantTypeLabel('convenience_store'), 'Minimarket');
    expect(shoppingMerchantTypeLabel('other'), 'Tempat');
  });

  test('isAllowedShoppingMerchantPlace allows named POI places', () {
    expect(
      isAllowedShoppingMerchantPlace(
        name: 'Kopi Contoh',
        types: const ['cafe', 'food', 'establishment'],
      ),
      isTrue,
    );
    expect(
      isAllowedShoppingMerchantPlace(
        name: 'Hypermart Salatiga',
        types: const ['store', 'establishment'],
      ),
      isTrue,
    );
    expect(
      isAllowedShoppingMerchantPlace(
        name: 'de Jangli Palm Villa',
        types: const ['point_of_interest', 'establishment'],
      ),
      isTrue,
    );
    expect(
      isAllowedShoppingMerchantPlace(
        name: 'Bank Contoh',
        types: const ['bank', 'finance', 'establishment'],
      ),
      isFalse,
    );
    expect(
      isAllowedShoppingMerchantPlace(
        name: 'Gym Contoh',
        types: const ['gym', 'health', 'establishment'],
      ),
      isFalse,
    );
  });
}
