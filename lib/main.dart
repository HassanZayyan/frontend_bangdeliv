import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/app_env.dart';
import 'config/app_theme.dart';
import 'config/app_router.dart';
import 'providers/auth_session_provider.dart';

void main() {
  AppEnv.logDebugSummary();

  runApp(
    // Membungkus aplikasi dengan ProviderScope untuk Riverpod
    const ProviderScope(child: MyApp()),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(authSessionProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'BangDeliv',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
