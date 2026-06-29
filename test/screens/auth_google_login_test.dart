import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/auth/presentation/screens/complete_phone_screen.dart';
import 'package:frontend_bangdeliv/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:frontend_bangdeliv/features/auth/presentation/screens/login_screen.dart';
import 'package:frontend_bangdeliv/features/profile/presentation/screens/change_password_screen.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';

void main() {
  testWidgets('login exposes Google sign-in and manual signup link', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('Masuk dengan Google'), findsOneWidget);
    expect(find.text('Daftar Sekarang'), findsOneWidget);
  });

  testWidgets('login tagline stays centered when large text wraps', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(1.3),
            ),
            child: LoginScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    final taglineFinder = find.text(
      'Pesan kebutuhan dan perjalananmu dengan mudah',
    );
    expect(taglineFinder, findsOneWidget);

    final tagline = tester.widget<Text>(taglineFinder);
    expect(tagline.textAlign, TextAlign.center);
    expect(tagline.maxLines, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('complete phone validates required phone before submitting', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            () => _FakeAuthSessionNotifier(_googleSession()),
          ),
        ],
        child: const MaterialApp(home: CompletePhoneScreen()),
      ),
    );

    await tester.tap(find.text('Simpan Nomor'));
    await tester.pump();

    expect(find.text('Nomor WhatsApp wajib diisi'), findsOneWidget);
  });

  testWidgets('create password explains Google password is optional', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChangePasswordScreen(mode: PasswordFormMode.create),
      ),
    );

    expect(find.text('Login & Keamanan'), findsOneWidget);
    expect(find.text('Google sudah terhubung'), findsOneWidget);
    expect(
      find.textContaining('Password BangDeliv bersifat opsional'),
      findsOneWidget,
    );
    expect(find.text('Tambah Password'), findsOneWidget);
  });

  testWidgets('forgot password validates required reset fields', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));

    await tester.ensureVisible(find.text('Atur Ulang Password'));
    await tester.tap(find.text('Atur Ulang Password'));
    await tester.pump();

    expect(find.text('Email wajib diisi'), findsOneWidget);
    expect(find.text('Nomor WhatsApp wajib diisi'), findsOneWidget);
    expect(find.text('Password baru wajib diisi'), findsOneWidget);
    expect(find.text('Konfirmasi password wajib diisi'), findsOneWidget);
  });

  testWidgets('forgot password validates confirmation mismatch before submit', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));

    await tester.enterText(
      find.byKey(const ValueKey('forgot-password-email-field')),
      'user@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('forgot-password-phone-field')),
      '081234567890',
    );
    await tester.enterText(
      find.byKey(const ValueKey('forgot-password-new-password-field')),
      'passwordBaru123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('forgot-password-confirm-password-field')),
      'passwordBeda123',
    );

    await tester.ensureVisible(find.text('Atur Ulang Password'));
    await tester.tap(find.text('Atur Ulang Password'));
    await tester.pump();

    expect(find.text('Konfirmasi password tidak sama'), findsOneWidget);
  });
}

class _FakeAuthSessionNotifier extends AuthSessionNotifier {
  _FakeAuthSessionNotifier(this._initialState);

  final AuthSessionState _initialState;

  @override
  AuthSessionState build() => _initialState;
}

AuthSessionState _googleSession() {
  return AuthSessionState.fromProfile(
    const UserProfileModel(
      id: 7,
      name: 'Google User',
      phone: '',
      email: 'google.user@example.com',
      avatar: null,
      avatarUrl: null,
      role: 'customer',
      authProvider: 'google',
      hasPassword: false,
      requiresPhoneCompletion: true,
      driverProfile: null,
      stats: UserStatsModel(totalOrders: 0, totalPaid: 0),
      addresses: [],
    ),
  );
}
