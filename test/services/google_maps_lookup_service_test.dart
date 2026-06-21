import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/services/google_maps_lookup_service.dart';

void main() {
  test('cleanAddress drops generated pin labels and keeps real addresses', () {
    const service = GoogleMapsLookupService();

    expect(service.cleanAddress('Pin -7.123,110.456'), isNull);
    expect(service.cleanAddress('  Jalan Mawar 1  '), 'Jalan Mawar 1');
    expect(service.cleanAddress(''), isNull);
  });

  test(
    'searchPlaces can scope address search to Salatiga service area',
    () async {
      late Uri requestedUrl;
      final service = GoogleMapsLookupService(
        apiKey: 'test-key',
        client: MockClient((request) async {
          requestedUrl = request.url;
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'predictions': [
                {
                  'description': 'Jl. Diponegoro, Salatiga',
                  'place_id': 'abc',
                  'types': ['route', 'geocode'],
                },
              ],
            }),
            200,
          );
        }),
      );

      final predictions = await service.searchPlaces(
        'Diponegoro',
        scope: GoogleMapsLookupScope.salatigaServiceAreaAddress,
      );

      expect(predictions, hasLength(1));
      expect(predictions.single.types, ['route', 'geocode']);
      expect(requestedUrl.path, '/maps/api/place/autocomplete/json');
      expect(requestedUrl.queryParameters['components'], 'country:id');
      expect(requestedUrl.queryParameters['language'], 'id');
      expect(requestedUrl.queryParameters['location'], '-7.3305,110.5084');
      expect(requestedUrl.queryParameters['radius'], '45000');
      expect(requestedUrl.queryParameters['strictbounds'], 'true');
    },
  );

  test('searchPlaces can restrict predictions to establishments', () async {
    late Uri requestedUrl;
    final service = GoogleMapsLookupService(
      apiKey: 'test-key',
      client: MockClient((request) async {
        requestedUrl = request.url;
        return http.Response(
          jsonEncode({
            'status': 'OK',
            'predictions': [
              {
                'description': 'Kopi Contoh, Salatiga',
                'place_id': 'place-1',
                'structured_formatting': {'main_text': 'Kopi Contoh'},
                'types': ['cafe', 'food', 'establishment'],
              },
            ],
          }),
          200,
        );
      }),
    );

    final predictions = await service.searchPlaces(
      'kopi',
      establishmentOnly: true,
    );

    expect(predictions.single.name, 'Kopi Contoh');
    expect(predictions.single.types, ['cafe', 'food', 'establishment']);
    expect(requestedUrl.queryParameters['types'], 'establishment');
  });

  test(
    'geocodeQuery can scope address lookup with service-area bounds',
    () async {
      late Uri requestedUrl;
      final service = GoogleMapsLookupService(
        apiKey: 'test-key',
        client: MockClient((request) async {
          requestedUrl = request.url;
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'results': [
                {
                  'formatted_address': 'Jl. Patimura, Salatiga',
                  'geometry': {
                    'location': {'lat': -7.33, 'lng': 110.5},
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final resolved = await service.geocodeQuery(
        'Patimura',
        scope: GoogleMapsLookupScope.salatigaServiceAreaAddress,
      );

      expect(resolved?.address, 'Jl. Patimura, Salatiga');
      expect(requestedUrl.path, '/maps/api/geocode/json');
      expect(
        requestedUrl.queryParameters['bounds'],
        '-7.6500,110.1000|-7.0500,110.8500',
      );
      expect(requestedUrl.queryParameters['components'], 'country:ID');
    },
  );

  test(
    'reverseGeocode remains unscoped for user GPS and manual map pins',
    () async {
      late Uri requestedUrl;
      final service = GoogleMapsLookupService(
        apiKey: 'test-key',
        client: MockClient((request) async {
          requestedUrl = request.url;
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'results': [
                {'formatted_address': 'Alamat dari titik pengguna'},
              ],
            }),
            200,
          );
        }),
      );

      final address = await service.reverseGeocode(const LatLng(-7.4, 110.3));

      expect(address, 'Alamat dari titik pengguna');
      expect(requestedUrl.path, '/maps/api/geocode/json');
      expect(requestedUrl.queryParameters, isNot(contains('bounds')));
      expect(requestedUrl.queryParameters, isNot(contains('components')));
      expect(requestedUrl.queryParameters, isNot(contains('location')));
      expect(requestedUrl.queryParameters, isNot(contains('radius')));
      expect(requestedUrl.queryParameters, isNot(contains('strictbounds')));
    },
  );
}
