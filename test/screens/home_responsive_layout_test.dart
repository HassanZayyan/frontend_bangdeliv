import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/config/app_theme.dart';
import 'package:frontend_bangdeliv/core/di/app_providers.dart';
import 'package:frontend_bangdeliv/features/home/presentation/screens/home_screen.dart';
import 'package:frontend_bangdeliv/models/home_data_model.dart';
import 'package:frontend_bangdeliv/models/merchant_model.dart';
import 'package:frontend_bangdeliv/services/api_client.dart';
import 'package:frontend_bangdeliv/services/home_api_service.dart';

void main() {
  testWidgets('home layout fits compact screen with large text scale', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeApiServiceProvider.overrideWithValue(_FakeHomeApiService()),
        ],
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Layanan BangDeliv'), findsOneWidget);
    expect(find.text('Toko & Resto Terdekat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeHomeApiService extends HomeApiService {
  _FakeHomeApiService() : super(ApiClient());

  @override
  Future<HomeDataModel> fetchHomeData({
    String search = '',
    int? limitMerchants,
    double? latitude,
    double? longitude,
  }) async {
    return HomeDataModel(
      categories: const [],
      popularMenus: const [],
      nearbyMerchants: [
        MerchantModel(
          id: '1',
          name: 'Resto Taman Kedai Satu',
          distance: '0.1 km',
          imageUrl: '',
        ),
        MerchantModel(
          id: '2',
          name: 'Dapur Mrican BangDeliv',
          distance: '0.1 km',
          imageUrl: '',
        ),
        MerchantModel(
          id: '3',
          name: 'Alfamart BangDeliv Point',
          distance: '0.1 km',
          imageUrl: '',
        ),
        MerchantModel(
          id: '4',
          name: 'Warung Makan Ndeso Sampangan',
          distance: '0.1 km',
          imageUrl: '',
        ),
      ],
    );
  }
}
