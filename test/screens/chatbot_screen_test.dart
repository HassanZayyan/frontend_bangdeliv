import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_bangdeliv/models/chatbot_model.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';
import 'package:frontend_bangdeliv/core/di/app_providers.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/chatbot/application/chatbot_conversation_provider.dart';
import 'package:frontend_bangdeliv/features/chatbot/presentation/screens/chatbot_screen.dart';
import 'package:frontend_bangdeliv/services/api_client.dart';
import 'package:frontend_bangdeliv/services/api_exception.dart';
import 'package:frontend_bangdeliv/services/chatbot_api_service.dart';
import 'package:frontend_bangdeliv/services/customer_order_api_service.dart';

void main() {
  testWidgets('antar_jemput now uses backend chatbot response', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeChatbotApiService();

    await _pumpChatbot(
      tester,
      serviceType: 'antar_jemput',
      chatbotApiService: fakeService,
    );

    await _sendMessage(tester, 'antar ke polines');

    expect(find.textContaining('Ketik "Konfirmasi"'), findsOneWidget);
    expect(fakeService.callCount, 1);
    expect(fakeService.lastServiceType, 'antar_jemput');
  });

  testWidgets('show address action when backend asks OPEN_ADDRESSES', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'antar_jemput',
      chatbotApiService: _FakeChatbotApiService(),
    );

    await _sendMessage(tester, 'butuh alamat profil');

    expect(find.text('Isi Alamat Saya'), findsOneWidget);
  });

  testWidgets('courier bootstrap shows one route picker action', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'kurir',
      chatbotApiService: _FakeChatbotApiService(),
    );

    expect(find.text('Atur Titik Ambil & Tujuan'), findsOneWidget);
    expect(find.text('Pilih Titik Ambil'), findsNothing);
    expect(find.text('Pilih Titik Tujuan'), findsNothing);
  });

  testWidgets('ride bootstrap shows one route picker action', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'antar_jemput',
      chatbotApiService: _FakeChatbotApiService(),
    );

    expect(find.text('Atur Titik Jemput & Tujuan'), findsOneWidget);
    expect(find.text('Pilih Titik Jemput'), findsNothing);
    expect(find.text('Pilih Titik Tujuan'), findsNothing);
  });

  testWidgets('nitip welcome shows concise multi merchant guidance', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: _FakeChatbotApiService(),
    );

    expect(find.textContaining('pilih merchant di map'), findsOneWidget);
    expect(find.textContaining('sampai 3 merchant'), findsOneWidget);
    expect(find.textContaining('Contoh: Beli di'), findsNothing);
    expect(
      find.widgetWithText(OutlinedButton, 'Pilih Merchant di Map'),
      findsOneWidget,
    );
  });

  testWidgets('chatbot input keyboard uses newline instead of keyboard send', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: _FakeChatbotApiService(),
    );

    final input = tester.widget<TextField>(find.byType(TextField));

    expect(input.keyboardType, TextInputType.multiline);
    expect(input.textInputAction, TextInputAction.newline);
    expect(input.onSubmitted, isNull);
  });

  testWidgets('chatbot app bar exposes reset action only', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'antar_jemput',
      chatbotApiService: _FakeChatbotApiService(),
    );

    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.text('Riwayat Sesi'), findsNothing);

    await tester.tap(find.byTooltip('Mulai ulang pesanan'));
    await _pumpChatbotFrame(tester);

    expect(find.text('Mulai ulang pesanan?'), findsOneWidget);
    expect(find.textContaining('Chat aktif'), findsOneWidget);
    expect(find.text('Pilih Sesi Chat'), findsNothing);
  });

  testWidgets('restart button confirms and starts a fresh chatbot session', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeChatbotApiService();

    await _pumpChatbot(
      tester,
      serviceType: 'antar_jemput',
      chatbotApiService: fakeService,
    );

    await _sendMessage(tester, 'antar ke polines');
    final oldSessionId = fakeService.lastSessionId;

    await tester.tap(find.byTooltip('Mulai ulang pesanan'));
    await _pumpChatbotFrame(tester);

    expect(find.text('Mulai ulang pesanan?'), findsOneWidget);

    await tester.tap(find.text('Mulai Ulang'));
    await _pumpChatbotFrame(tester);

    expect(fakeService.clearSessionCallCount, 1);
    expect(fakeService.lastClearedSessionId, oldSessionId);
    expect(fakeService.callCount, 1);
    expect(
      find.textContaining('Halo! Saya BangBot untuk layanan Antar Jemput'),
      findsOneWidget,
    );
    expect(find.textContaining('Draft siap'), findsNothing);
  });

  test('restart command parser only accepts explicit refresh commands', () {
    expect(ChatbotCommandParser.isRestartCommand('refresh'), isTrue);
    expect(ChatbotCommandParser.isRestartCommand('/refresh'), isTrue);
    expect(ChatbotCommandParser.isRestartCommand(' refresh '), isTrue);
    expect(ChatbotCommandParser.isRestartCommand('tolong refresh'), isFalse);
  });

  for (final serviceType in const <String>['antar_jemput', 'kurir', 'nitip']) {
    testWidgets('manual refresh command restarts $serviceType order flow', (
      WidgetTester tester,
    ) async {
      final fakeService = _FakeChatbotApiService();

      await _pumpChatbot(
        tester,
        serviceType: serviceType,
        chatbotApiService: fakeService,
      );

      await _sendMessage(tester, 'mulai draft');
      final oldSessionId = fakeService.lastSessionId;

      await _sendMessage(tester, 'refresh');

      expect(fakeService.clearSessionCallCount, 1);
      expect(fakeService.lastClearedSessionId, oldSessionId);
      expect(fakeService.callCount, 1);
      expect(find.textContaining('Halo! Saya BangBot'), findsOneWidget);
      expect(find.textContaining('Draft siap'), findsNothing);
    });
  }

  testWidgets(
    'nitip payment selection shows confirmation, not payment choices',
    (WidgetTester tester) async {
      await _pumpChatbot(
        tester,
        serviceType: 'nitip',
        chatbotApiService: _FakeChatbotApiService(),
      );

      await _sendMessage(tester, 'COD');

      expect(
        find.widgetWithText(OutlinedButton, 'Konfirmasi Nitip'),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'COD'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'QRIS'), findsNothing);
    },
  );

  testWidgets('nitip COD button clears old payment choices after one tap', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeChatbotApiService();
    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: fakeService,
    );

    await _sendMessage(tester, 'draft nitip payment');

    expect(find.widgetWithText(OutlinedButton, 'COD'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'QRIS'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'COD'));
    await _pumpChatbotFrame(tester);

    expect(fakeService.callCount, 2);
    expect(
      find.widgetWithText(OutlinedButton, 'Konfirmasi Nitip'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'COD'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'QRIS'), findsNothing);
  });

  testWidgets('nitip missing merchant shows merchant map picker action', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: _FakeChatbotApiService(),
    );

    await _sendMessage(tester, 'beli sembako');

    expect(
      find.widgetWithText(OutlinedButton, 'Pilih Merchant di Map'),
      findsOneWidget,
    );
  });

  testWidgets(
    'nitip ready first merchant offers add merchant with examples and mode add',
    (WidgetTester tester) async {
      final fakeService = _FakeChatbotApiService();
      await _pumpChatbot(
        tester,
        serviceType: 'nitip',
        chatbotApiService: fakeService,
      );

      await _sendMessage(tester, 'draft nitip merchant siap');

      expect(find.textContaining('Mau tambah merchant lain?'), findsOneWidget);
      expect(find.textContaining('- susu 1'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Tambah Merchant'),
        findsOneWidget,
      );
      expect(find.text('Beli ayam geprek'), findsNothing);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Tambah Merchant'));
      await _pumpChatbotFrame(tester);
      await tester.tap(find.text('Pilih Kedai Kedua'));
      await _pumpChatbotFrame(tester);

      expect(fakeService.patchMerchantCallCount, 1);
      expect(fakeService.lastMerchantMode, 'add');
      expect(find.textContaining('Kedai Kedua'), findsOneWidget);
      expect(find.textContaining('air mineral 1'), findsOneWidget);
    },
  );

  testWidgets('only latest chatbot action buttons stay enabled', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: _FakeChatbotApiService(),
    );

    await _sendMessage(tester, 'draft nitip payment');
    await _sendMessage(tester, 'COD');

    final oldCodButtons = find.widgetWithText(OutlinedButton, 'COD');
    expect(oldCodButtons, findsNothing);

    final confirmButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Konfirmasi Nitip'),
    );
    expect(confirmButton.onPressed, isNotNull);
  });

  testWidgets('back button from root chatbot falls back to home', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: _FakeChatbotApiService(),
    );

    await tester.tap(find.byIcon(Icons.chevron_left));
    await _pumpChatbotFrame(tester);

    expect(find.text('Home Screen'), findsOneWidget);
  });

  for (final entry in const <String, String>{
    'nitip': 'Sebelum pesan Nitip',
    'antar_jemput': 'Sebelum pesan Antar Jemput',
    'kurir': 'Sebelum pesan Kurir',
  }.entries) {
    testWidgets('${entry.key} without address opens Alamat Saya once', (
      WidgetTester tester,
    ) async {
      final fakeService = _FakeChatbotApiService();

      final router = await _pumpChatbot(
        tester,
        serviceType: entry.key,
        chatbotApiService: fakeService,
        authSession: _buildAuthenticatedSessionWithoutAddress(),
      );

      expect(find.text('Alamat Saya Screen'), findsOneWidget);

      router.pop();
      await _pumpChatbotFrame(tester);

      expect(find.textContaining(entry.value), findsOneWidget);
      expect(find.text('Isi Alamat Saya'), findsOneWidget);
      expect(find.text('Atur Titik Ambil & Tujuan'), findsNothing);
      expect(find.text('Atur Titik Jemput & Tujuan'), findsNothing);

      await _sendMessage(tester, 'coba mulai order');

      expect(fakeService.callCount, 0);
      expect(find.text('Alamat Saya Screen'), findsOneWidget);
    });
  }

  testWidgets('show api error message from chatbot service', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'kurir',
      chatbotApiService: _FakeChatbotApiService(),
    );

    await _sendMessage(tester, 'trigger error');

    expect(find.text('Chatbot timeout'), findsWidgets);
    expect(find.textContaining('belum bisa digunakan'), findsNothing);
  });

  testWidgets('show order created response after confirmation', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'antar_jemput',
      chatbotApiService: _FakeChatbotApiService(),
    );

    await _sendMessage(tester, 'Konfirmasi');

    expect(
      find.textContaining('order antar jemput berhasil dibuat'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Estimasi ongkir sementara: Rp 9.000.'),
      findsOneWidget,
    );
    expect(find.textContaining('Ongkir: Rp 9.000.'), findsNothing);
    expect(find.text('Lacak Pesanan'), findsOneWidget);
    expect(find.textContaining('belum bisa digunakan'), findsNothing);
  });

  testWidgets('track order action clears completed active session', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeChatbotApiService();

    await _pumpChatbot(
      tester,
      serviceType: 'antar_jemput',
      chatbotApiService: fakeService,
    );

    await _sendMessage(tester, 'Konfirmasi');
    await tester.tap(find.text('Lacak Pesanan'));
    await _pumpChatbotFrame(tester);

    expect(find.text('Track Screen 33'), findsOneWidget);
    expect(fakeService.clearSessionCallCount, 1);
    expect(fakeService.lastClearedSessionId, isNotEmpty);
  });

  testWidgets('back button clears completed active session', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeChatbotApiService();

    await _pumpChatbot(
      tester,
      serviceType: 'antar_jemput',
      chatbotApiService: fakeService,
    );

    await _sendMessage(tester, 'Konfirmasi');
    await tester.tap(find.byIcon(Icons.chevron_left));
    await _pumpChatbotFrame(tester);

    expect(find.text('Home Screen'), findsOneWidget);
    expect(fakeService.clearSessionCallCount, 1);
    expect(fakeService.lastClearedSessionId, isNotEmpty);
  });

  for (final entry in const <String, ({String message, String action})>{
    'kurir': (
      message: 'Alamat ambil kamu sudah tersimpan',
      action: 'Atur Titik Ambil & Tujuan',
    ),
    'nitip': (
      message: 'Alamat antar pesanan kamu sudah tersimpan',
      action: 'Pilih Titik Antar',
    ),
  }.entries) {
    testWidgets('${entry.key} shows address-ready message after address fill', (
      WidgetTester tester,
    ) async {
      final router = await _pumpChatbot(
        tester,
        serviceType: entry.key,
        chatbotApiService: _FakeChatbotApiService(),
        authSession: _buildAuthenticatedSessionWithoutAddress(),
        refreshedAuthSession: _buildAuthenticatedSession(),
      );

      expect(find.text('Alamat Saya Screen'), findsOneWidget);

      router.pop();
      await _pumpChatbotFrame(tester);

      expect(find.textContaining(entry.value.message), findsOneWidget);
      expect(find.text(entry.value.action), findsOneWidget);
      expect(find.text('Atur Titik Jemput & Tujuan'), findsNothing);
    });
  }

  testWidgets('show courier map picker action when backend asks for pin', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'kurir',
      chatbotApiService: _FakeChatbotApiService(),
    );

    await _sendMessage(tester, 'butuh map tujuan');

    expect(find.textContaining('belum pas di peta'), findsOneWidget);
    expect(find.text('Atur Titik Ambil & Tujuan'), findsWidgets);
    expect(find.text('Pilih Titik Tujuan di Map'), findsNothing);
  });

  test('initial courier map pin can patch backend session before chat', () async {
    final fakeService = _FakeChatbotApiService();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(
          () => _FakeAuthSessionNotifier(_buildAuthenticatedSession()),
        ),
        chatbotApiServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(chatbotConversationProvider.notifier);
    await notifier.bootstrap(
      serviceType: 'kurir',
      welcomeMessage:
          'Halo! Saya BangBot untuk layanan Kurir. Tulis lokasi ambil, tujuan kirim, isi paket, atau pilih titik langsung di map.',
    );

    await notifier.applyMapPinAction(
      serviceType: 'kurir',
      target: 'pickup',
      latitude: -7.3289,
      longitude: 110.5001,
      address: 'Pin -7.328900, 110.500100',
    );

    final state = container.read(chatbotConversationProvider);

    expect(fakeService.patchLocationCallCount, 1);
    expect(fakeService.lastPatchTarget, 'pickup');
    expect(state.messages.last.text, contains('Draft map pin diterima'));
    expect(state.errorMessage, isNull);
  });

  test('route picker action sends one bulk patch request', () async {
    final fakeService = _FakeChatbotApiService();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(
          () => _FakeAuthSessionNotifier(_buildAuthenticatedSession()),
        ),
        chatbotApiServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(chatbotConversationProvider.notifier);
    await notifier.bootstrap(
      serviceType: 'kurir',
      welcomeMessage: 'Halo kurir',
    );

    await notifier.applyRoutePickerAction(
      serviceType: 'kurir',
      locations: const <ChatbotLocationPatch>[
        ChatbotLocationPatch(
          target: 'dropoff',
          latitude: -7.3312,
          longitude: 110.5077,
          address: 'Lapangan Pancasila Salatiga',
        ),
      ],
    );

    final state = container.read(chatbotConversationProvider);

    expect(fakeService.patchLocationsCallCount, 1);
    expect(fakeService.patchLocationCallCount, 0);
    expect(fakeService.lastRouteTargets, ['dropoff']);
    expect(state.messages.last.text, contains('Draft rute diterima'));
  });

  test('route picker action can let backend resolve missing address', () async {
    final fakeService = _FakeChatbotApiService();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(
          () => _FakeAuthSessionNotifier(_buildAuthenticatedSession()),
        ),
        chatbotApiServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(chatbotConversationProvider.notifier);
    await notifier.bootstrap(
      serviceType: 'antar_jemput',
      welcomeMessage: 'Halo ride',
    );

    await notifier.applyRoutePickerAction(
      serviceType: 'antar_jemput',
      locations: const <ChatbotLocationPatch>[
        ChatbotLocationPatch(
          target: 'destination',
          latitude: -7.3312,
          longitude: 110.5077,
        ),
      ],
    );

    expect(fakeService.patchLocationsCallCount, 1);
    expect(fakeService.lastRouteTargets, ['destination']);
    expect(fakeService.lastRouteAddresses, [null]);
  });

  testWidgets('courier draft does not show size, weight, or policy warning', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'kurir',
      chatbotApiService: _FakeChatbotApiService(),
    );

    await _sendMessage(tester, 'draft kacamata');

    expect(find.text('Berat/Ukuran'), findsNothing);
    expect(find.text('Status Barang'), findsNothing);
    expect(find.text('kecil/ringan untuk motor'), findsNothing);
    expect(find.textContaining('Paket aman'), findsNothing);
    expect(find.textContaining('0 kg'), findsNothing);
  });

  test('customer transfer evidence picker uses gallery', () {
    final source = File(
      'lib/features/tracking/presentation/screens/track_order_screen.dart',
    ).readAsStringSync();
    final uploadMethod = source.substring(
      source.indexOf('Future<void> _uploadTransferEvidence'),
      source.indexOf('if (photo == null)'),
    );

    expect(uploadMethod, contains('source: ImageSource.gallery'));
    expect(uploadMethod, isNot(contains('source: ImageSource.camera')));
  });
}

Future<GoRouter> _pumpChatbot(
  WidgetTester tester, {
  required String serviceType,
  required ChatbotApiService chatbotApiService,
  AuthSessionState? authSession,
  AuthSessionState? refreshedAuthSession,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});

  final router = GoRouter(
    initialLocation: '/chatbot?service_type=$serviceType',
    routes: <RouteBase>[
      GoRoute(
        path: '/chatbot',
        builder: (BuildContext context, GoRouterState state) {
          return const ChatbotScreen();
        },
      ),
      GoRoute(
        path: '/addresses',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(
            body: Center(child: Text('Alamat Saya Screen')),
          );
        },
      ),
      GoRoute(
        path: '/home',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Center(child: Text('Home Screen')));
        },
      ),
      GoRoute(
        path: '/track',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: Center(child: Text('Track Screen ${state.extra}')),
          );
        },
      ),
      GoRoute(
        path: '/chatbot/shopping/merchant-map-picker',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  context.pop(
                    const ShoppingMerchantPlacePayload(
                      placeId: 'google-place-kedai-kedua',
                      name: 'Kedai Kedua',
                      address: 'Jl. Kedai Kedua',
                      latitude: -7.05,
                      longitude: 110.43,
                      types: <String>['restaurant'],
                    ),
                  );
                },
                child: const Text('Pilih Kedai Kedua'),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/activity',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Center(child: Text('Activity Screen')));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          () => _FakeAuthSessionNotifier(
            authSession ?? _buildAuthenticatedSession(),
            refreshedSession: refreshedAuthSession,
          ),
        ),
        chatbotApiServiceProvider.overrideWithValue(chatbotApiService),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  await _pumpChatbotFrame(tester);

  return router;
}

Future<void> _sendMessage(WidgetTester tester, String message) async {
  await tester.enterText(find.byType(TextField), message);
  await tester.tap(find.byIcon(Icons.send));
  await _pumpChatbotFrame(tester);
}

Future<void> _pumpChatbotFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

AuthSessionState _buildAuthenticatedSession() {
  const profile = UserProfileModel(
    id: 1,
    name: 'Hassan',
    phone: '081234567890',
    email: 'hassan@example.com',
    avatar: null,
    avatarUrl: null,
    role: 'customer',
    driverProfile: null,
    stats: UserStatsModel(totalOrders: 3, totalPaid: 100000),
    addresses: <SavedAddressModel>[
      SavedAddressModel(
        id: 11,
        label: 'Rumah',
        recipientName: 'Hassan',
        phone: '081234567890',
        fullAddress: 'Jalan Mawar No 1',
        detail: 'RT 01 RW 02',
        latitude: -7.0509,
        longitude: 110.4315,
        isDefault: true,
      ),
    ],
  );

  return AuthSessionState.fromProfile(profile);
}

AuthSessionState _buildAuthenticatedSessionWithoutAddress() {
  const profile = UserProfileModel(
    id: 2,
    name: 'Hassan',
    phone: '081234567890',
    email: 'hassan.noaddress@example.com',
    avatar: null,
    avatarUrl: null,
    role: 'customer',
    driverProfile: null,
    stats: UserStatsModel(totalOrders: 0, totalPaid: 0),
    addresses: <SavedAddressModel>[],
  );

  return AuthSessionState.fromProfile(profile);
}

class _FakeAuthSessionNotifier extends AuthSessionNotifier {
  _FakeAuthSessionNotifier(this._session, {AuthSessionState? refreshedSession})
    : _refreshedSession = refreshedSession;

  final AuthSessionState _session;
  final AuthSessionState? _refreshedSession;

  @override
  AuthSessionState build() => _session;

  @override
  Future<void> initialize() async {
    state = _session;
  }

  @override
  Future<void> handleLoginSuccess() async {
    state = _session;
  }

  @override
  Future<void> refreshSession() async {
    state = _refreshedSession ?? _session;
  }
}

class _FakeChatbotApiService extends ChatbotApiService {
  _FakeChatbotApiService() : super(ApiClient());

  int callCount = 0;
  int patchLocationCallCount = 0;
  int patchLocationsCallCount = 0;
  int patchMerchantCallCount = 0;
  int clearSessionCallCount = 0;
  String? lastServiceType;
  String? lastSessionId;
  String? lastPatchTarget;
  String? lastMerchantMode;
  String? lastClearedSessionId;
  List<String> lastRouteTargets = const <String>[];
  List<String?> lastRouteAddresses = const <String?>[];

  @override
  Future<void> clearSession(String sessionId) async {
    clearSessionCallCount += 1;
    lastClearedSessionId = sessionId;
  }

  @override
  Future<ChatbotResult> sendMessage(
    String message, {
    required String serviceType,
    String? sessionId,
  }) async {
    callCount += 1;
    lastServiceType = serviceType;
    lastSessionId = sessionId;

    final normalized = message.trim().toLowerCase();
    if (normalized == 'trigger error') {
      throw const ApiException('Chatbot timeout');
    }

    if (serviceType == 'nitip' && normalized == 'draft nitip payment') {
      return ChatbotResult.fromApiJson({
        'status': 'success',
        'session_id': sessionId,
        'service_context': {'service_type': serviceType},
        'model_used': 'gemini-3.1-flash-lite',
        'data': {
          'intent': 'shopping_order',
          'assistant_text':
              'Baik Hassan, saya sudah siapkan draft Nitip. Pilih metode pembayaran.',
          'shopping': {
            'ready_to_confirm': true,
            'payment_method': null,
            'merchant': {'name': 'Alfamart BangDeliv Point'},
            'delivery': {'address': 'FISIP UNDIP'},
            'items': [
              {'name': 'kopi', 'quantity': 1, 'unit_price': 0},
            ],
          },
          'validation': {
            'is_valid_order': true,
            'rejection_reasons': [],
            'missing_fields': [],
            'next_actions': ['SET_PAYMENT_COD', 'SET_PAYMENT_TRANSFER'],
          },
          'action_payloads': {
            'SET_PAYMENT_COD': {'label': 'COD', 'message': 'COD'},
            'SET_PAYMENT_TRANSFER': {'label': 'QRIS', 'message': 'QRIS'},
          },
          'order': {'created': false, 'payment_method': null},
        },
      });
    }

    if (serviceType == 'nitip' && normalized == 'draft nitip merchant siap') {
      return ChatbotResult.fromApiJson({
        'status': 'success',
        'session_id': sessionId,
        'service_context': {'service_type': serviceType},
        'model_used': 'gemini-3.1-flash-lite',
        'data': {
          'intent': 'shopping_order',
          'assistant_text':
              'Draft Nitip merchant pertama sudah aman.\n\n'
              'Merchant\n'
              'Kedai Tinari\n\n'
              'Daftar belanja\n'
              '1. 1x ramen mala (harga menyusul dari nota)\n'
              '2. 1x es jeruk (harga menyusul dari nota)\n\n'
              'Alamat antar\n'
              'FISIP UNDIP\n\n'
              'Estimasi ongkir sementara: Rp 9.000\n'
              'Estimasi total sementara: Rp 9.000\n'
              'Metode pembayaran: pilih COD atau QRIS.\n\n'
              'Mau tambah merchant lain? Pilih merchantnya dulu.\n'
              'Contoh setelah merchant berikutnya dipilih:\n'
              '- susu 1\n'
              '- roti tawar 2\n\n'
              'Ketik "konfirmasi" kalau sudah oke.',
          'shopping': {
            'ready_to_confirm': true,
            'payment_method': null,
            'merchant': {'name': 'Kedai Tinari'},
            'delivery': {'address': 'FISIP UNDIP'},
            'items': [
              {'name': 'ramen mala', 'quantity': 1, 'unit_price': 0},
              {'name': 'es jeruk', 'quantity': 1, 'unit_price': 0},
            ],
            'stops': [
              {
                'index': 1,
                'is_active': true,
                'ready': true,
                'merchant': {'name': 'Kedai Tinari'},
                'items': [
                  {'name': 'ramen mala', 'quantity': 1, 'unit_price': 0},
                  {'name': 'es jeruk', 'quantity': 1, 'unit_price': 0},
                ],
              },
            ],
          },
          'validation': {
            'is_valid_order': true,
            'rejection_reasons': [],
            'missing_fields': [],
            'next_actions': [
              'OPEN_ADD_MERCHANT_PICKER',
              'OPEN_MAP_PICKER_DELIVERY',
              'SET_PAYMENT_COD',
              'SET_PAYMENT_TRANSFER',
            ],
          },
          'action_payloads': {
            'OPEN_ADD_MERCHANT_PICKER': {
              'label': 'Tambah Merchant',
              'mode': 'add',
              'initial_latitude': -7.0509,
              'initial_longitude': 110.4315,
            },
            'OPEN_MAP_PICKER_DELIVERY': {
              'target': 'delivery',
              'label': 'Ganti Titik Antar',
            },
            'SET_PAYMENT_COD': {'label': 'COD', 'message': 'COD'},
            'SET_PAYMENT_TRANSFER': {'label': 'QRIS', 'message': 'QRIS'},
          },
          'order': {'created': false, 'payment_method': null},
        },
      });
    }

    if (serviceType == 'nitip' && normalized == 'beli sembako') {
      return ChatbotResult.fromApiJson({
        'status': 'success',
        'session_id': sessionId,
        'service_context': {'service_type': serviceType},
        'model_used': 'gemini-3.1-flash-lite',
        'data': {
          'intent': 'shopping_order',
          'assistant_text': 'Draft Nitip belum lengkap. Lengkapi: merchant.',
          'shopping': {
            'ready_to_confirm': false,
            'payment_method': null,
            'merchant': {'id': null, 'name': null},
            'delivery': {'address': 'FISIP UNDIP'},
            'items': [
              {'name': 'sembako', 'quantity': 1, 'unit_price': 0},
            ],
          },
          'validation': {
            'is_valid_order': false,
            'rejection_reasons': ['Merchant/toko belum dipilih.'],
            'missing_fields': ['merchant'],
            'next_actions': ['OPEN_MERCHANT_PICKER'],
          },
          'action_payloads': {
            'OPEN_MERCHANT_PICKER': {
              'label': 'Pilih Merchant di Map',
              'initial_latitude': -7.0509,
              'initial_longitude': 110.4315,
            },
          },
          'order': {'created': false, 'payment_method': null},
        },
      });
    }

    if (serviceType == 'nitip' && normalized == 'cod') {
      return ChatbotResult.fromApiJson({
        'status': 'success',
        'session_id': sessionId,
        'service_context': {'service_type': serviceType},
        'model_used': 'gemini-3.1-flash-lite',
        'data': {
          'intent': 'shopping_order',
          'assistant_text':
              'Baik, metode pembayaran COD sudah dipilih. Ketik "Konfirmasi" kalau sudah oke.',
          'shopping': {
            'ready_to_confirm': true,
            'payment_method': 'COD',
            'merchant': {'name': 'Alfamart BangDeliv Point'},
            'delivery': {'address': 'FISIP UNDIP'},
            'items': [
              {'name': 'kopi', 'quantity': 1, 'unit_price': 0},
            ],
          },
          'validation': {
            'is_valid_order': true,
            'rejection_reasons': [],
            'missing_fields': [],
            'next_actions': ['SET_PAYMENT_COD', 'SET_PAYMENT_TRANSFER'],
          },
          'action_payloads': {
            'SET_PAYMENT_COD': {'label': 'COD', 'message': 'COD'},
            'SET_PAYMENT_TRANSFER': {'label': 'QRIS', 'message': 'QRIS'},
          },
          'order': {'created': false, 'payment_method': 'COD'},
        },
      });
    }

    if (normalized == 'konfirmasi') {
      return ChatbotResult.fromApiJson({
        'status': 'success',
        'session_id': sessionId,
        'service_context': {'service_type': serviceType},
        'model_used': 'deterministic-command',
        'data': {
          'intent': serviceType == 'antar_jemput'
              ? 'ride_order'
              : 'courier_order',
          'assistant_text':
              'Siap, order antar jemput berhasil dibuat.\n'
              'Nomor order: BD-20260511-0001\n'
              'Ongkir: Rp 9.000.',
          'validation': {
            'is_valid_order': true,
            'rejection_reasons': [],
            'missing_fields': [],
            'next_actions': [],
          },
          'order': {
            'created': true,
            'id': 33,
            'order_number': 'BD-20260511-0001',
            'status': 'PENDING',
          },
        },
      });
    }

    if (normalized.contains('alamat')) {
      return ChatbotResult.fromApiJson({
        'status': 'success',
        'model_used': 'gemini-2.5-flash',
        'data': {
          'intent': serviceType == 'antar_jemput'
              ? 'ride_order'
              : 'courier_order',
          'assistant_text':
              'Alamat jemput di profil belum tersedia. Silakan isi Alamat Saya.',
          'validation': {
            'is_valid_order': false,
            'rejection_reasons': ['Lokasi jemput di profil belum tersedia.'],
            'missing_fields': ['pickup_address'],
            'next_actions': ['OPEN_ADDRESSES'],
          },
          'order': {'created': false},
        },
      });
    }

    if (normalized.contains('map')) {
      return ChatbotResult.fromApiJson({
        'status': 'success',
        'model_used': 'gemini-2.5-flash',
        'data': {
          'intent': 'courier_order',
          'assistant_text':
              'Alamat tujuan "Erha Setiabudi Tembalang" belum pas di peta. Pilih titiknya langsung di map.',
          'validation': {
            'is_valid_order': false,
            'rejection_reasons': [
              'Alamat tujuan belum pas di peta. Pilih titiknya langsung di map.',
            ],
            'missing_fields': ['dropoff_address'],
            'next_actions': ['OPEN_MAP_PICKER_DROPOFF'],
          },
          'action_payloads': {
            'OPEN_MAP_PICKER_DROPOFF': {
              'target': 'dropoff',
              'label': 'Pilih Titik Tujuan di Map',
            },
          },
          'order': {'created': false},
        },
      });
    }

    if (normalized.contains('kacamata')) {
      return ChatbotResult.fromApiJson({
        'status': 'success',
        'model_used': 'gemini-2.5-flash',
        'data': {
          'intent': 'courier_order',
          'assistant_text':
              'Baik Hassan, saya sudah siapkan draft pengiriman Kurir.\n'
              'Ambil: Jalan Mawar No 1\n'
              'Tujuan: Erha Setiabudi Tembalang\n'
              'Barang: kacamata\n'
              'Estimasi ongkir sementara: Rp 8.000 (kalkulasi detail menyusul).\n'
              'Ketik "Konfirmasi" untuk lanjut. Pembayaran dilakukan tunai saat driver tiba dan mengecek barang di titik ambil.',
          'validation': {
            'is_valid_order': true,
            'rejection_reasons': [],
            'missing_fields': [],
            'next_actions': ['CONFIRM_DRAFT'],
          },
          'order': {'created': false, 'delivery_fee': 8000},
        },
      });
    }

    return ChatbotResult.fromApiJson({
      'status': 'success',
      'model_used': 'gemini-2.5-flash',
      'data': {
        'intent': serviceType == 'antar_jemput'
            ? 'ride_order'
            : 'courier_order',
        'assistant_text':
            'Draft siap. Ketik "Konfirmasi" untuk lanjut atau "Ubah Tujuan".',
        'validation': {
          'is_valid_order': true,
          'rejection_reasons': [],
          'missing_fields': [],
          'next_actions': [],
        },
        'order': {'created': false},
      },
    });
  }

  @override
  Future<ChatbotResult> patchSessionLocation(
    String sessionId, {
    required String serviceType,
    required String target,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    patchLocationCallCount += 1;
    lastServiceType = serviceType;
    lastPatchTarget = target;

    return ChatbotResult.fromApiJson({
      'status': 'success',
      'session_id': sessionId,
      'service_context': {'service_type': serviceType},
      'model_used': 'map-pin-action',
      'data': {
        'intent': serviceType == 'antar_jemput'
            ? 'ride_order'
            : 'courier_order',
        'assistant_text':
            'Draft map pin diterima. Lengkapi data lain agar siap dikonfirmasi.',
        'validation': {
          'is_valid_order': false,
          'rejection_reasons': [],
          'missing_fields': serviceType == 'kurir'
              ? ['dropoff_address', 'package_description']
              : ['destination_address'],
          'next_actions': serviceType == 'kurir'
              ? ['OPEN_MAP_PICKER_DROPOFF']
              : ['OPEN_MAP_PICKER_DESTINATION'],
        },
        'action_payloads': serviceType == 'kurir'
            ? {
                'OPEN_MAP_PICKER_DROPOFF': {
                  'target': 'dropoff',
                  'label': 'Pilih Titik Tujuan',
                },
              }
            : {
                'OPEN_MAP_PICKER_DESTINATION': {
                  'target': 'destination',
                  'label': 'Pilih Titik Tujuan',
                },
              },
        'order': {'created': false},
      },
    });
  }

  @override
  Future<ChatbotResult> patchSessionLocations(
    String sessionId, {
    required String serviceType,
    required List<ChatbotLocationPatchRequest> locations,
  }) async {
    patchLocationsCallCount += 1;
    lastServiceType = serviceType;
    lastRouteTargets = locations.map((location) => location.target).toList();
    lastRouteAddresses = locations.map((location) => location.address).toList();

    return ChatbotResult.fromApiJson({
      'status': 'success',
      'session_id': sessionId,
      'service_context': {'service_type': serviceType},
      'model_used': 'map-route-action',
      'data': {
        'intent': serviceType == 'antar_jemput'
            ? 'ride_order'
            : 'courier_order',
        'assistant_text': 'Draft rute diterima.',
        'validation': {
          'is_valid_order': false,
          'rejection_reasons': [],
          'missing_fields': serviceType == 'kurir'
              ? ['package_description']
              : ['destination_address'],
          'next_actions': [],
        },
        'order': {'created': false},
      },
    });
  }

  @override
  Future<ChatbotResult> patchSessionMerchant(
    String sessionId, {
    required String serviceType,
    int? merchantId,
    ShoppingMerchantPlacePayload? merchantPlace,
    String mode = 'select',
  }) async {
    patchMerchantCallCount += 1;
    lastServiceType = serviceType;
    lastMerchantMode = mode;

    return ChatbotResult.fromApiJson({
      'status': 'success',
      'session_id': sessionId,
      'service_context': {'service_type': serviceType},
      'model_used': 'merchant-picker-action',
      'data': {
        'intent': 'shopping_order',
        'assistant_text': mode == 'add'
            ? 'Draft Nitip belum lengkap. Lengkapi: items.\n\nMerchant\nKedai Kedua\n\nTulis item dan jumlah untuk merchant ini.\nContoh:\n- susu 1\n- roti tawar 2\n- air mineral 1'
            : 'Merchant Nitip berhasil dipilih.',
        'validation': {
          'is_valid_order': false,
          'rejection_reasons': [],
          'missing_fields': ['items'],
          'next_actions': [],
        },
        'order': {'created': false},
      },
    });
  }
}
