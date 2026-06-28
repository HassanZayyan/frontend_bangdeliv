import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appLifecycleStateProvider =
    NotifierProvider<AppLifecycleStateNotifier, AppLifecycleState>(
      AppLifecycleStateNotifier.new,
    );

class AppLifecycleStateNotifier extends Notifier<AppLifecycleState> {
  @override
  AppLifecycleState build() {
    return AppLifecycleState.resumed;
  }

  void setState(AppLifecycleState next) {
    state = next;
  }
}

bool isAppLifecycleResumed(AppLifecycleState state) {
  return state == AppLifecycleState.resumed;
}
