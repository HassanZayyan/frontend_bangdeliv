import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'config/app_colors.dart';
import 'config/app_env.dart';
import 'config/app_theme.dart';
import 'config/app_router.dart';
import 'config/app_text_scaling.dart';
import 'features/realtime/application/app_realtime_bootstrap_provider.dart';
import 'features/auth/application/auth_session_provider.dart';
import 'features/driver_orders/application/driver_availability_location_reporter_provider.dart';
import 'features/realtime/application/chat_heads_up_notification_provider.dart';
import 'features/realtime/application/firebase_notification_provider.dart';
import 'services/firebase_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await FirebaseNotificationService.initializeFirebase();
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
    ref.watch(appRealtimeBootstrapProvider);
    ref.watch(firebaseNotificationBootstrapProvider);
    ref.watch(chatHeadsUpNotificationProvider);
    ref.watch(driverAvailabilityLocationReporterProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'BangDeliv',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) {
        return ColoredBox(
          color: AppColors.background,
          child: AppTextScaling.clamp(
            context: context,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
