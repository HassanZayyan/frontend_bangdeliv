import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

final currentUserLocationProvider =
    NotifierProvider<CurrentUserLocationNotifier, LatLng?>(
      CurrentUserLocationNotifier.new,
    );

class CurrentUserLocationNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;

  void setLocation(LatLng location) {
    final current = state;
    if (current != null &&
        current.latitude == location.latitude &&
        current.longitude == location.longitude) {
      return;
    }

    state = location;
  }

  void clear() {
    if (state == null) {
      return;
    }

    state = null;
  }
}
