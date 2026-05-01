import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend_bangdeliv/models/chatbot_model.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';
import 'package:frontend_bangdeliv/providers/api_providers.dart';
import 'package:frontend_bangdeliv/providers/auth_session_provider.dart';
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

  testWidgets('show api error message from chatbot service', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'kurir',
      chatbotApiService: _FakeChatbotApiService(),
    );

    await _sendMessage(tester, 'trigger error');

    expect(find.textContaining('terjadi kendala'), findsOneWidget);
  });
}

Future<void> _pumpChatbot(
  WidgetTester tester, {
  required String serviceType,
  required ChatbotApiService chatbotApiService,
}) async {
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
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          () => _FakeAuthSessionNotifier(_buildAuthenticatedSession()),
        ),
        chatbotApiServiceProvider.overrideWithValue(chatbotApiService),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _sendMessage(WidgetTester tester, String message) async {
  await tester.enterText(find.byType(TextField), message);
  await tester.tap(find.byIcon(Icons.send));
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
        isDefault: true,
      ),
    ],
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
  String? lastServiceType;

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
}
