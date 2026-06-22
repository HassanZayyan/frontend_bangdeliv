import 'dart:convert';
import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_env.dart';

class GoogleMapsPrediction {
  const GoogleMapsPrediction({
    required this.description,
    required this.placeId,
    this.name,
    this.types = const <String>[],
  });

  final String description;
  final String? placeId;
  final String? name;
  final List<String> types;
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

enum GoogleMapsLookupScope {
  indonesia,
  bangDelivServiceAreaAddress,
  salatigaServiceAreaAddress,
}

class GoogleMapsLookupService {
  const GoogleMapsLookupService({http.Client? client, String? apiKey})
    : _client = client,
      _apiKeyOverride = apiKey;

  static const _bangDelivServiceAreaCenter = LatLng(
    -7.319916770351389,
    110.46393594806243,
  );
  static const _bangDelivServiceAreaRadiusMeters = 50000;
  static const _bangDelivServiceAreaBounds =
      '-7.7700,110.0100|-6.8700,110.9200';
  static const _nearbyEstablishmentRadiusMeters = 120;
  static const _nearbyCandidateMaxDistanceMeters = 80.0;

  final http.Client? _client;
  final String? _apiKeyOverride;

  bool get isConfigured => _apiKey.isNotEmpty;

  String get _apiKey => (_apiKeyOverride ?? AppEnv.googleMapsApiKey).trim();

  Future<List<GoogleMapsPrediction>> searchPlaces(
    String query, {
    GoogleMapsLookupScope scope = GoogleMapsLookupScope.indonesia,
    String? sessionToken,
    bool establishmentOnly = false,
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
      if (establishmentOnly) 'types': 'establishment',
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

  Future<GoogleMapsResolvedPlace?> findNearestEstablishment(
    LatLng target, {
    int radiusMeters = _nearbyEstablishmentRadiusMeters,
    String? preferredQuery,
  }) async {
    final apiKey = _apiKey;
    if (apiKey.isEmpty) {
      return null;
    }

    // Map taps must resolve from the coordinate itself, not from stale search text.
    final nearby = await _findNearestNearbyPlace(
      target,
      apiKey,
      radiusMeters: radiusMeters,
    );
    if (nearby != null) {
      final address = (nearby.address ?? '').trim();
      if (address.isNotEmpty) {
        return nearby;
      }

      final fallbackAddress = await reverseGeocode(nearby.target);
      return GoogleMapsResolvedPlace(
        target: nearby.target,
        placeId: nearby.placeId,
        name: nearby.name,
        address: fallbackAddress,
        types: nearby.types,
      );
    }

    return null;
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

  Future<GoogleMapsResolvedPlace?> _findNearestNearbyPlace(
    LatLng target,
    String apiKey, {
    required int radiusMeters,
  }) async {
    final candidatesByKey = <String, GoogleMapsResolvedPlace>{};

    final candidates = await _nearbySearchCandidates(
      target,
      apiKey,
      radiusMeters: radiusMeters,
    );
    for (final candidate in candidates) {
      final name = (candidate.name ?? '').trim();
      if (name.isEmpty) {
        continue;
      }
      final key = _candidateDedupeKey(candidate);
      candidatesByKey[key] = candidate;
    }

    return _bestNearbyCandidate(target, candidatesByKey.values);
  }

  Future<List<GoogleMapsResolvedPlace>> _nearbySearchCandidates(
    LatLng target,
    String apiKey, {
    required int radiusMeters,
  }) async {
    final queryParameters = <String, String>{
      'location':
          '${target.latitude.toStringAsFixed(6)},${target.longitude.toStringAsFixed(6)}',
      'radius': radiusMeters.clamp(30, 500).toString(),
      'key': apiKey,
      'language': 'id',
    };

    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/nearbysearch/json',
      queryParameters,
    );

    try {
      final response = await _get(url);
      if (response.statusCode != 200) {
        return const <GoogleMapsResolvedPlace>[];
      }

      final data = json.decode(response.body);
      if (data is! Map<String, dynamic> || data['status'] != 'OK') {
        return const <GoogleMapsResolvedPlace>[];
      }

      final results = data['results'];
      if (results is! List || results.isEmpty) {
        return const <GoogleMapsResolvedPlace>[];
      }

      return results
          .whereType<Map<String, dynamic>>()
          .where(_isNamedPointOfInterestResult)
          .map(_resolvedPlaceFromResult)
          .whereType<GoogleMapsResolvedPlace>()
          .toList(growable: false);
    } catch (_) {
      return const <GoogleMapsResolvedPlace>[];
    }
  }

  GoogleMapsResolvedPlace? _bestNearbyCandidate(
    LatLng target,
    Iterable<GoogleMapsResolvedPlace> candidates,
  ) {
    final closeCandidates = candidates
        .where((candidate) {
          return _distanceMeters(target, candidate.target) <=
              _nearbyCandidateMaxDistanceMeters;
        })
        .toList(growable: false);

    if (closeCandidates.isEmpty) {
      return null;
    }

    closeCandidates.sort((left, right) {
      final leftScore = _candidateScore(target, left);
      final rightScore = _candidateScore(target, right);
      return leftScore.compareTo(rightScore);
    });

    return closeCandidates.first;
  }

  double _candidateScore(LatLng target, GoogleMapsResolvedPlace candidate) {
    return _distanceMeters(target, candidate.target);
  }

  String _candidateDedupeKey(GoogleMapsResolvedPlace candidate) {
    final placeId = (candidate.placeId ?? '').trim();
    if (placeId.isNotEmpty) {
      return 'place:$placeId';
    }

    return 'geo:${_normalizePlaceLookupText(candidate.name ?? '')}:'
        '${candidate.target.latitude.toStringAsFixed(6)},'
        '${candidate.target.longitude.toStringAsFixed(6)}';
  }

  GoogleMapsPrediction _predictionFromJson(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'];
    final name = structuredFormatting is Map<String, dynamic>
        ? cleanAddress(structuredFormatting['main_text'])
        : null;
    final rawTypes = json['types'];
    final types = rawTypes is List
        ? rawTypes
              .map((type) => type.toString().trim())
              .where((type) => type.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    return GoogleMapsPrediction(
      description: (json['description'] ?? '').toString(),
      placeId: json['place_id']?.toString(),
      name: name,
      types: types,
    );
  }

  Future<http.Response> _get(Uri url) {
    final client = _client;
    return client == null ? http.get(url) : client.get(url);
  }

  bool _isNamedPointOfInterestResult(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      return false;
    }

    final rawTypes = json['types'];
    final types = rawTypes is List
        ? rawTypes
              .map((type) => type.toString().trim().toLowerCase())
              .where((type) => type.isNotEmpty)
              .toSet()
        : const <String>{};
    return types.contains('establishment') ||
        types.contains('point_of_interest');
  }

  void _applyAutocompleteScope(
    Map<String, String> queryParameters,
    GoogleMapsLookupScope scope,
  ) {
    switch (scope) {
      case GoogleMapsLookupScope.indonesia:
        return;
      case GoogleMapsLookupScope.bangDelivServiceAreaAddress:
      case GoogleMapsLookupScope.salatigaServiceAreaAddress:
        queryParameters
          ..['location'] =
              '${_bangDelivServiceAreaCenter.latitude},${_bangDelivServiceAreaCenter.longitude}'
          ..['radius'] = _bangDelivServiceAreaRadiusMeters.toString()
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
      case GoogleMapsLookupScope.bangDelivServiceAreaAddress:
      case GoogleMapsLookupScope.salatigaServiceAreaAddress:
        queryParameters
          ..['bounds'] = _bangDelivServiceAreaBounds
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
    final formattedAddress =
        cleanAddress(result['formatted_address']) ??
        cleanAddress(result['vicinity']);
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

  String _normalizePlaceLookupText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _degreesToRadians(b.latitude - a.latitude);
    final dLng = _degreesToRadians(b.longitude - a.longitude);
    final lat1 = _degreesToRadians(a.latitude);
    final lat2 = _degreesToRadians(b.latitude);

    final haversine =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    return earthRadiusMeters *
        2 *
        math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
