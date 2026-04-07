import '../models/category_model.dart';
import '../models/food_model.dart';
import '../models/home_data_model.dart';
import '../models/merchant_model.dart';
import 'api_client.dart';
import 'api_exception.dart';

class HomeApiService {
  HomeApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<HomeDataModel> fetchHomeData({String search = ''}) async {
    try {
      final response = await _apiClient.get(
        '/v1/home',
        queryParams: <String, dynamic>{
          if (search.trim().isNotEmpty) 'search': search.trim(),
        },
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
                restaurantRating: _toDouble(item['restaurant_rating']),
              ),
            )
            .toList(growable: false),
        nearbyMerchants: merchantItems
            .map((item) => MerchantModel.fromApiJson(item))
            .toList(growable: false),
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return _fetchFromLegacyEndpoints(search: search);
      }

      rethrow;
    }
  }

  Future<HomeDataModel> _fetchFromLegacyEndpoints({String search = ''}) async {
    final restaurantsResponse = await _apiClient.get(
      '/v1/restaurants',
      queryParams: <String, dynamic>{
        'per_page': 10,
        'sort': 'rating',
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    );

    final restaurantItems = _extractList(restaurantsResponse['data']);
    final nearbyMerchants = restaurantItems
        .map((item) => MerchantModel.fromApiJson(item))
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
        final rating = _toDouble(restaurant['avg_rating']);

        for (final menu in menuItems.take(3)) {
          popularMenus.add(
            FoodModel.fromApiJson(
              menu,
              restaurantName: restaurantName,
              restaurantRating: rating,
            ),
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

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
