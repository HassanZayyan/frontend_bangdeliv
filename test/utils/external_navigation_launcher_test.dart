import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/utils/external_navigation_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  test('builds Google navigation and universal fallback URIs', () {
    final appUri = buildGoogleMapsNavigationAppUri(
      latitude: -7.31,
      longitude: 110.49,
    );
    expect(appUri.scheme, 'https');
    expect(appUri.host, 'www.google.com');
    expect(appUri.queryParameters['destination'], '-7.31,110.49');
    expect(appUri.queryParameters['travelmode'], 'two-wheeler');
    expect(appUri.queryParameters['dir_action'], 'navigate');

    final webUri = buildGoogleMapsNavigationWebUri(
      latitude: -7.31,
      longitude: 110.49,
    );
    expect(webUri.host, 'www.google.com');
    expect(webUri.queryParameters['api'], '1');
    expect(webUri.queryParameters['destination'], '-7.31,110.49');
    expect(webUri.queryParameters['travelmode'], 'two-wheeler');
    expect(webUri.queryParameters.containsKey('dir_action'), isFalse);
  });

  test('falls back to web URL when Google Maps app URI fails', () async {
    final calls = <Uri>[];

    final opened = await launchGoogleMapsNavigation(
      latitude: -7.31,
      longitude: 110.49,
      launcher: (uri, mode) async {
        calls.add(uri);
        expect(
          mode,
          calls.length == 1
              ? LaunchMode.externalApplication
              : LaunchMode.platformDefault,
        );
        return calls.length == 2;
      },
    );

    expect(opened, isTrue);
    expect(calls, hasLength(2));
    expect(calls.first.queryParameters['dir_action'], 'navigate');
    expect(calls.last.host, 'www.google.com');
    expect(calls.last.queryParameters['travelmode'], 'two-wheeler');
  });

  test('returns false when both launch attempts throw or fail', () async {
    var attempts = 0;
    final opened = await launchGoogleMapsNavigation(
      latitude: -7.31,
      longitude: 110.49,
      launcher: (uri, mode) async {
        attempts++;
        if (attempts == 1) {
          throw StateError('app missing');
        }
        return false;
      },
    );

    expect(opened, isFalse);
    expect(attempts, 2);
  });
}
