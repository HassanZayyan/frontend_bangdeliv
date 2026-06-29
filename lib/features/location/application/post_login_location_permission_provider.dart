import 'package:flutter_riverpod/flutter_riverpod.dart';

final postLoginLocationPermissionRefreshProvider =
    NotifierProvider<PostLoginLocationPermissionRefreshNotifier, int>(
      PostLoginLocationPermissionRefreshNotifier.new,
    );

class PostLoginLocationPermissionRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void markGranted() {
    state += 1;
  }
}
