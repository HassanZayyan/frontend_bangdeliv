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
    'searchPlaces can scope address search to Bang Deliv service area',
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
        scope: GoogleMapsLookupScope.bangDelivServiceAreaAddress,
      );

      expect(predictions, hasLength(1));
      expect(predictions.single.types, ['route', 'geocode']);
      expect(requestedUrl.path, '/maps/api/place/autocomplete/json');
      expect(requestedUrl.queryParameters['components'], 'country:id');
      expect(requestedUrl.queryParameters['language'], 'id');
      expect(
        requestedUrl.queryParameters['location'],
        '-7.319916770351389,110.46393594806243',
      );
      expect(requestedUrl.queryParameters['radius'], '50000');
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
    'searchPlaces can restrict to location bias and sort by distance',
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
                  'description': 'Alfamart Jakarta',
                  'place_id': 'far-alfamart',
                  'structured_formatting': {'main_text': 'Alfamart'},
                  'distance_meters': 120000,
                  'types': ['convenience_store', 'establishment'],
                },
                {
                  'description': 'Alfamart Salatiga',
                  'place_id': 'near-alfamart',
                  'structured_formatting': {'main_text': 'Alfamart'},
                  'distance_meters': 450,
                  'types': ['convenience_store', 'establishment'],
                },
              ],
            }),
            200,
          );
        }),
      );

      final predictions = await service.searchPlaces(
        'alfamart',
        establishmentOnly: true,
        locationBias: const LatLng(-7.3178, 110.4630),
        radiusMeters: 50000,
        restrictToLocationBias: true,
      );

      expect(predictions.map((prediction) => prediction.placeId), [
        'near-alfamart',
        'far-alfamart',
      ]);
      expect(predictions.first.distanceMeters, 450);
      expect(requestedUrl.queryParameters['origin'], '-7.317800,110.463000');
      expect(
        requestedUrl.queryParameters['locationrestriction'],
        'circle:50000@-7.317800,110.463000',
      );
      expect(requestedUrl.queryParameters, isNot(contains('location')));
      expect(requestedUrl.queryParameters, isNot(contains('radius')));
      expect(requestedUrl.queryParameters, isNot(contains('strictbounds')));
    },
  );

  test(
    'searchPlaces can supplement autocomplete results up to requested max',
    () async {
      final requestedUrls = <Uri>[];
      final service = GoogleMapsLookupService(
        apiKey: 'test-key',
        client: MockClient((request) async {
          requestedUrls.add(request.url);
          if (request.url.path == '/maps/api/place/autocomplete/json') {
            return http.Response(
              jsonEncode({
                'status': 'OK',
                'predictions': [
                  for (var index = 1; index <= 5; index++)
                    {
                      'description': 'Alamat Autocomplete $index',
                      'place_id': 'auto-$index',
                      'structured_formatting': {
                        'main_text': 'Autocomplete $index',
                      },
                      'distance_meters': index * 1000,
                      'types': ['establishment'],
                    },
                ],
              }),
              200,
            );
          }

          expect(request.url.path, '/maps/api/place/textsearch/json');
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'results': [
                {
                  'name': 'Alfamart Dekat',
                  'place_id': 'text-near',
                  'formatted_address': 'Jl. Dekat',
                  'types': ['store', 'establishment'],
                  'geometry': {
                    'location': {'lat': -7.3179, 'lng': 110.4630},
                  },
                },
                {
                  'name': 'Alfamart Tengah',
                  'place_id': 'text-mid',
                  'formatted_address': 'Jl. Tengah',
                  'types': ['store', 'establishment'],
                  'geometry': {
                    'location': {'lat': -7.3200, 'lng': 110.4630},
                  },
                },
                {
                  'name': 'Alfamart Jauh',
                  'place_id': 'text-far',
                  'formatted_address': 'Jl. Jauh',
                  'types': ['store', 'establishment'],
                  'geometry': {
                    'location': {'lat': -7.3700, 'lng': 110.4630},
                  },
                },
                {
                  'name': 'Alfamart Lebih Jauh',
                  'place_id': 'text-extra',
                  'formatted_address': 'Jl. Lebih Jauh',
                  'types': ['store', 'establishment'],
                  'geometry': {
                    'location': {'lat': -7.3900, 'lng': 110.4630},
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final predictions = await service.searchPlaces(
        'alfamart',
        locationBias: const LatLng(-7.3178, 110.4630),
        radiusMeters: 50000,
        restrictToLocationBias: true,
        maxResults: 8,
      );

      expect(predictions, hasLength(8));
      expect(predictions.map((prediction) => prediction.placeId), [
        'text-near',
        'text-mid',
        'auto-1',
        'auto-2',
        'auto-3',
        'auto-4',
        'auto-5',
        'text-far',
      ]);
      expect(requestedUrls.map((url) => url.path), [
        '/maps/api/place/autocomplete/json',
        '/maps/api/place/textsearch/json',
      ]);
      expect(requestedUrls.last.queryParameters['query'], 'alfamart');
      expect(requestedUrls.last.queryParameters['radius'], '50000');
      expect(
        requestedUrls.last.queryParameters['location'],
        '-7.317800,110.463000',
      );
    },
  );

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
        scope: GoogleMapsLookupScope.bangDelivServiceAreaAddress,
      );

      expect(resolved?.address, 'Jl. Patimura, Salatiga');
      expect(requestedUrl.path, '/maps/api/geocode/json');
      expect(
        requestedUrl.queryParameters['bounds'],
        '-7.7700,110.0100|-6.8700,110.9200',
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

  test('findNearestEstablishment chooses nearest named POI', () async {
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
                'name': 'Bakso Yupiter',
                'place_id': 'far-bakso',
                'vicinity': 'Jl. Jupiter II',
                'types': ['restaurant', 'food', 'establishment'],
                'geometry': {
                  'location': {'lat': -7.31820, 'lng': 110.46330},
                },
              },
              {
                'name': 'de Jangli Palm Villa',
                'place_id': 'near-villa',
                'vicinity': 'Jl. Jangli Gabeng',
                'types': ['point_of_interest', 'establishment'],
                'geometry': {
                  'location': {'lat': -7.31781, 'lng': 110.46301},
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    final resolved = await service.findNearestEstablishment(
      const LatLng(-7.3178, 110.463),
    );

    expect(resolved?.placeId, 'near-villa');
    expect(resolved?.name, 'de Jangli Palm Villa');
    expect(resolved?.address, 'de Jangli Palm Villa, Jl. Jangli Gabeng');
    expect(resolved?.types, ['point_of_interest', 'establishment']);
    expect(requestedUrl.path, '/maps/api/place/nearbysearch/json');
    expect(requestedUrl.queryParameters['radius'], '120');
    expect(requestedUrl.queryParameters['location'], '-7.317800,110.463000');
    expect(requestedUrl.queryParameters, isNot(contains('keyword')));
    expect(requestedUrl.queryParameters, isNot(contains('type')));
  });

  test(
    'findNearestEstablishment prefers nearest coffee over stale preferred query',
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
                  'name': 'Bakso Yupiter',
                  'place_id': 'bakso-yupiter',
                  'vicinity': 'Jalan Jupiter II No.19, Jangli',
                  'types': ['restaurant', 'food', 'establishment'],
                  'geometry': {
                    'location': {'lat': -7.31845, 'lng': 110.46345},
                  },
                },
                {
                  'name': 'oriana coffee',
                  'place_id': 'oriana-coffee',
                  'vicinity': 'Jl. Jangli Gabeng',
                  'types': ['cafe', 'food', 'establishment'],
                  'geometry': {
                    'location': {'lat': -7.31781, 'lng': 110.46301},
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final resolved = await service.findNearestEstablishment(
        const LatLng(-7.3178, 110.463),
        preferredQuery: 'Bakso Yupiter',
      );

      expect(resolved?.placeId, 'oriana-coffee');
      expect(resolved?.name, 'oriana coffee');
      expect(requestedUrl.queryParameters, isNot(contains('keyword')));
      expect(requestedUrl.queryParameters, isNot(contains('type')));
    },
  );

  test(
    'findNearestEstablishment returns null without nearby establishment',
    () async {
      final requestedPaths = <String>[];
      final service = GoogleMapsLookupService(
        apiKey: 'test-key',
        client: MockClient((request) async {
          requestedPaths.add(request.url.path);
          if (request.url.path == '/maps/api/place/nearbysearch/json') {
            return http.Response(jsonEncode({'status': 'ZERO_RESULTS'}), 200);
          }

          fail('Reverse geocode must not be used as a merchant result.');
        }),
      );

      final resolved = await service.findNearestEstablishment(
        const LatLng(-7.3178, 110.463),
      );

      expect(resolved, isNull);
      expect(requestedPaths, ['/maps/api/place/nearbysearch/json']);
    },
  );

  test('findNearestEstablishment ignores road-only nearby results', () async {
    final requestedPaths = <String>[];
    final service = GoogleMapsLookupService(
      apiKey: 'test-key',
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path == '/maps/api/place/nearbysearch/json') {
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'results': [
                {
                  'name': 'Jl. Jatisari V No.10',
                  'place_id': 'road-result',
                  'vicinity': 'Tembalang',
                  'types': ['route', 'geocode'],
                  'geometry': {
                    'location': {'lat': -7.3178, 'lng': 110.4630},
                  },
                },
              ],
            }),
            200,
          );
        }

        fail('Reverse geocode must not be used as a merchant result.');
      }),
    );

    final resolved = await service.findNearestEstablishment(
      const LatLng(-7.3178, 110.463),
    );

    expect(resolved, isNull);
    expect(requestedPaths, ['/maps/api/place/nearbysearch/json']);
  });

  test(
    'findNearestEstablishment rejects far candidates without fallback merchant',
    () async {
      final requestedPaths = <String>[];
      Uri? nearbyUrl;
      final service = GoogleMapsLookupService(
        apiKey: 'test-key',
        client: MockClient((request) async {
          requestedPaths.add(request.url.path);
          if (request.url.path == '/maps/api/place/nearbysearch/json') {
            nearbyUrl ??= request.url;
            return http.Response(
              jsonEncode({
                'status': 'OK',
                'results': [
                  {
                    'name': 'Osha Mart Salatiga',
                    'place_id': 'osha-mart',
                    'vicinity': 'Jl. Lingkar Selatan',
                    'types': [
                      'convenience_store',
                      'store',
                      'point_of_interest',
                      'establishment',
                    ],
                    'geometry': {
                      'location': {'lat': -7.3300, 'lng': 110.5080},
                    },
                  },
                ],
              }),
              200,
            );
          }

          fail('Reverse geocode must not be used as a merchant result.');
        }),
      );

      final resolved = await service.findNearestEstablishment(
        const LatLng(-7.3178, 110.4630),
        preferredQuery: 'JAVANICA CAFE',
      );

      expect(resolved, isNull);
      expect(nearbyUrl?.queryParameters, isNot(contains('keyword')));
      expect(nearbyUrl?.queryParameters, isNot(contains('type')));
      expect(requestedPaths, ['/maps/api/place/nearbysearch/json']);
    },
  );
}
