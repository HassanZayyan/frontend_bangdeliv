import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend_bangdeliv/models/user_profile_model.dart';
import 'package:frontend_bangdeliv/providers/auth_session_provider.dart';
import 'package:frontend_bangdeliv/providers/api_providers.dart';
import 'package:frontend_bangdeliv/screens/chatbot_screen.dart';
import 'package:frontend_bangdeliv/services/api_client.dart';
import 'package:frontend_bangdeliv/services/ride_order_api_service.dart';

void main() {
  testWidgets('destination message shows confirm prompt', (
    WidgetTester tester,
  ) async {
    await _pumpRideChatbot(tester);

    await _sendMessage(tester, 'Antar ke Jalan Sudirman No 10');

    expect(find.textContaining('Ketik "Konfirmasi"'), findsOneWidget);
  });

  testWidgets('ubah tujuan resets destination draft', (
    WidgetTester tester,
  ) async {
    await _pumpRideChatbot(tester);

    await _sendMessage(tester, 'Antar ke Jalan Sudirman No 10');
    await _sendMessage(tester, 'ubah tujuan');

    expect(find.textContaining('tujuan sebelumnya saya reset'), findsOneWidget);
  });

  testWidgets(
    'after confirmation, non-destination input asks for new trip destination',
    (WidgetTester tester) async {
      await _pumpRideChatbot(tester);

      await _sendMessage(tester, 'Antar ke Jalan Sudirman No 10');
      await _sendMessage(tester, 'konfirmasi');
      await _sendMessage(tester, 'halo bangbot');

      expect(
        find.textContaining('Perjalanan sebelumnya sudah dikonfirmasi'),
        findsOneWidget,
      );
    },
  );
}

Future<void> _pumpRideChatbot(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/chatbot?service_type=antar_jemput',
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
        rideOrderApiServiceProvider.overrideWithValue(
          _FakeRideOrderApiService(),
        ),
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

class _FakeRideOrderApiService extends RideOrderApiService {
  _FakeRideOrderApiService() : super(ApiClient());

  @override
  Future<RideOrderSubmissionResult> createRideOrder({
    required int addressId,
    required String destinationAddress,
    String? notes,
  }) async {
    return const RideOrderSubmissionResult(
      orderId: 999,
      orderNumber: 'BDR-TEST-9999',
    );
  }
}
