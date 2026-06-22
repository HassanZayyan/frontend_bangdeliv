import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_bangdeliv/models/chatbot_model.dart';
import 'package:frontend_bangdeliv/models/chatbot_launch_args.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';
import 'package:frontend_bangdeliv/core/di/app_providers.dart';
import 'package:frontend_bangdeliv/data/repositories/customer_order_repository.dart';
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

    expect(find.textContaining('Draft siap.'), findsOneWidget);
    expect(find.textContaining('Ketik "Konfirmasi"'), findsNothing);
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

  testWidgets('ride reset destination shows focused destination action', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'antar_jemput',
      chatbotApiService: _FakeChatbotApiService(),
    );

    await _sendMessage(tester, 'reset tujuan button');

    expect(
      find.textContaining('tujuan sebelumnya sudah saya reset'),
      findsOneWidget,
    );
    expect(find.textContaining('klik tombol'), findsNothing);
    expect(find.text('Tujuan baru'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Pilih Tujuan Baru'),
      findsOneWidget,
    );
    expect(find.text('Atur Titik Jemput & Tujuan'), findsNothing);
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

  testWidgets('chatbot app bar menu only shows restart action', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'antar_jemput',
      chatbotApiService: _FakeChatbotApiService(),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await _pumpChatbotFrame(tester);

    expect(find.text('Riwayat Sesi'), findsNothing);
    expect(find.text('Mulai ulang pesanan?'), findsNothing);
    expect(find.text('Mulai Ulang'), findsNothing);
    expect(find.text('Mulai Ulang Pesanan'), findsOneWidget);
    expect(find.text('Pilih Sesi Chat'), findsNothing);
  });

  testWidgets('restart menu starts a fresh chatbot session', (
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

    await tester.tap(find.byIcon(Icons.more_vert));
    await _pumpChatbotFrame(tester);

    expect(find.text('Mulai ulang pesanan?'), findsNothing);

    await tester.tap(find.text('Mulai Ulang Pesanan'));
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

  for (final entry
      in const <String, ({String draftMessage, String confirmLabel})>{
        'antar_jemput': (
          draftMessage: 'draft transport payment',
          confirmLabel: 'Konfirmasi',
        ),
        'kurir': (
          draftMessage: 'draft transport payment',
          confirmLabel: 'Konfirmasi',
        ),
        'nitip': (
          draftMessage: 'draft nitip payment',
          confirmLabel: 'Konfirmasi Nitip',
        ),
      }.entries) {
    testWidgets('${entry.key} QRIS button advances to confirmation', (
      WidgetTester tester,
    ) async {
      final fakeService = _FakeChatbotApiService();
      await _pumpChatbot(
        tester,
        serviceType: entry.key,
        chatbotApiService: fakeService,
      );

      await _sendMessage(tester, entry.value.draftMessage);

      expect(find.widgetWithText(OutlinedButton, 'COD'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'QRIS'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'QRIS'));
      await _pumpChatbotFrame(tester);

      expect(fakeService.lastMessage, 'QRIS');
      expect(
        find.widgetWithText(OutlinedButton, entry.value.confirmLabel),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'COD'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'QRIS'), findsNothing);
    });
  }

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

  testWidgets('nitip launch args select merchant and show menu selector', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeChatbotApiService();

    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: fakeService,
      launchArgs: const ChatbotLaunchArgs(
        serviceType: 'nitip',
        merchantId: 42,
        merchantName: 'Bakso Balungan',
        menuSuggestions: <ChatbotMenuSuggestion>[
          ChatbotMenuSuggestion(
            name: 'Bakso Urat',
            presetMessage: 'Bakso Urat 1',
            priceLabel: 'Rp 12.000',
          ),
        ],
      ),
    );

    expect(fakeService.patchMerchantCallCount, 1);
    expect(fakeService.lastMerchantId, 42);
    expect(find.textContaining('Draft Nitip belum lengkap'), findsNothing);
    expect(
      find.textContaining('Merchant Nitip berhasil dipilih'),
      findsNothing,
    );
    expect(find.text('Pilih menu'), findsOneWidget);
    expect(find.text('Bakso Balungan'), findsOneWidget);
    expect(find.text('Bakso Urat'), findsOneWidget);
    expect(find.text('Rp 12.000'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Bakso Urat - Rp 12.000'),
      findsNothing,
    );

    final disabledConfirm = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Konfirmasi'),
    );
    expect(disabledConfirm.onPressed, isNull);

    await tester.tap(find.byTooltip('Tambah Bakso Urat'));
    await _pumpChatbotFrame(tester);

    final enabledConfirm = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Konfirmasi'),
    );
    expect(enabledConfirm.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Konfirmasi'));
    await _pumpChatbotFrame(tester);

    expect(fakeService.lastMessage, 'Bakso Urat 1');
    expect(find.text('Pilih menu'), findsNothing);
  });

  testWidgets('nitip official merchant picker fetches menu selector', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeChatbotApiService();
    final fakeRepository = _FakeCustomerOrderRepository(
      menusByMerchantId: const <int, List<ShoppingMenuOption>>{
        42: <ShoppingMenuOption>[
          ShoppingMenuOption(id: 9, name: 'Dimsum Ayam', price: 15000),
          ShoppingMenuOption(id: 10, name: 'Es Teh', price: 3000),
        ],
      },
    );

    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: fakeService,
      customerOrderRepository: fakeRepository,
      merchantPickerResult: const ShoppingMerchantPickerResult(
        merchantId: 42,
        place: ShoppingMerchantPlacePayload(
          placeId: 'official-42',
          name: 'Dimsum Dan Seblak Wolu',
          address: 'Lokasi BangDeliv',
          latitude: -7.3178,
          longitude: 110.463,
          types: <String>['restaurant'],
        ),
      ),
    );

    await _sendMessage(tester, 'beli sembako');

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Pilih Merchant di Map'),
    );
    await _pumpChatbotFrame(tester);
    await tester.tap(find.text('Pilih Kedai Kedua'));
    await _pumpChatbotFrame(tester);

    expect(fakeService.patchMerchantCallCount, 1);
    expect(fakeService.lastMerchantId, 42);
    expect(fakeRepository.searchMenuCallCount, 1);
    expect(fakeRepository.lastMerchantId, 42);
    expect(find.textContaining('Draft Nitip belum lengkap'), findsOneWidget);
    expect(
      find.textContaining('Merchant Nitip berhasil dipilih'),
      findsNothing,
    );
    expect(find.text('Pilih menu'), findsOneWidget);
    expect(find.text('Dimsum Dan Seblak Wolu'), findsOneWidget);
    expect(find.text('Dimsum Ayam'), findsOneWidget);
    expect(find.text('Rp15.000'), findsOneWidget);

    await tester.tap(find.byTooltip('Tambah Dimsum Ayam'));
    await tester.tap(find.byTooltip('Tambah Dimsum Ayam'));
    await tester.tap(find.byTooltip('Tambah Es Teh'));
    await _pumpChatbotFrame(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Konfirmasi'));
    await _pumpChatbotFrame(tester);

    expect(fakeService.lastMessage, 'Dimsum Ayam 2\nEs Teh 1');
  });

  testWidgets('nitip external merchant picker keeps manual item flow', (
    WidgetTester tester,
  ) async {
    final fakeRepository = _FakeCustomerOrderRepository();

    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: _FakeChatbotApiService(),
      customerOrderRepository: fakeRepository,
    );

    await _sendMessage(tester, 'beli sembako');

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Pilih Merchant di Map'),
    );
    await _pumpChatbotFrame(tester);
    await tester.tap(find.text('Pilih Kedai Kedua'));
    await _pumpChatbotFrame(tester);

    expect(fakeRepository.searchMenuCallCount, 0);
    expect(find.text('Pilih menu'), findsNothing);
    expect(find.textContaining('Draft Nitip belum lengkap'), findsNWidgets(2));
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

  testWidgets('order created keeps chat usable with a fresh session', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeChatbotApiService();

    await _pumpChatbot(
      tester,
      serviceType: 'antar_jemput',
      chatbotApiService: fakeService,
    );

    await _sendMessage(tester, 'Konfirmasi');
    final completedSessionId = fakeService.lastClearedSessionId;

    expect(fakeService.clearSessionCallCount, 1);
    expect(find.text('Lacak Pesanan'), findsOneWidget);

    await _sendMessage(tester, 'alamat baru');

    expect(fakeService.callCount, 2);
    expect(fakeService.lastSessionId, isNot(completedSessionId));
    expect(find.textContaining('Alamat jemput di profil'), findsOneWidget);
  });

  testWidgets('track order action keeps completed chat while navigating', (
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

  testWidgets('back button leaves completed chat cleanup to auto rotation', (
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
  ChatbotLaunchArgs? launchArgs,
  CustomerOrderRepository? customerOrderRepository,
  ShoppingMerchantPickerResult? merchantPickerResult,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});

  final router = GoRouter(
    initialLocation: '/chatbot?service_type=$serviceType',
    routes: <RouteBase>[
      GoRoute(
        path: '/chatbot',
        builder: (BuildContext context, GoRouterState state) {
          return ChatbotScreen(launchArgs: launchArgs);
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
          final result =
              merchantPickerResult ??
              const ShoppingMerchantPickerResult(
                place: ShoppingMerchantPlacePayload(
                  placeId: 'google-place-kedai-kedua',
                  name: 'Kedai Kedua',
                  address: 'Jl. Kedai Kedua',
                  latitude: -7.05,
                  longitude: 110.43,
                  types: <String>['restaurant'],
                ),
              );
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  context.pop(result);
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
        if (customerOrderRepository != null)
          customerOrderRepositoryProvider.overrideWithValue(
            customerOrderRepository,
          ),
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

class _FakeCustomerOrderRepository implements CustomerOrderRepository {
  _FakeCustomerOrderRepository({
    this.menusByMerchantId = const <int, List<ShoppingMenuOption>>{},
  });

  final Map<int, List<ShoppingMenuOption>> menusByMerchantId;
  int searchMenuCallCount = 0;
  int? lastMerchantId;
  String? lastMenuQuery;

  @override
  Future<List<ShoppingMenuOption>> searchMerchantMenus(
    int merchantId,
    String query,
  ) async {
    searchMenuCallCount += 1;
    lastMerchantId = merchantId;
    lastMenuQuery = query;

    return menusByMerchantId[merchantId] ?? const <ShoppingMenuOption>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  int? lastMerchantId;
  String? lastClearedSessionId;
  String? lastMessage;
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
    lastMessage = message;

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

    if (serviceType == 'nitip' && normalized == 'qris') {
      return ChatbotResult.fromApiJson({
        'status': 'success',
        'session_id': sessionId,
        'service_context': {'service_type': serviceType},
        'model_used': 'deterministic-payment',
        'data': {
          'intent': 'shopping_order',
          'assistant_text':
              'Baik, metode pembayaran QRIS sudah dipilih. Ketik "Konfirmasi" kalau sudah oke.',
          'shopping': {
            'ready_to_confirm': true,
            'payment_method': 'TRANSFER',
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
          'order': {'created': false, 'payment_method': 'TRANSFER'},
        },
      });
    }

    if ((serviceType == 'antar_jemput' || serviceType == 'kurir') &&
        normalized == 'draft transport payment') {
      final draftKey = serviceType == 'antar_jemput' ? 'ride' : 'courier';
      return ChatbotResult.fromApiJson({
        'status': 'success',
        'session_id': sessionId,
        'service_context': {'service_type': serviceType},
        'model_used': 'gemini-3.1-flash-lite',
        'data': {
          'intent': serviceType == 'antar_jemput'
              ? 'ride_order'
              : 'courier_order',
          'assistant_text':
              'Draft siap. Pilih metode pembayaran sebelum konfirmasi.',
          draftKey: {'ready_to_confirm': true, 'payment_method': null},
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

    if ((serviceType == 'antar_jemput' || serviceType == 'kurir') &&
        normalized == 'qris') {
      final draftKey = serviceType == 'antar_jemput' ? 'ride' : 'courier';
      return ChatbotResult.fromApiJson({
        'status': 'success',
        'session_id': sessionId,
        'service_context': {'service_type': serviceType},
        'model_used': 'deterministic-payment',
        'data': {
          'intent': serviceType == 'antar_jemput'
              ? 'ride_order'
              : 'courier_order',
          'assistant_text':
              'Baik, metode pembayaran QRIS sudah dipilih. Ketuk Konfirmasi kalau sudah oke.',
          draftKey: {'ready_to_confirm': true, 'payment_method': 'TRANSFER'},
          'validation': {
            'is_valid_order': true,
            'rejection_reasons': [],
            'missing_fields': [],
            'next_actions': [
              'SET_PAYMENT_COD',
              'SET_PAYMENT_TRANSFER',
              'RESET_DESTINATION',
            ],
          },
          'action_payloads': {
            'SET_PAYMENT_COD': {'label': 'COD', 'message': 'COD'},
            'SET_PAYMENT_TRANSFER': {'label': 'QRIS', 'message': 'QRIS'},
            'RESET_DESTINATION': {
              'label': 'Ubah Tujuan',
              'message': 'Ubah Tujuan',
            },
          },
          'order': {'created': false, 'payment_method': 'TRANSFER'},
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

    if (normalized.contains('reset tujuan')) {
      return ChatbotResult.fromApiJson({
        'status': 'success',
        'model_used': 'gemini-2.5-flash',
        'data': {
          'intent': 'ride_order',
          'assistant_text':
              'tujuan sebelumnya sudah saya reset.\n'
              'Jemput: Fakultas Teknik UNDIP\n'
              'Silakan pilih tujuan baru.',
          'validation': {
            'is_valid_order': false,
            'rejection_reasons': [],
            'missing_fields': ['destination_address'],
            'next_actions': ['OPEN_ROUTE_PICKER'],
          },
          'action_payloads': {
            'OPEN_ROUTE_PICKER': {
              'label': 'Pilih Tujuan Baru',
              'points': {
                'destination': {
                  'target': 'destination',
                  'label': 'Titik Tujuan',
                },
              },
            },
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
    lastMerchantId = merchantId;

    return ChatbotResult.fromApiJson({
      'status': 'success',
      'session_id': sessionId,
      'service_context': {'service_type': serviceType},
      'model_used': 'merchant-picker-action',
      'data': {
        'intent': 'shopping_order',
        'assistant_text': mode == 'add'
            ? 'Draft Nitip belum lengkap. Lengkapi: items.\n\nMerchant\nKedai Kedua\n\nTulis item dan jumlah untuk merchant ini.\nContoh:\n- susu 1\n- roti tawar 2\n- air mineral 1'
            : 'Draft Nitip belum lengkap. Lengkapi: items.\n\nMerchant\nKedai Kedua\n\nTulis item dan jumlah untuk merchant ini.\nContoh:\n- susu 1\n- roti tawar 2\n- air mineral 1',
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
