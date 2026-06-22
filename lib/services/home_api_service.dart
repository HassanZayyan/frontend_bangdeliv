import '../models/category_model.dart';
import '../models/food_model.dart';
import '../models/home_data_model.dart';
import '../models/merchant_detail_model.dart';
import '../models/merchant_model.dart';
import 'api_client.dart';
import 'api_exception.dart';

class HomeApiService {
  HomeApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<MerchantDetailModel> fetchMerchantDetail(String merchantId) async {
    final normalizedId = merchantId.trim();
    if (normalizedId.isEmpty) {
      throw const ApiException('Tempat tidak valid.');
    }

    final detailResponse = await _apiClient.get(
      '/v1/restaurants/$normalizedId',
    );
    final detailData = (detailResponse['data'] is Map<String, dynamic>)
        ? detailResponse['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    final merchant = MerchantModel.fromApiJson(detailData);

    final menusResponse = await _apiClient.get(
      '/v1/restaurants/$normalizedId/menus',
      queryParams: const <String, dynamic>{'only_available': '1'},
    );
    final menusData = (menusResponse['data'] is Map<String, dynamic>)
        ? menusResponse['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    final restaurantData = (menusData['restaurant'] is Map<String, dynamic>)
        ? menusData['restaurant'] as Map<String, dynamic>
        : <String, dynamic>{};
    final restaurantName = restaurantData['name']?.toString() ?? merchant.name;
    final menus = _extractList(menusData['menus'])
        .map(
          (menu) => FoodModel.fromApiJson(menu, restaurantName: restaurantName),
        )
        .toList(growable: false);

    return MerchantDetailModel(merchant: merchant, menus: menus);
  }

  Future<HomeDataModel> fetchHomeData({
    String search = '',
    int? limitMerchants,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (latitude != null && longitude != null) ...{
          'latitude': latitude,
          'longitude': longitude,
        },
      };
      if (limitMerchants != null) {
        queryParams['limit_merchants'] = limitMerchants;
      }

      final response = await _apiClient.get(
        '/v1/home',
        queryParams: queryParams,
      );

      final data = (response['data'] is Map<String, dynamic>)
          ? response['data'] as Map<String, dynamic>
          : <String, dynamic>{};

      final categoryItems = _extractList(data['categories']);
      final popularItems = _extractList(data['popular_menus']);
      final merchantItems = _extractList(data['nearby_merchants']);

      return HomeDataModel(
        categories: categoryItems
            .map((item) => CategoryModel.fromApiJson(item))
            .toList(growable: false),
        popularMenus: popularItems
            .map(
              (item) => FoodModel.fromApiJson(
                item,
                restaurantName: item['restaurant_name']?.toString() ?? '-',
              ),
            )
            .toList(growable: false),
        nearbyMerchants: merchantItems
            .map((item) => MerchantModel.fromApiJson(item))
            .toList(growable: false),
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return _fetchFromLegacyEndpoints(
          search: search,
          limitMerchants: limitMerchants,
          latitude: latitude,
          longitude: longitude,
        );
      }

      rethrow;
    }
  }

  Future<HomeDataModel> _fetchFromLegacyEndpoints({
    String search = '',
    int? limitMerchants,
    double? latitude,
    double? longitude,
  }) async {
    final hasLocation = latitude != null && longitude != null;

    final restaurantsResponse = await _apiClient.get(
      '/v1/restaurants',
      queryParams: <String, dynamic>{
        'per_page': limitMerchants ?? 10,
        'sort': hasLocation ? 'nearest' : 'name',
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (hasLocation) ...{'latitude': latitude, 'longitude': longitude},
      },
    );

    final restaurantItems = _extractList(restaurantsResponse['data']);
    final nearbyMerchants = restaurantItems
        .map((item) => MerchantModel.fromApiJson(item))
        .take(limitMerchants ?? 10)
        .toList(growable: false);

    final categoriesByName = <String, CategoryModel>{};
    final popularMenus = <FoodModel>[];
    final restaurantSamples = restaurantItems.take(4).toList(growable: false);

    for (final restaurant in restaurantSamples) {
      final restaurantId = restaurant['id']?.toString();
      if (restaurantId == null || restaurantId.isEmpty) {
        continue;
      }

      try {
        final menusResponse = await _apiClient.get(
          '/v1/restaurants/$restaurantId/menus',
        );
        final menusData = (menusResponse['data'] is Map<String, dynamic>)
            ? menusResponse['data'] as Map<String, dynamic>
            : <String, dynamic>{};

        final categoryItems = _extractList(menusData['categories']);
        final menuItems = _extractList(menusData['menus']);

        for (final category in categoryItems) {
          final name = category['name']?.toString();
          if (name == null || name.trim().isEmpty) {
            continue;
          }

          categoriesByName.putIfAbsent(
            name.toLowerCase(),
            () => CategoryModel.fromApiJson(category),
          );
        }

        final restaurantName = restaurant['name']?.toString() ?? '-';
        for (final menu in menuItems.take(3)) {
          popularMenus.add(
            FoodModel.fromApiJson(menu, restaurantName: restaurantName),
          );
        }
      } catch (_) {
        continue;
      }
    }

    return HomeDataModel(
      categories: categoriesByName.values.take(8).toList(growable: false),
      popularMenus: popularMenus.take(8).toList(growable: false),
      nearbyMerchants: nearbyMerchants,
    );
  }

  List<Map<String, dynamic>> _extractList(dynamic value) {
    if (value is! List<dynamic>) {
      return const <Map<String, dynamic>>[];
    }

    return value.whereType<Map<String, dynamic>>().toList(growable: false);
  }
}
