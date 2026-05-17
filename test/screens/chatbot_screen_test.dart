import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_bangdeliv/models/chatbot_model.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';
import 'package:frontend_bangdeliv/providers/api_providers.dart';
import 'package:frontend_bangdeliv/providers/auth_session_provider.dart';
import 'package:frontend_bangdeliv/providers/chatbot_conversation_provider.dart';
import 'package:frontend_bangdeliv/screens/chatbot_screen.dart';
import 'package:frontend_bangdeliv/services/api_client.dart';
import 'package:frontend_bangdeliv/services/api_exception.dart';
import 'package:frontend_bangdeliv/services/chatbot_api_service.dart';

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

  for (final entry in const <String, String>{
    'nitip': 'Sebelum titip belanja',
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
    expect(find.text('Lacak Pesanan'), findsOneWidget);
    expect(find.textContaining('belum bisa digunakan'), findsNothing);
  });

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

  testWidgets('show small courier draft size line without fake numbers', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'kurir',
      chatbotApiService: _FakeChatbotApiService(),
    );

    await _sendMessage(tester, 'draft kacamata');

    expect(find.text('Berat/Ukuran'), findsOneWidget);
    expect(find.text('kecil/ringan untuk motor'), findsOneWidget);
    expect(find.textContaining('0 kg'), findsNothing);
  });
}

Future<GoRouter> _pumpChatbot(
  WidgetTester tester, {
  required String serviceType,
  required ChatbotApiService chatbotApiService,
  AuthSessionState? authSession,
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
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          () => _FakeAuthSessionNotifier(
            authSession ?? _buildAuthenticatedSession(),
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
    stats: UserStatsModel(totalOrders: 3, totalPaid: 100000, rating: 4.8),
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
    stats: UserStatsModel(totalOrders: 0, totalPaid: 0, rating: 0),
    addresses: <SavedAddressModel>[],
  );

  return AuthSessionState.fromProfile(profile);
}

class _FakeAuthSessionNotifier extends AuthSessionNotifier {
  _FakeAuthSessionNotifier(this._session);

  final AuthSessionState _session;

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
    state = _session;
  }
}

class _FakeChatbotApiService extends ChatbotApiService {
  _FakeChatbotApiService() : super(ApiClient());

  int callCount = 0;
  int patchLocationCallCount = 0;
  int patchLocationsCallCount = 0;
  String? lastServiceType;
  String? lastPatchTarget;
  List<String> lastRouteTargets = const <String>[];
  List<String?> lastRouteAddresses = const <String?>[];

  @override
  Future<List<ChatbotSessionSummary>> fetchSessions({
    String? serviceType,
    int limit = 20,
  }) async {
    return const <ChatbotSessionSummary>[];
  }

  @override
  Future<ChatbotHistoryPage> fetchSessionHistory(
    String sessionId, {
    int limit = 50,
    int? beforeId,
  }) async {
    return ChatbotHistoryPage(
      sessionId: sessionId,
      messages: const <ChatbotHistoryMessage>[],
      hasMore: false,
      nextBeforeId: null,
    );
  }

  @override
  Future<ChatbotResult> sendMessage(
    String message, {
    required String serviceType,
    String? sessionId,
  }) async {
    callCount += 1;
    lastServiceType = serviceType;

    final normalized = message.trim().toLowerCase();
    if (normalized == 'trigger error') {
      throw const ApiException('Chatbot timeout');
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
              'Ukuran/Berat: kecil/ringan untuk motor\n'
              'Status barang: Paket aman untuk layanan kurir motor.\n'
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
}
