import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/config/app_theme.dart';
import 'package:frontend_bangdeliv/core/di/app_providers.dart';
import 'package:frontend_bangdeliv/features/home/presentation/screens/merchant_detail_screen.dart';
import 'package:frontend_bangdeliv/models/food_model.dart';
import 'package:frontend_bangdeliv/models/home_data_model.dart';
import 'package:frontend_bangdeliv/models/merchant_detail_model.dart';
import 'package:frontend_bangdeliv/models/merchant_model.dart';
import 'package:frontend_bangdeliv/services/api_client.dart';
import 'package:frontend_bangdeliv/services/home_api_service.dart';

void main() {
  testWidgets('merchant detail shows backend full address', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeApiServiceProvider.overrideWithValue(_FakeHomeApiService()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MerchantDetailScreen(merchantId: '1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text("Rendy's Chicken"), findsOneWidget);
    final addressFinder = find.text('Jl. Tentara Pelajar No. 12, Ambarawa');
    expect(addressFinder, findsOneWidget);

    final addressText = tester.widget<Text>(addressFinder);
    expect(addressText.style?.fontWeight, FontWeight.w500);
  });
}

class _FakeHomeApiService extends HomeApiService {
  _FakeHomeApiService() : super(ApiClient());

  @override
  Future<MerchantDetailModel> fetchMerchantDetail(String merchantId) async {
    return MerchantDetailModel(
      merchant: MerchantModel.fromApiJson(const <String, dynamic>{
        'id': 1,
        'name': "Rendy's Chicken",
        'merchant_type': 'restaurant',
        'full_address': 'Jl. Tentara Pelajar No. 12, Ambarawa',
        'banner_image': null,
        'gallery_images': <String>[],
      }),
      menus: const <FoodModel>[],
    );
  }

  @override
  Future<HomeDataModel> fetchHomeData({
    String search = '',
    int? limitMerchants,
    double? latitude,
    double? longitude,
  }) async {
    return const HomeDataModel(
      categories: [],
      popularMenus: [],
      nearbyMerchants: [],
    );
  }
}
