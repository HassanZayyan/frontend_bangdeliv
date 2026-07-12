import 'package:url_launcher/url_launcher.dart';

typedef ExternalNavigationUrlLauncher =
    Future<bool> Function(Uri uri, LaunchMode mode);

Uri buildGoogleMapsNavigationAppUri({
  required double latitude,
  required double longitude,
}) {
  return Uri.https('www.google.com', '/maps/dir/', <String, String>{
    'api': '1',
    'destination': '$latitude,$longitude',
    'travelmode': 'two-wheeler',
    'dir_action': 'navigate',
  });
}

Uri buildGoogleMapsNavigationWebUri({
  required double latitude,
  required double longitude,
}) {
  return Uri.https('www.google.com', '/maps/dir/', <String, String>{
    'api': '1',
    'destination': '$latitude,$longitude',
    'travelmode': 'two-wheeler',
  });
}

Future<bool> launchGoogleMapsNavigation({
  required double latitude,
  required double longitude,
  ExternalNavigationUrlLauncher launcher = _launchExternalUrl,
}) async {
  final appUri = buildGoogleMapsNavigationAppUri(
    latitude: latitude,
    longitude: longitude,
  );
  try {
    if (await launcher(appUri, LaunchMode.externalApplication)) {
      return true;
    }
  } catch (_) {
    // Continue to the universal web URL when the app URI is unsupported.
  }

  final webUri = buildGoogleMapsNavigationWebUri(
    latitude: latitude,
    longitude: longitude,
  );
  try {
    return await launcher(webUri, LaunchMode.platformDefault);
  } catch (_) {
    return false;
  }
}

Future<bool> _launchExternalUrl(Uri uri, LaunchMode mode) {
  return launchUrl(uri, mode: mode);
}
