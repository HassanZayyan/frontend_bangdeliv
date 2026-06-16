import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_env.dart';

class GoogleMapsPrediction {
  const GoogleMapsPrediction({
    required this.description,
    required this.placeId,
    this.name,
  });

  final String description;
  final String? placeId;
  final String? name;
}

class GoogleMapsResolvedPlace {
  const GoogleMapsResolvedPlace({
    required this.target,
    this.placeId,
    this.name,
    this.address,
    this.types = const <String>[],
  });

  final LatLng target;
  final String? placeId;
  final String? name;
  final String? address;
  final List<String> types;
}

enum GoogleMapsLookupScope { indonesia, salatigaServiceAreaAddress }

class GoogleMapsLookupService {
  const GoogleMapsLookupService({http.Client? client, String? apiKey})
    : _client = client,
      _apiKeyOverride = apiKey;

  static const _salatigaServiceAreaCenter = LatLng(-7.3305, 110.5084);
  static const _salatigaServiceAreaRadiusMeters = 45000;
  static const _salatigaServiceAreaBounds = '-7.6500,110.1000|-7.0500,110.8500';

  final http.Client? _client;
  final String? _apiKeyOverride;

  bool get isConfigured => _apiKey.isNotEmpty;

  String get _apiKey => (_apiKeyOverride ?? AppEnv.googleMapsApiKey).trim();

  Future<List<GoogleMapsPrediction>> searchPlaces(
    String query, {
    GoogleMapsLookupScope scope = GoogleMapsLookupScope.indonesia,
    String? sessionToken,
  }) async {
    final normalizedQuery = query.trim();
    final apiKey = _apiKey;
    if (normalizedQuery.isEmpty || apiKey.isEmpty) {
      return const <GoogleMapsPrediction>[];
    }

    final queryParameters = <String, String>{
      'input': normalizedQuery,
      'key': apiKey,
      'components': 'country:id',
      'language': 'id',
      if ((sessionToken ?? '').trim().isNotEmpty)
        'sessiontoken': sessionToken!.trim(),
    };
    _applyAutocompleteScope(queryParameters, scope);

    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      queryParameters,
    );

    try {
      final response = await _get(url);
      if (response.statusCode != 200) {
        return const <GoogleMapsPrediction>[];
      }

      final data = json.decode(response.body);
      if (data is! Map<String, dynamic> || data['status'] != 'OK') {
        return const <GoogleMapsPrediction>[];
      }

      final predictions = data['predictions'];
      if (predictions is! List) {
        return const <GoogleMapsPrediction>[];
      }

      return predictions
          .whereType<Map<String, dynamic>>()
          .map(_predictionFromJson)
          .where((prediction) => prediction.description.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <GoogleMapsPrediction>[];
    }
  }

  Future<GoogleMapsResolvedPlace?> resolvePlace({
    String? placeId,
    String? fallbackQuery,
    GoogleMapsLookupScope scope = GoogleMapsLookupScope.indonesia,
    String? sessionToken,
  }) async {
    final apiKey = _apiKey;
    if (apiKey.isEmpty) {
      return null;
    }

    final normalizedPlaceId = placeId?.trim() ?? '';
    if (normalizedPlaceId.isNotEmpty) {
      final resolved = await _resolvePlaceId(
        normalizedPlaceId,
        apiKey,
        sessionToken: sessionToken,
      );
      if (resolved != null) {
        return resolved;
      }
    }

    final normalizedFallback = fallbackQuery?.trim() ?? '';
    if (normalizedFallback.isEmpty) {
      return null;
    }

    return geocodeQuery(normalizedFallback, scope: scope);
  }

  Future<GoogleMapsResolvedPlace?> geocodeQuery(
    String query, {
    GoogleMapsLookupScope scope = GoogleMapsLookupScope.indonesia,
  }) async {
    final normalizedQuery = query.trim();
    final apiKey = _apiKey;
    if (normalizedQuery.isEmpty || apiKey.isEmpty) {
      return null;
    }

    final queryParameters = <String, String>{
      'address': normalizedQuery,
      'key': apiKey,
      'language': 'id',
    };
    _applyGeocodeScope(queryParameters, scope);

    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      queryParameters,
    );

    try {
      final response = await _get(url);
      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body);
      if (data is! Map<String, dynamic> || data['status'] != 'OK') {
        return null;
      }

      final results = data['results'];
      if (results is! List || results.isEmpty) {
        return null;
      }

      final first = results.first;
      if (first is! Map<String, dynamic>) {
        return null;
      }

      return _resolvedPlaceFromResult(first);
    } catch (_) {
      return null;
    }
  }

  Future<String?> reverseGeocode(LatLng target) async {
    final apiKey = _apiKey;
    if (apiKey.isEmpty) {
      return null;
    }

    final url = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', <
      String,
      String
    >{
      'latlng':
          '${target.latitude.toStringAsFixed(6)},${target.longitude.toStringAsFixed(6)}',
      'key': apiKey,
      'language': 'id',
    });

    try {
      final response = await _get(url);
      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body);
      if (data is! Map<String, dynamic> || data['status'] != 'OK') {
        return null;
      }

      final results = data['results'];
      if (results is! List || results.isEmpty) {
        return null;
      }

      final first = results.first;
      if (first is! Map<String, dynamic>) {
        return null;
      }

      return cleanAddress(first['formatted_address']);
    } catch (_) {
      return null;
    }
  }

  String? cleanAddress(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    if (RegExp(r'^pin\s+-?\d', caseSensitive: false).hasMatch(text)) {
      return null;
    }

    return text;
  }

  Future<GoogleMapsResolvedPlace?> _resolvePlaceId(
    String placeId,
    String apiKey, {
    String? sessionToken,
  }) async {
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      <String, String>{
        'place_id': placeId,
        'key': apiKey,
        'language': 'id',
        'fields': 'place_id,name,formatted_address,geometry,type',
        if ((sessionToken ?? '').trim().isNotEmpty)
          'sessiontoken': sessionToken!.trim(),
      },
    );

    try {
      final response = await _get(url);
      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body);
      if (data is! Map<String, dynamic> || data['status'] != 'OK') {
        return null;
      }

      final result = data['result'];
      if (result is! Map<String, dynamic>) {
        return null;
      }

      return _resolvedPlaceFromResult(result);
    } catch (_) {
      return null;
    }
  }

  GoogleMapsPrediction _predictionFromJson(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'];
    final name = structuredFormatting is Map<String, dynamic>
        ? cleanAddress(structuredFormatting['main_text'])
        : null;

    return GoogleMapsPrediction(
      description: (json['description'] ?? '').toString(),
      placeId: json['place_id']?.toString(),
      name: name,
    );
  }

  Future<http.Response> _get(Uri url) {
    final client = _client;
    return client == null ? http.get(url) : client.get(url);
  }

  void _applyAutocompleteScope(
    Map<String, String> queryParameters,
    GoogleMapsLookupScope scope,
  ) {
    switch (scope) {
      case GoogleMapsLookupScope.indonesia:
        return;
      case GoogleMapsLookupScope.salatigaServiceAreaAddress:
        queryParameters
          ..['location'] =
              '${_salatigaServiceAreaCenter.latitude},${_salatigaServiceAreaCenter.longitude}'
          ..['radius'] = _salatigaServiceAreaRadiusMeters.toString()
          ..['strictbounds'] = 'true';
    }
  }

  void _applyGeocodeScope(
    Map<String, String> queryParameters,
    GoogleMapsLookupScope scope,
  ) {
    switch (scope) {
      case GoogleMapsLookupScope.indonesia:
        return;
      case GoogleMapsLookupScope.salatigaServiceAreaAddress:
        queryParameters
          ..['bounds'] = _salatigaServiceAreaBounds
          ..['components'] = 'country:ID';
    }
  }

  GoogleMapsResolvedPlace? _resolvedPlaceFromResult(
    Map<String, dynamic> result,
  ) {
    final geometry = result['geometry'];
    final location = geometry is Map<String, dynamic>
        ? geometry['location']
        : null;
    final lat = location is Map<String, dynamic> ? location['lat'] : null;
    final lng = location is Map<String, dynamic> ? location['lng'] : null;
    if (lat is! num || lng is! num) {
      return null;
    }

    final placeId = cleanAddress(result['place_id']);
    final formattedAddress = cleanAddress(result['formatted_address']);
    final placeName = cleanAddress(result['name']);
    final rawTypes = result['types'];
    final types = rawTypes is List
        ? rawTypes
              .map((type) => type.toString().trim())
              .where((type) => type.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    return GoogleMapsResolvedPlace(
      target: LatLng(lat.toDouble(), lng.toDouble()),
      placeId: placeId,
      name: placeName,
      address: _buildDisplayAddress(
        placeName: placeName,
        formattedAddress: formattedAddress,
      ),
      types: types,
    );
  }

  String? _buildDisplayAddress({
    required String? placeName,
    required String? formattedAddress,
  }) {
    if (placeName == null || placeName.isEmpty) {
      return formattedAddress;
    }
    if (formattedAddress == null || formattedAddress.isEmpty) {
      return placeName;
    }

    final normalizedPlaceName = placeName.toLowerCase();
    final normalizedFormatted = formattedAddress.toLowerCase();
    if (normalizedFormatted.contains(normalizedPlaceName)) {
      return formattedAddress;
    }

    return '$placeName, $formattedAddress';
  }
}
