import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_bangdeliv/models/address_location_picker_result.dart';
import 'package:frontend_bangdeliv/config/app_colors.dart';
import 'package:frontend_bangdeliv/models/chatbot_model.dart';
import 'package:frontend_bangdeliv/models/chatbot_launch_args.dart';
import 'package:frontend_bangdeliv/models/customer_order_model.dart';
import 'package:frontend_bangdeliv/models/route_location_picker_result.dart';
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
import 'package:frontend_bangdeliv/widgets/bang_ui.dart';

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
    _expectEnabledFilledAction(
      tester,
      label: 'Isi Alamat Saya',
      backgroundColor: AppColors.primary,
    );
  });

  testWidgets('courier bootstrap shows one route picker action', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'kurir',
      chatbotApiService: _FakeChatbotApiService(),
    );

    expect(find.text('Atur Lokasi Ambil/Tujuan'), findsOneWidget);
    _expectEnabledFilledAction(
      tester,
      label: 'Atur Lokasi Ambil/Tujuan',
      backgroundColor: AppColors.primary,
    );
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

    expect(find.text('Atur Lokasi Jemput/Tujuan'), findsOneWidget);
    _expectEnabledFilledAction(
      tester,
      label: 'Atur Lokasi Jemput/Tujuan',
      backgroundColor: AppColors.primary,
    );
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
    expect(_filledIconButtonWithText('Pilih Tujuan Baru'), findsOneWidget);
    _expectEnabledFilledAction(
      tester,
      label: 'Pilih Tujuan Baru',
      backgroundColor: AppColors.primary,
    );
    expect(find.text('Atur Lokasi Jemput/Tujuan'), findsNothing);
  });

  testWidgets('ride edit location opens route picker without preset bubble', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeChatbotApiService();
    await _pumpChatbot(
      tester,
      serviceType: 'antar_jemput',
      chatbotApiService: fakeService,
    );

    await _sendMessage(tester, 'draft transport payment');
    await tester.tap(_filledIconButtonWithText('QRIS'));
    await _pumpChatbotFrame(tester);

    expect(
      _filledIconButtonWithText('Ubah Lokasi Jemput/Tujuan'),
      findsOneWidget,
    );
    _expectEnabledFilledAction(
      tester,
      label: 'Ubah Lokasi Jemput/Tujuan',
      backgroundColor: AppColors.primary,
    );

    await tester.tap(_filledIconButtonWithText('Ubah Lokasi Jemput/Tujuan'));
    await _pumpChatbotFrame(tester);

    expect(find.text('Atur Rute Antar Jemput'), findsOneWidget);
    expect(fakeService.callCount, 2);
    expect(fakeService.lastMessage, 'QRIS');
    expect(find.text('Ubah Tujuan'), findsNothing);
  });

  testWidgets('nitip welcome shows concise multi tempat guidance', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: _FakeChatbotApiService(),
    );

    expect(
      find.textContaining('memilih toko/resto dan alamat antar'),
      findsOneWidget,
    );
    expect(find.textContaining('sudah terdaftar di BangDeliv'), findsOneWidget);
    expect(
      find.textContaining('ketuk tombol Pilih Toko/Resto'),
      findsOneWidget,
    );
    expect(find.textContaining('lalu ketuk Cari lewat Maps'), findsOneWidget);
    // Penanda bold **...** harus di-strip (dirender tebal), tidak tampil literal.
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('dapat ditemukan di Google Maps'), findsNothing);
    expect(find.textContaining('Alamat antar utama'), findsNothing);
    expect(find.textContaining('masih draft'), findsNothing);
    expect(find.textContaining('maksimal 3 toko/resto'), findsOneWidget);
    expect(find.textContaining('Beli di Nasgor Gajah'), findsOneWidget);
    expect(find.text('Beli ayam geprek'), findsNothing);
    expect(find.text('Beli sembako'), findsNothing);
    expect(find.text('Belanja minimarket'), findsNothing);
    expect(_filledIconButtonWithText('Pilih Toko/Resto'), findsOneWidget);
    _expectEnabledFilledAction(
      tester,
      label: 'Pilih Toko/Resto',
      backgroundColor: AppColors.primary,
    );
    expect(
      tester.getSize(_filledIconButtonWithText('Pilih Toko/Resto')).height,
      greaterThanOrEqualTo(48),
    );
    expect(find.text('Ketuk tombol untuk atur pesanan'), findsOneWidget);
  });

  testWidgets('antar jemput welcome shows pickup and destination examples', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'antar_jemput',
      chatbotApiService: _FakeChatbotApiService(),
    );

    expect(
      find.textContaining('menulis titik jemput dan tujuan'),
      findsOneWidget,
    );
    // Peringatan Maps menyebut kedua titik, bukan hanya tujuan.
    expect(
      find.textContaining('lokasi jemput dan tujuan dapat ditemukan'),
      findsOneWidget,
    );
    expect(find.textContaining('menulis tujuan perjalanan'), findsNothing);
    expect(find.textContaining('Contoh:'), findsOneWidget);
    expect(find.textContaining('Antar ke Ramayana Salatiga'), findsOneWidget);
    expect(
      find.textContaining('Jemput saya di Kopi Kenangan Tembalang'),
      findsOneWidget,
    );
    expect(find.textContaining('Google Maps'), findsOneWidget);
    expect(find.text('Ketuk tombol untuk atur lokasi'), findsOneWidget);
  });

  testWidgets('courier welcome shows the complete writing format', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'kurir',
      chatbotApiService: _FakeChatbotApiService(),
    );

    expect(find.textContaining('Contoh:'), findsOneWidget);
    expect(
      find.textContaining('Ambil: Laundry Berkah Salatiga'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Tujuan: Universitas Kristen Satya Wacana'),
      findsOneWidget,
    );
    expect(find.textContaining('Barang: 1 tas laundry'), findsOneWidget);
    expect(find.textContaining('Google Maps'), findsOneWidget);
    expect(find.text('Ketuk tombol untuk atur lokasi'), findsOneWidget);
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

  testWidgets('chatbot app bar refresh asks for confirmation and can cancel', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeChatbotApiService();
    await _pumpChatbot(
      tester,
      serviceType: 'antar_jemput',
      chatbotApiService: fakeService,
    );

    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byTooltip('Refresh chat'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh chat'));
    await _pumpChatbotFrame(tester);

    expect(find.text('Refresh chat?'), findsOneWidget);
    expect(
      find.text(
        'Percakapan dan draft pesanan saat ini akan dihapus. Kamu yakin ingin memulai chat dari awal?',
      ),
      findsOneWidget,
    );
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Refresh Chat'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await _pumpChatbotFrame(tester);

    expect(find.text('Refresh chat?'), findsNothing);
    expect(fakeService.clearSessionCallCount, 0);
  });

  testWidgets('refresh confirmation starts a fresh chatbot session', (
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

    await tester.tap(find.byTooltip('Refresh chat'));
    await _pumpChatbotFrame(tester);

    expect(find.text('Refresh chat?'), findsOneWidget);

    await tester.tap(find.text('Refresh Chat'));
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

      expect(_filledIconButtonWithText('Buat Pesanan'), findsOneWidget);
      expect(_filledIconButtonWithText('COD'), findsNothing);
      expect(_filledIconButtonWithText('QRIS'), findsNothing);
      expect(
        find.textContaining('kompensasi 50% tarif segmen gagal'),
        findsNothing,
      );
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

    expect(_filledIconButtonWithText('COD'), findsOneWidget);
    expect(_filledIconButtonWithText('QRIS'), findsOneWidget);

    await tester.tap(_filledIconButtonWithText('COD'));
    await _pumpChatbotFrame(tester);

    expect(fakeService.callCount, 2);
    expect(_filledIconButtonWithText('Buat Pesanan'), findsOneWidget);
    expect(_filledIconButtonWithText('COD'), findsNothing);
    expect(_filledIconButtonWithText('QRIS'), findsNothing);
  });

  for (final entry
      in const <String, ({String draftMessage, String confirmLabel})>{
        'antar_jemput': (
          draftMessage: 'draft transport payment',
          confirmLabel: 'Buat Pesanan',
        ),
        'kurir': (
          draftMessage: 'draft transport payment',
          confirmLabel: 'Buat Pesanan',
        ),
        'nitip': (
          draftMessage: 'draft nitip payment',
          confirmLabel: 'Buat Pesanan',
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

      expect(_filledIconButtonWithText('COD'), findsOneWidget);
      expect(_filledIconButtonWithText('QRIS'), findsOneWidget);

      for (final label in const ['COD', 'QRIS']) {
        _expectEnabledFilledAction(
          tester,
          label: label,
          backgroundColor: AppColors.success,
        );
      }

      await tester.tap(_filledIconButtonWithText('QRIS'));
      await _pumpChatbotFrame(tester);

      expect(fakeService.lastMessage, 'QRIS');
      expect(
        _filledIconButtonWithText(entry.value.confirmLabel),
        findsOneWidget,
      );
      _expectEnabledFilledAction(
        tester,
        label: entry.value.confirmLabel,
        backgroundColor: AppColors.success,
      );
      expect(_filledIconButtonWithText('COD'), findsNothing);
      expect(_filledIconButtonWithText('QRIS'), findsNothing);
    });
  }

  testWidgets('nitip missing tempat shows map picker action', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: _FakeChatbotApiService(),
    );

    await _sendMessage(tester, 'beli sembako');

    expect(find.textContaining('belum terdaftar di BangDeliv'), findsOneWidget);
    expect(
      find.textContaining(
        'Ketuk Cari lewat Maps agar driver mendapatkan titik yang tepat',
      ),
      findsOneWidget,
    );
    expect(_filledIconButtonWithText('Cari lewat Maps'), findsOneWidget);
  });

  testWidgets(
    'nitip empty draft keeps nearby recommendation instead of map fallback',
    (WidgetTester tester) async {
      await _pumpChatbot(
        tester,
        serviceType: 'nitip',
        chatbotApiService: _FakeChatbotApiService(),
      );

      await _sendMessage(tester, 'nitip apa enaknya');

      expect(
        find.textContaining(
          'Berikut pilihan dari restoran terdekat dengan alamat antarmu',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Resto Paling Dekat'), findsOneWidget);
      expect(
        find.textContaining('Nama toko/resto itu belum terdaftar'),
        findsNothing,
      );
      expect(_filledIconButtonWithText('Pilih Toko/Resto'), findsOneWidget);
    },
  );

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
    expect(find.textContaining('Tempat Nitip berhasil dipilih'), findsNothing);
    expect(find.text('Pilih menu'), findsOneWidget);
    expect(find.text('Bakso Balungan'), findsOneWidget);
    expect(find.text('Bakso Urat'), findsOneWidget);
    expect(find.text('Rp 12.000'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Bakso Urat - Rp 12.000'),
      findsNothing,
    );

    final disabledConfirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Konfirmasi Pilihan (0)'),
    );
    expect(disabledConfirm.onPressed, isNull);
    expect(find.text('Tulis item manual'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byTooltip('Tambah Bakso Urat'));
    await _pumpChatbotFrame(tester);

    final enabledConfirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Konfirmasi Pilihan (1)'),
    );
    expect(enabledConfirm.onPressed, isNotNull);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Konfirmasi Pilihan (1)'),
    );
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
          ShoppingMenuOption(id: 10, name: 'Es Teh', price: 0),
          ShoppingMenuOption(id: 11, name: 'Ikan Bakar', price: null),
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
          address: 'Lokasi Bang Deliv',
          latitude: -7.3178,
          longitude: 110.463,
          types: <String>['restaurant'],
        ),
      ),
    );

    await _sendMessage(tester, 'beli sembako');

    await tester.tap(_filledIconButtonWithText('Cari lewat Maps'));
    await _pumpChatbotFrame(tester);
    await tester.tap(find.text('Pilih Kedai Kedua'));
    await _pumpChatbotFrame(tester);

    expect(fakeService.patchMerchantCallCount, 1);
    expect(fakeService.lastMerchantId, 42);
    expect(fakeRepository.searchMenuCallCount, 1);
    expect(fakeRepository.lastMerchantId, 42);
    expect(find.textContaining('Draft Nitip belum lengkap'), findsNothing);
    expect(find.textContaining('Tempat Nitip berhasil dipilih'), findsNothing);
    expect(find.text('Pilih menu'), findsOneWidget);
    expect(find.text('Dimsum Dan Seblak Wolu'), findsOneWidget);
    expect(find.text('Dimsum Ayam'), findsOneWidget);
    expect(find.text('Rp15.000'), findsOneWidget);
    expect(find.text('Rp0'), findsOneWidget);
    expect(find.text('Harga sesuai nota'), findsOneWidget);

    await tester.tap(find.byTooltip('Tambah Dimsum Ayam'));
    await tester.tap(find.byTooltip('Tambah Dimsum Ayam'));
    await tester.tap(find.byTooltip('Tambah Es Teh'));
    await _pumpChatbotFrame(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Konfirmasi Pilihan (3)'),
    );
    await _pumpChatbotFrame(tester);

    expect(fakeService.lastMessage, 'Dimsum Ayam 2\nEs Teh 1');
  });

  testWidgets('lihat menu untuk resto terdaftar otomatis membuka menu selector', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeChatbotApiService();
    final fakeRepository = _FakeCustomerOrderRepository(
      menusByMerchantId: const <int, List<ShoppingMenuOption>>{
        77: <ShoppingMenuOption>[
          ShoppingMenuOption(id: 1, name: 'Nasi Goreng Spesial', price: 15000),
          ShoppingMenuOption(id: 2, name: 'Es Teh', price: 3000),
        ],
      },
    );

    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: fakeService,
      customerOrderRepository: fakeRepository,
    );

    await _sendMessage(tester, 'Lihat menu Nasgor Gajah');

    // Sinyal menu_selector memicu pemuatan menu resto otomatis.
    expect(fakeRepository.searchMenuCallCount, 1);
    expect(fakeRepository.lastMerchantId, 77);
    expect(find.text('Pilih menu'), findsOneWidget);
    expect(find.text('Nasgor Gajah'), findsOneWidget);
    expect(find.text('Nasi Goreng Spesial'), findsOneWidget);
    expect(find.text('Rp15.000'), findsOneWidget);
  });

  testWidgets('menu selector search filters and keeps hidden selection counted', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeChatbotApiService();
    final fakeRepository = _FakeCustomerOrderRepository(
      menusByMerchantId: <int, List<ShoppingMenuOption>>{
        42: <ShoppingMenuOption>[
          for (var i = 1; i <= 11; i++)
            ShoppingMenuOption(id: i, name: 'Menu $i', price: 10000),
          const ShoppingMenuOption(id: 12, name: 'Bakso Spesial', price: 12000),
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
          address: 'Lokasi Bang Deliv',
          latitude: -7.3178,
          longitude: 110.463,
          types: <String>['restaurant'],
        ),
      ),
    );

    await _sendMessage(tester, 'beli sembako');
    await tester.tap(_filledIconButtonWithText('Cari lewat Maps'));
    await _pumpChatbotFrame(tester);
    await tester.tap(find.text('Pilih Kedai Kedua'));
    await _pumpChatbotFrame(tester);

    expect(find.text('Pilih menu'), findsOneWidget);
    expect(find.text('Menu 1'), findsOneWidget);
    expect(find.text('Bakso Spesial'), findsNothing);
    expect(find.text('Tampilkan 2 menu lainnya'), findsOneWidget);

    final searchField = find.descendant(
      of: find.byType(BangSearchField),
      matching: find.byType(TextField),
    );
    await tester.enterText(searchField, 'bakso');
    await _pumpChatbotFrame(tester);

    expect(find.text('Bakso Spesial'), findsOneWidget);
    expect(find.text('Menu 1'), findsNothing);

    await tester.ensureVisible(find.byTooltip('Tambah Bakso Spesial'));
    await tester.tap(find.byTooltip('Tambah Bakso Spesial'));
    await _pumpChatbotFrame(tester);

    await tester.enterText(searchField, '');
    await _pumpChatbotFrame(tester);

    expect(find.text('Bakso Spesial'), findsNothing);
    expect(
      find.widgetWithText(FilledButton, 'Konfirmasi Pilihan (1)'),
      findsOneWidget,
    );

    await tester.tap(
      find.widgetWithText(FilledButton, 'Konfirmasi Pilihan (1)'),
    );
    await _pumpChatbotFrame(tester);

    expect(fakeService.lastMessage, 'Bakso Spesial 1');
  });

  testWidgets('menu selector asks before switching to manual item input', (
    tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: _FakeChatbotApiService(),
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

    await tester.tap(find.byTooltip('Tambah Bakso Urat'));
    await _pumpChatbotFrame(tester);
    await tester.tap(find.text('Tulis item manual'));
    await tester.pumpAndSettle();

    expect(find.text('Tulis item manual?'), findsOneWidget);
    expect(find.textContaining('Pilihan 1 item'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Tulis manual'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih menu'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('failed menu confirmation preserves selected quantities', (
    tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: _FakeChatbotApiService(
        failingMessages: const <String>{'bakso urat 1'},
      ),
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

    await tester.tap(find.byTooltip('Tambah Bakso Urat'));
    await _pumpChatbotFrame(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Konfirmasi Pilihan (1)'),
    );
    await _pumpChatbotFrame(tester);

    expect(find.text('Pilih menu'), findsOneWidget);
    expect(find.text('1 item dipilih'), findsOneWidget);
    expect(find.text('Chatbot timeout'), findsWidgets);
  });

  testWidgets('nitip official menu selector survives reopening chatbot', (
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

    final router = await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: fakeService,
      customerOrderRepository: fakeRepository,
      merchantPickerResult: const ShoppingMerchantPickerResult(
        merchantId: 42,
        place: ShoppingMerchantPlacePayload(
          placeId: 'official-42',
          name: 'Dimsum Dan Seblak Wolu',
          address: 'Lokasi Bang Deliv',
          latitude: -7.3178,
          longitude: 110.463,
          types: <String>['restaurant'],
        ),
      ),
    );

    await tester.tap(_filledIconButtonWithText('Pilih Toko/Resto'));
    await _pumpChatbotFrame(tester);
    await tester.tap(find.text('Pilih Kedai Kedua'));
    await _pumpChatbotFrame(tester);

    expect(find.text('Pilih menu'), findsOneWidget);
    expect(find.text('Dimsum Ayam'), findsOneWidget);

    await tester.tap(find.byTooltip('Tambah Dimsum Ayam'));
    await _pumpChatbotFrame(tester);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await _pumpChatbotFrame(tester);

    expect(find.text('Home Screen'), findsOneWidget);

    router.go('/chatbot?service_type=nitip');
    await _pumpChatbotFrame(tester);

    expect(find.text('Pilih menu'), findsOneWidget);
    expect(find.text('Dimsum Ayam'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Konfirmasi Pilihan (1)'),
    );
    await _pumpChatbotFrame(tester);

    expect(fakeService.lastMessage, 'Dimsum Ayam 1');
    expect(find.text('Pilih menu'), findsNothing);
  });

  testWidgets('nitip menu selector can change official merchant from list', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeChatbotApiService();
    final fakeRepository = _FakeCustomerOrderRepository(
      menusByMerchantId: const <int, List<ShoppingMenuOption>>{
        42: <ShoppingMenuOption>[
          ShoppingMenuOption(id: 9, name: 'Dimsum Ayam', price: 15000),
        ],
        43: <ShoppingMenuOption>[
          ShoppingMenuOption(id: 21, name: 'Bakso Urat', price: 12000),
        ],
      },
    );

    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: fakeService,
      customerOrderRepository: fakeRepository,
      merchantPickerResults: const <ShoppingMerchantPickerResult>[
        ShoppingMerchantPickerResult(
          merchantId: 42,
          place: ShoppingMerchantPlacePayload(
            placeId: 'official-42',
            name: 'Dimsum Dan Seblak Wolu',
            address: 'Lokasi Bang Deliv',
            latitude: -7.3178,
            longitude: 110.463,
            types: <String>['restaurant'],
          ),
        ),
        ShoppingMerchantPickerResult(
          merchantId: 43,
          place: ShoppingMerchantPlacePayload(
            placeId: 'official-43',
            name: 'Bakso Balungan',
            address: 'Lokasi Bang Deliv',
            latitude: -7.318,
            longitude: 110.464,
            types: <String>['restaurant'],
          ),
        ),
      ],
    );

    await tester.tap(_filledIconButtonWithText('Pilih Toko/Resto'));
    await _pumpChatbotFrame(tester);
    await tester.tap(find.text('Pilih Kedai Kedua'));
    await _pumpChatbotFrame(tester);

    expect(find.text('Dimsum Dan Seblak Wolu'), findsOneWidget);
    expect(find.text('Dimsum Ayam'), findsOneWidget);

    await tester.tap(find.text('Ganti Toko/Resto'));
    await _pumpChatbotFrame(tester);
    await tester.tap(find.text('Pilih Kedai Kedua'));
    await _pumpChatbotFrame(tester);

    expect(fakeService.patchMerchantCallCount, 2);
    expect(fakeService.lastMerchantMode, 'select');
    expect(fakeService.lastMerchantId, 43);
    expect(fakeRepository.searchMenuCallCount, 2);
    expect(fakeRepository.lastMerchantId, 43);
    expect(find.text('Bakso Balungan'), findsOneWidget);
    expect(find.text('Bakso Urat'), findsOneWidget);
    expect(find.text('Dimsum Ayam'), findsNothing);
  });

  testWidgets(
    'nitip "Ganti Toko/Resto" replaces the active stop instead of adding',
    (WidgetTester tester) async {
      final fakeService = _FakeChatbotApiService()
        // Backend menyertakan stop dengan stop_id stabil + is_active.
        ..merchantStopsPayload = <Map<String, dynamic>>[
          <String, dynamic>{
            'index': 1,
            'stop_id': 'stop-uuid-1',
            'is_active': true,
            'ready': false,
            'merchant': <String, dynamic>{'name': 'Kedai Aktif'},
            'items': <dynamic>[],
          },
        ];
      final fakeRepository = _FakeCustomerOrderRepository(
        menusByMerchantId: const <int, List<ShoppingMenuOption>>{
          42: <ShoppingMenuOption>[
            ShoppingMenuOption(id: 9, name: 'Dimsum Ayam', price: 15000),
          ],
          43: <ShoppingMenuOption>[
            ShoppingMenuOption(id: 21, name: 'Bakso Urat', price: 12000),
          ],
        },
      );

      await _pumpChatbot(
        tester,
        serviceType: 'nitip',
        chatbotApiService: fakeService,
        customerOrderRepository: fakeRepository,
        merchantPickerResults: const <ShoppingMerchantPickerResult>[
          ShoppingMerchantPickerResult(
            merchantId: 42,
            place: ShoppingMerchantPlacePayload(
              placeId: 'official-42',
              name: 'Dimsum Dan Seblak Wolu',
              address: 'Lokasi Bang Deliv',
              latitude: -7.3178,
              longitude: 110.463,
              types: <String>['restaurant'],
            ),
          ),
          ShoppingMerchantPickerResult(
            merchantId: 43,
            place: ShoppingMerchantPlacePayload(
              placeId: 'official-43',
              name: 'Bakso Balungan',
              address: 'Lokasi Bang Deliv',
              latitude: -7.318,
              longitude: 110.464,
              types: <String>['restaurant'],
            ),
          ),
        ],
      );

      await tester.tap(_filledIconButtonWithText('Pilih Toko/Resto'));
      await _pumpChatbotFrame(tester);
      await tester.tap(find.text('Pilih Kedai Kedua'));
      await _pumpChatbotFrame(tester);

      // Menu selector untuk stop aktif tampil.
      expect(find.text('Dimsum Dan Seblak Wolu'), findsOneWidget);
      expect(find.text('Dimsum Ayam'), findsOneWidget);
      expect(fakeService.lastMerchantMode, 'select');

      await tester.tap(find.text('Ganti Toko/Resto'));
      await _pumpChatbotFrame(tester);
      await tester.tap(find.text('Pilih Kedai Kedua'));
      await _pumpChatbotFrame(tester);

      // "Ganti" harus MENGGANTI stop tersebut (mode replace + target stop_id),
      // bukan menambah stop baru (mode add).
      expect(fakeService.patchMerchantCallCount, 2);
      expect(fakeService.lastMerchantMode, 'replace');
      expect(fakeService.lastReplaceTargetStopId, 'stop-uuid-1');
      expect(fakeService.lastMerchantId, 43);
      expect(find.text('Bakso Balungan'), findsOneWidget);
      expect(find.text('Bakso Urat'), findsOneWidget);
      expect(find.text('Dimsum Ayam'), findsNothing);
    },
  );

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

    await tester.tap(_filledIconButtonWithText('Cari lewat Maps'));
    await _pumpChatbotFrame(tester);
    await tester.tap(find.text('Pilih Kedai Kedua'));
    await _pumpChatbotFrame(tester);

    expect(fakeRepository.searchMenuCallCount, 0);
    expect(find.text('Pilih menu'), findsNothing);
    expect(find.textContaining('Draft Nitip belum lengkap'), findsOneWidget);
    expect(find.text('-'), findsNWidgets(3));
    expect(find.text('susu 1'), findsOneWidget);
    expect(find.text('roti tawar 2'), findsOneWidget);
    expect(find.text('air mineral 1'), findsOneWidget);

    final exampleText = tester.widget<Text>(find.text('susu 1'));
    expect(exampleText.style?.fontWeight, FontWeight.w600);
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! Container) {
          return false;
        }
        final decoration = widget.decoration;
        return widget.constraints ==
                const BoxConstraints.tightFor(width: 4, height: 4) &&
            decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle;
      }),
      findsNothing,
    );
  });

  testWidgets(
    'nitip ready first tempat offers add tempat action with mode add',
    (WidgetTester tester) async {
      final fakeService = _FakeChatbotApiService();
      await _pumpChatbot(
        tester,
        serviceType: 'nitip',
        chatbotApiService: fakeService,
      );

      await _sendMessage(tester, 'draft nitip merchant siap');

      expect(find.text('Tambah toko/resto lain'), findsOneWidget);
      expect(
        find.textContaining('Pilih toko/resto dari daftar atau peta'),
        findsOneWidget,
      );
      expect(_filledIconButtonWithText('Tambah Toko/Resto'), findsOneWidget);
      _expectEnabledFilledAction(
        tester,
        label: 'Tambah Toko/Resto',
        backgroundColor: AppColors.primary,
      );
      expect(find.text('Beli ayam geprek'), findsNothing);

      await tester.ensureVisible(
        _filledIconButtonWithText('Tambah Toko/Resto'),
      );
      await _pumpChatbotFrame(tester);
      await tester.tap(_filledIconButtonWithText('Tambah Toko/Resto'));
      await _pumpChatbotFrame(tester);
      await tester.tap(find.text('Pilih Kedai Kedua'));
      await _pumpChatbotFrame(tester);

      expect(fakeService.patchMerchantCallCount, 1);
      expect(fakeService.lastMerchantMode, 'add');
      expect(find.textContaining('Kedai Kedua'), findsOneWidget);
      expect(find.textContaining('air mineral 1'), findsOneWidget);
    },
  );

  testWidgets('nitip estimate notice keeps long total label readable', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: _FakeChatbotApiService(),
    );

    await _sendMessage(tester, 'draft nitip merchant siap');
    final labelFinder = find.text('Estimasi total:');
    final amountFinder = find.text('Menunggu harga barang');

    await tester.ensureVisible(amountFinder);
    await _pumpChatbotFrame(tester);

    expect(labelFinder, findsOneWidget);
    expect(amountFinder, findsOneWidget);
    expect(
      tester.getTopLeft(amountFinder).dy,
      greaterThan(tester.getTopLeft(labelFinder).dy),
    );
    for (final label in const [
      'COD',
      'QRIS',
      'Ganti Alamat Antar',
      'Tambah Toko/Resto',
    ]) {
      expect(_filledIconButtonWithText(label), findsOneWidget);
      expect(
        tester.getSize(_filledIconButtonWithText(label)).height,
        greaterThanOrEqualTo(48),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('chatbot action buttons define a neutral disabled style', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: _FakeChatbotApiService(),
    );

    final button = tester.widget<FilledButton>(
      _filledIconButtonWithText('Pilih Toko/Resto'),
    );
    expect(button.onPressed, isNotNull);
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{
        WidgetState.disabled,
      }),
      AppColors.surfaceAlt,
    );
    expect(
      button.style?.foregroundColor?.resolve(<WidgetState>{
        WidgetState.disabled,
      }),
      AppColors.textMuted,
    );
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
    'nitip': 'layanan Nitip. Sebelum membuat pesanan',
    'antar_jemput': 'layanan Antar Jemput. Sebelum membuat pesanan',
    'kurir': 'layanan Kurir. Sebelum membuat pesanan',
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
      expect(find.text('Atur Lokasi Ambil/Tujuan'), findsNothing);
      expect(find.text('Atur Lokasi Jemput/Tujuan'), findsNothing);

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
    _expectEnabledFilledAction(
      tester,
      label: 'Lacak Pesanan',
      backgroundColor: AppColors.primary,
    );
    expect(find.textContaining('belum bisa digunakan'), findsNothing);
  });

  testWidgets('draft chat survives leaving and reopening chatbot', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeChatbotApiService();
    final router = await _pumpChatbot(
      tester,
      serviceType: 'antar_jemput',
      chatbotApiService: fakeService,
    );

    await _sendMessage(tester, 'antar ke polines');

    expect(find.textContaining('Draft siap'), findsOneWidget);
    expect(fakeService.callCount, 1);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await _pumpChatbotFrame(tester);

    expect(find.text('Home Screen'), findsOneWidget);

    router.go('/chatbot?service_type=antar_jemput');
    await _pumpChatbotFrame(tester);

    expect(find.textContaining('Draft siap'), findsOneWidget);
    expect(fakeService.callCount, 1);
  });

  testWidgets('resolved order resets chatbot conversation', (
    WidgetTester tester,
  ) async {
    final fakeOrders = _FakeCustomerOrderRepository(
      orders: <CustomerOrderSummaryModel>[
        _buildOrderSummary(
          id: 33,
          statusCode: 'COMPLETED',
          statusLabel: 'Selesai',
          isTerminalStatus: true,
        ),
      ],
    );

    await _pumpChatbot(
      tester,
      serviceType: 'antar_jemput',
      chatbotApiService: _FakeChatbotApiService(),
      customerOrderRepository: fakeOrders,
    );

    await _sendMessage(tester, 'Konfirmasi');

    expect(fakeOrders.fetchOrdersCallCount, greaterThan(0));
    expect(
      find.textContaining('order antar jemput berhasil dibuat'),
      findsNothing,
    );
    expect(
      find.textContaining('Halo! Saya BangBot untuk layanan Antar Jemput'),
      findsOneWidget,
    );
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
      action: 'Atur Lokasi Ambil/Tujuan',
    ),
    'nitip': (
      message: 'Alamat antar utama kamu sudah tersimpan',
      action: 'Pilih Alamat Antar',
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
      expect(find.text('Atur Lokasi Jemput/Tujuan'), findsNothing);
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
    expect(find.text('Atur Lokasi Ambil/Tujuan'), findsWidgets);
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

    final notifier = container.read(
      chatbotConversationProvider('kurir').notifier,
    );
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

    final state = container.read(chatbotConversationProvider('kurir'));

    expect(fakeService.patchLocationCallCount, 1);
    expect(fakeService.lastPatchTarget, 'pickup');
    expect(state.messages.last.text, contains('Draft map pin diterima'));
    expect(state.errorMessage, isNull);
  });

  test('nitip delivery map patch keeps existing draft response', () async {
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

    final notifier = container.read(
      chatbotConversationProvider('nitip').notifier,
    );
    await notifier.bootstrap(
      serviceType: 'nitip',
      welcomeMessage: 'Halo nitip',
    );
    await notifier.sendMessage(
      'draft nitip merchant siap',
      serviceType: 'nitip',
    );

    await notifier.applyMapPinAction(
      serviceType: 'nitip',
      target: 'delivery',
      latitude: -7.011,
      longitude: 110.411,
      address: 'Alamat Antar Baru',
    );

    final state = container.read(chatbotConversationProvider('nitip'));
    final lastMessage = state.messages.last;

    expect(fakeService.patchLocationCallCount, 1);
    expect(fakeService.lastPatchTarget, 'delivery');
    expect(lastMessage.text, contains('Draft Nitip tempat pertama sudah aman'));
    expect(lastMessage.text, contains('Kedai Tinari'));
    expect(lastMessage.text, contains('Alamat Antar Baru'));
    expect(lastMessage.text, isNot(contains('Sekarang pilih toko/resto')));
    expect(
      lastMessage.actionHints.map((hint) => hint.label),
      contains('Ganti Alamat Antar'),
    );
  });

  testWidgets('nitip delivery picker forwards street address', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeChatbotApiService();
    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: fakeService,
    );

    await _sendMessage(tester, 'draft nitip merchant siap');
    final deliveryButton = _filledIconButtonWithText('Ganti Alamat Antar');
    _expectEnabledFilledAction(
      tester,
      label: 'Ganti Alamat Antar',
      backgroundColor: AppColors.primary,
    );
    await tester.ensureVisible(deliveryButton);
    await _pumpChatbotFrame(tester);
    await tester.tap(deliveryButton);
    await _pumpChatbotFrame(tester);

    expect(find.text('Picker Alamat Antar'), findsOneWidget);

    await tester.tap(find.text('Simpan Jalan Antar'));
    await _pumpChatbotFrame(tester);

    expect(fakeService.patchLocationCallCount, 1);
    expect(fakeService.lastPatchTarget, 'delivery');
    expect(fakeService.lastPatchAddress, 'Jl. Sraten Raya No. 10');
    expect(find.textContaining('Jl. Sraten Raya No. 10'), findsOneWidget);
    expect(find.textContaining('-7.011'), findsNothing);
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

    final notifier = container.read(
      chatbotConversationProvider('kurir').notifier,
    );
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

    final state = container.read(chatbotConversationProvider('kurir'));

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

    final notifier = container.read(
      chatbotConversationProvider('antar_jemput').notifier,
    );
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

  testWidgets('quick chat templates show per service type before first message', (
    WidgetTester tester,
  ) async {
    const expectedTemplates = <String, List<String>>{
      'kurir': [
        'Anter [barang] ke [tujuan]',
        'Kirim [barang] dari [lokasi] ke [tujuan]',
        'Ambil / Tujuan / Barang',
      ],
      'antar_jemput': [
        'Antar saya ke [tujuan]',
        'Jemput saya di [lokasi], antar ke [tujuan]',
      ],
      'nitip': [
        'Beli di resto + menu',
        'Lihat menu [resto]',
        'Rekomendasi makanan dong',
      ],
    };

    for (final entry in expectedTemplates.entries) {
      await _pumpChatbot(
        tester,
        serviceType: entry.key,
        chatbotApiService: _FakeChatbotApiService(),
      );

      for (final label in entry.value) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'Template "$label" missing for ${entry.key}',
        );
      }
    }
  });

  testWidgets('placeholder template fills input with first slot selected', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeChatbotApiService();
    await _pumpChatbot(
      tester,
      serviceType: 'kurir',
      chatbotApiService: fakeService,
    );

    await tester.ensureVisible(find.text('Anter [barang] ke [tujuan]'));
    await tester.tap(find.text('Anter [barang] ke [tujuan]'));
    await _pumpChatbotFrame(tester);

    expect(fakeService.callCount, 0);

    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    expect(controller.text, 'Anter [barang] ke [tujuan]');
    expect(
      controller.selection,
      const TextSelection(baseOffset: 6, extentOffset: 14),
    );

    expect(find.text('Kirim [barang] dari [lokasi] ke [tujuan]'), findsOneWidget);
  });

  testWidgets('full sentence template sends immediately', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeChatbotApiService();
    await _pumpChatbot(
      tester,
      serviceType: 'nitip',
      chatbotApiService: fakeService,
    );

    await tester.ensureVisible(find.text('Rekomendasi makanan dong'));
    await tester.tap(find.text('Rekomendasi makanan dong'));
    await _pumpChatbotFrame(tester);

    expect(fakeService.callCount, 1);
    expect(fakeService.lastMessage, 'Rekomendasi makanan dong');
    expect(fakeService.lastServiceType, 'nitip');
    expect(find.text('Beli di resto + menu'), findsNothing);
    expect(find.text('Lihat menu [resto]'), findsNothing);
  });

  testWidgets('quick chat templates disappear after first user message', (
    WidgetTester tester,
  ) async {
    await _pumpChatbot(
      tester,
      serviceType: 'kurir',
      chatbotApiService: _FakeChatbotApiService(),
    );

    await _sendMessage(tester, 'kirim laptop ke polines');

    expect(find.text('Anter [barang] ke [tujuan]'), findsNothing);
    expect(find.text('Kirim [barang] dari [lokasi] ke [tujuan]'), findsNothing);
    expect(find.text('Ambil / Tujuan / Barang'), findsNothing);
  });

  testWidgets('multi-line chip fills input with full body and first slot', (
    WidgetTester tester,
  ) async {
    final fakeService = _FakeChatbotApiService();
    await _pumpChatbot(
      tester,
      serviceType: 'kurir',
      chatbotApiService: fakeService,
    );

    await tester.ensureVisible(find.text('Ambil / Tujuan / Barang'));
    await tester.tap(find.text('Ambil / Tujuan / Barang'));
    await _pumpChatbotFrame(tester);

    // Chip fills input (does not send) with the full multi-line body.
    expect(fakeService.callCount, 0);
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    expect(
      controller.text,
      'Ambil: [lokasi ambil]\nTujuan: [lokasi tujuan]\nBarang: [nama barang]',
    );
    // First placeholder "[lokasi ambil]" selected (after "Ambil: ").
    expect(
      controller.selection,
      const TextSelection(baseOffset: 7, extentOffset: 21),
    );
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

Finder _filledIconButtonWithText(String label) {
  return find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is FilledButton),
  );
}

void _expectEnabledFilledAction(
  WidgetTester tester, {
  required String label,
  required Color backgroundColor,
}) {
  final finder = _filledIconButtonWithText(label);
  final button = tester.widget<FilledButton>(finder);

  expect(button.onPressed, isNotNull);
  expect(
    button.style?.backgroundColor?.resolve(<WidgetState>{}),
    backgroundColor,
  );
  expect(
    button.style?.foregroundColor?.resolve(<WidgetState>{}),
    AppColors.white,
  );
  expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
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
  List<ShoppingMerchantPickerResult>? merchantPickerResults,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});

  var merchantPickerResultIndex = 0;
  ShoppingMerchantPickerResult nextMerchantPickerResult() {
    final queuedResults = merchantPickerResults;
    if (queuedResults != null && queuedResults.isNotEmpty) {
      final index = merchantPickerResultIndex
          .clamp(0, queuedResults.length - 1)
          .toInt();
      merchantPickerResultIndex += 1;
      return queuedResults[index];
    }

    return merchantPickerResult ??
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
  }

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
        path: '/addresses/location-picker',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Picker Alamat Antar'),
                  ElevatedButton(
                    onPressed: () {
                      context.pop(
                        const AddressLocationPickerResult(
                          latitude: -7.011,
                          longitude: 110.411,
                          source: 'map_pin',
                          address: 'Jl. Sraten Raya No. 10',
                        ),
                      );
                    },
                    child: const Text('Simpan Jalan Antar'),
                  ),
                ],
              ),
            ),
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
        path: '/route-location-picker',
        builder: (BuildContext context, GoRouterState state) {
          final extra = state.extra;
          final title = extra is RouteLocationPickerArgs
              ? extra.title
              : 'Route Picker';
          return Scaffold(body: Center(child: Text(title)));
        },
      ),
      GoRoute(
        path: '/chatbot/shopping/merchant-picker',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  context.pop(nextMerchantPickerResult());
                },
                child: const Text('Pilih Kedai Kedua'),
              ),
            ),
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
                  context.pop(nextMerchantPickerResult());
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

CustomerOrderSummaryModel _buildOrderSummary({
  required int id,
  required String statusCode,
  required String statusLabel,
  required bool isTerminalStatus,
}) {
  return CustomerOrderSummaryModel(
    id: id,
    orderNumber: 'BD-260623-$id',
    serviceTypeCode: 'ride',
    serviceTypeLabel: 'Antar Jemput',
    restaurantName: '',
    itemsSummary: 'Antar jemput',
    totalAmount: 9000,
    statusCode: statusCode,
    statusLabel: statusLabel,
    isTerminalStatus: isTerminalStatus,
    createdAt: DateTime(2026, 6, 23, 10),
    estimatedDelivery: null,
    deliveryAddress: 'Alun-Alun Salatiga',
    paymentStatus: 'paid',
    paymentMethod: 'COD',
  );
}

class _FakeCustomerOrderRepository implements CustomerOrderRepository {
  _FakeCustomerOrderRepository({
    this.orders = const <CustomerOrderSummaryModel>[],
    this.menusByMerchantId = const <int, List<ShoppingMenuOption>>{},
  });

  final List<CustomerOrderSummaryModel> orders;
  final Map<int, List<ShoppingMenuOption>> menusByMerchantId;
  int fetchOrdersCallCount = 0;
  int searchMenuCallCount = 0;
  int? lastMerchantId;
  String? lastMenuQuery;

  @override
  Future<List<CustomerOrderSummaryModel>> fetchOrders({
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    fetchOrdersCallCount += 1;
    return orders;
  }

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
  _FakeChatbotApiService({this.failingMessages = const <String>{}})
    : super(ApiClient());

  final Set<String> failingMessages;

  int callCount = 0;
  int patchLocationCallCount = 0;
  int patchLocationsCallCount = 0;
  int patchMerchantCallCount = 0;
  int clearSessionCallCount = 0;
  String? lastServiceType;
  String? lastSessionId;
  String? lastPatchTarget;
  String? lastPatchAddress;
  String? lastMerchantMode;
  int? lastMerchantId;
  String? lastReplaceTargetStopId;
  String? lastClearedSessionId;
  String? lastMessage;
  List<String> lastRouteTargets = const <String>[];
  List<String?> lastRouteAddresses = const <String?>[];

  /// Opt-in: bila diisi, respons patch merchant menyertakan draft belanja
  /// dengan stops (mengandung `stop_id` + `is_active`) supaya menu selector
  /// mendapat targetStopId — mensimulasikan kontrak backend sebenarnya.
  List<Map<String, dynamic>>? merchantStopsPayload;

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
    if (normalized == 'trigger error' || failingMessages.contains(normalized)) {
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
            'merchant': {'name': 'Alfamart Bang Deliv Point'},
            'delivery': {'address': 'FISIP UNDIP'},
            'items': [
              {'name': 'kopi', 'quantity': 1, 'unit_price': 0},
            ],
          },
          'validation': {
            'is_valid_order': true,
            'rejection_reasons': [],
            'missing_fields': [],
            'next_actions': [
              'SET_PAYMENT_COD',
              'SET_PAYMENT_TRANSFER',
              'RESET_DESTINATION',
              'CHANGE_PICKUP',
            ],
          },
          'action_payloads': {
            'SET_PAYMENT_COD': {'label': 'COD', 'message': 'COD'},
            'SET_PAYMENT_TRANSFER': {'label': 'QRIS', 'message': 'QRIS'},
            'RESET_DESTINATION': {
              'label': 'Ubah Tujuan',
              'message': 'Ubah Tujuan',
            },
            'CHANGE_PICKUP': {
              'target': 'pickup',
              'label': serviceType == 'kurir'
                  ? 'Ubah Lokasi Ambil'
                  : 'Ubah Lokasi Jemput',
              'initial_latitude': -7.3289,
              'initial_longitude': 110.5001,
            },
          },
          'order': {'created': false, 'payment_method': null},
        },
      });
    }

    if (serviceType == 'nitip' && normalized == 'lihat menu nasgor gajah') {
      return ChatbotResult.fromApiJson({
        'status': 'success',
        'session_id': sessionId,
        'service_context': {'service_type': serviceType},
        'model_used': 'deterministic-assistant',
        'data': {
          'intent': 'shopping_order',
          'assistant_text': 'Ini menu Nasgor Gajah. Pilih item yang ingin dibeli.',
          'menu_selector': {
            'merchant_id': 77,
            'merchant_name': 'Nasgor Gajah',
            'mode': 'select',
          },
          'shopping': {
            'ready_to_confirm': false,
            'merchant': {'id': 77, 'name': 'Nasgor Gajah'},
            'stops': [
              {
                'index': 1,
                'is_active': true,
                'merchant': {'id': 77, 'name': 'Nasgor Gajah'},
                'items': <dynamic>[],
                'ready': false,
              },
            ],
          },
          'validation': {
            'is_valid_order': false,
            'rejection_reasons': <dynamic>[],
            'missing_fields': ['items'],
            'next_actions': <dynamic>[],
          },
          'order': {'created': false},
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
              'Draft Nitip tempat pertama sudah aman.\n\n'
              'Tempat\n'
              'Kedai Tinari\n\n'
              'Daftar belanja\n'
              '1. 1x ramen mala (harga sesuai nota)\n'
              '2. 1x es jeruk (harga sesuai nota)\n\n'
              'Alamat antar\n'
              'FISIP UNDIP\n\n'
              'Estimasi ongkir sementara: Rp 9.000\n'
              'Harga barang: Sesuai nota\n'
              'Estimasi total sementara: Menunggu harga barang\n'
              'Metode pembayaran: pilih COD atau QRIS.\n\n'
              'Mau tambah tempat lain? Pilih tempatnya dulu.\n'
              'Contoh setelah tempat berikutnya dipilih:\n'
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
              'label': 'Tambah Tempat',
              'mode': 'add',
              'initial_latitude': -7.0509,
              'initial_longitude': 110.4315,
            },
            'OPEN_MAP_PICKER_DELIVERY': {
              'target': 'delivery',
              'label': 'Ganti Alamat Antar',
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
            'rejection_reasons': ['Tempat belum dipilih.'],
            'missing_fields': ['merchant'],
            'next_actions': ['OPEN_MERCHANT_PICKER'],
          },
          'action_payloads': {
            'OPEN_MERCHANT_PICKER': {
              'label': 'Pilih Tempat di Map',
              'initial_latitude': -7.0509,
              'initial_longitude': 110.4315,
            },
          },
          'order': {'created': false, 'payment_method': null},
        },
      });
    }

    if (serviceType == 'nitip' && normalized == 'nitip apa enaknya') {
      return ChatbotResult.fromApiJson({
        'status': 'success',
        'session_id': sessionId,
        'service_context': {'service_type': serviceType},
        'model_used': 'deterministic-assistant',
        'data': {
          'intent': 'shopping_order',
          'assistant_text':
              'Berikut pilihan dari restoran terdekat dengan alamat antarmu:\n\n'
              '1. Resto Paling Dekat (sekitar 0,25 km)\n'
              '- Nasi Goreng\n'
              '- Es Teh\n\n'
              'Sebutkan nama restoran yang ingin dipakai, lalu tulis menu dan jumlah pesanannya.',
          'shopping': {
            'ready_to_confirm': false,
            'payment_method': null,
            'merchant': {'id': null, 'name': null},
            'delivery': {'address': 'FISIP UNDIP'},
            'items': <Map<String, dynamic>>[],
            'stops': <Map<String, dynamic>>[],
          },
          'validation': {
            'is_valid_order': false,
            'rejection_reasons': ['Tempat belum dipilih.'],
            'missing_fields': ['merchant', 'items'],
            'next_actions': ['OPEN_MERCHANT_PICKER'],
          },
          'action_payloads': {
            'OPEN_MERCHANT_PICKER': {
              'label': 'Pilih Tempat di Map',
              'mode': 'select',
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
            'merchant': {'name': 'Alfamart Bang Deliv Point'},
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
            'merchant': {'name': 'Alfamart Bang Deliv Point'},
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
              'CHANGE_PICKUP',
            ],
          },
          'action_payloads': {
            'SET_PAYMENT_COD': {'label': 'COD', 'message': 'COD'},
            'SET_PAYMENT_TRANSFER': {'label': 'QRIS', 'message': 'QRIS'},
            'RESET_DESTINATION': {
              'label': 'Ubah Tujuan',
              'message': 'Ubah Tujuan',
            },
            'CHANGE_PICKUP': {
              'target': 'pickup',
              'label': serviceType == 'kurir'
                  ? 'Ubah Lokasi Ambil'
                  : 'Ubah Lokasi Jemput',
              'initial_latitude': -7.3289,
              'initial_longitude': 110.5001,
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
    lastPatchAddress = address;

    if (serviceType == 'nitip') {
      final deliveryAddress = address ?? 'Pin baru';

      return ChatbotResult.fromApiJson({
        'status': 'success',
        'session_id': sessionId,
        'service_context': {'service_type': serviceType},
        'model_used': 'map-pin-action',
        'data': {
          'intent': 'shopping_order',
          'assistant_text':
              'Draft Nitip tempat pertama sudah aman.\n\n'
              'Tempat\n'
              'Kedai Tinari\n\n'
              'Daftar belanja\n'
              '1. 1x ramen mala (harga sesuai nota)\n'
              '2. 1x es jeruk (harga sesuai nota)\n\n'
              'Alamat antar\n'
              '$deliveryAddress\n\n'
              'Estimasi ongkir sementara: Rp 11.000\n'
              'Harga barang: Sesuai nota\n'
              'Estimasi total sementara: Menunggu harga barang\n'
              'Metode pembayaran: pilih COD atau QRIS.\n\n'
              'Mau tambah tempat lain? Pilih tempatnya dulu.\n'
              'Contoh setelah tempat berikutnya dipilih:\n'
              '- susu 1\n'
              '- roti tawar 2\n\n'
              'Ketik "konfirmasi" kalau sudah oke.',
          'shopping': {
            'ready_to_confirm': true,
            'payment_method': null,
            'merchant': {'name': 'Kedai Tinari'},
            'delivery': {'address': deliveryAddress},
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
              'label': 'Tambah Tempat',
              'mode': 'add',
            },
            'OPEN_MAP_PICKER_DELIVERY': {
              'target': 'delivery',
              'label': 'Ganti Alamat Antar',
            },
            'SET_PAYMENT_COD': {'label': 'COD', 'message': 'COD'},
            'SET_PAYMENT_TRANSFER': {'label': 'QRIS', 'message': 'QRIS'},
          },
          'order': {'created': false, 'payment_method': null},
        },
      });
    }

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
    String? replaceTargetStopId,
  }) async {
    patchMerchantCallCount += 1;
    lastServiceType = serviceType;
    lastMerchantMode = mode;
    lastMerchantId = merchantId;
    lastReplaceTargetStopId = replaceTargetStopId;

    return ChatbotResult.fromApiJson({
      'status': 'success',
      'session_id': sessionId,
      'service_context': {'service_type': serviceType},
      'model_used': 'merchant-picker-action',
      'data': {
        'intent': 'shopping_order',
        'assistant_text': mode == 'add'
            ? 'Draft Nitip belum lengkap. Lengkapi: items.\n\nTempat\nKedai Kedua\n\nTulis item dan jumlah untuk tempat ini.\nContoh:\n- susu 1\n- roti tawar 2\n- air mineral 1'
            : 'Draft Nitip belum lengkap. Lengkapi: items.\n\nTempat\nKedai Kedua\n\nTulis item dan jumlah untuk tempat ini.\nContoh:\n- susu 1\n- roti tawar 2\n- air mineral 1',
        'validation': {
          'is_valid_order': false,
          'rejection_reasons': [],
          'missing_fields': ['items'],
          'next_actions': [],
        },
        if (merchantStopsPayload != null)
          'shopping': <String, dynamic>{'stops': merchantStopsPayload},
        'order': {'created': false},
      },
    });
  }
}
