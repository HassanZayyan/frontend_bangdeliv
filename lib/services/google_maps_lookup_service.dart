import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_env.dart';

class GoogleMapsPrediction {
  const GoogleMapsPrediction({
    required this.description,
    required this.placeId,
  });

  final String description;
  final String? placeId;
}

class GoogleMapsResolvedPlace {
  const GoogleMapsResolvedPlace({required this.target, this.address});

  final LatLng target;
  final String? address;
}

class GoogleMapsLookupService {
  const GoogleMapsLookupService();

  bool get isConfigured => AppEnv.googleMapsApiKey.trim().isNotEmpty;

  Future<List<GoogleMapsPrediction>> searchPlaces(String query) async {
    final normalizedQuery = query.trim();
    final apiKey = AppEnv.googleMapsApiKey.trim();
    if (normalizedQuery.isEmpty || apiKey.isEmpty) {
      return const <GoogleMapsPrediction>[];
    }

    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      <String, String>{
        'input': normalizedQuery,
        'key': apiKey,
        'components': 'country:id',
        'language': 'id',
      },
    );

    try {
      final response = await http.get(url);
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
  }) async {
    final apiKey = AppEnv.googleMapsApiKey.trim();
    if (apiKey.isEmpty) {
      return null;
    }

    final normalizedPlaceId = placeId?.trim() ?? '';
    if (normalizedPlaceId.isNotEmpty) {
      final resolved = await _resolvePlaceId(normalizedPlaceId, apiKey);
      if (resolved != null) {
        return resolved;
      }
    }

    final normalizedFallback = fallbackQuery?.trim() ?? '';
    if (normalizedFallback.isEmpty) {
      return null;
    }

    return geocodeQuery(normalizedFallback);
  }

  Future<GoogleMapsResolvedPlace?> geocodeQuery(String query) async {
    final normalizedQuery = query.trim();
    final apiKey = AppEnv.googleMapsApiKey.trim();
    if (normalizedQuery.isEmpty || apiKey.isEmpty) {
      return null;
    }

    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      <String, String>{
        'address': normalizedQuery,
        'key': apiKey,
        'language': 'id',
      },
    );

    try {
      final response = await http.get(url);
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
    final apiKey = AppEnv.googleMapsApiKey.trim();
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
      final response = await http.get(url);
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
    String apiKey,
  ) async {
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      <String, String>{'place_id': placeId, 'key': apiKey, 'language': 'id'},
    );

    try {
      final response = await http.get(url);
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
    return GoogleMapsPrediction(
      description: (json['description'] ?? '').toString(),
      placeId: json['place_id']?.toString(),
    );
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

    return GoogleMapsResolvedPlace(
      target: LatLng(lat.toDouble(), lng.toDouble()),
      address:
          cleanAddress(result['formatted_address']) ??
          cleanAddress(result['name']),
    );
  }
}
