import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/features/chatbot/presentation/widgets/chatbot_menu_selector.dart';
import 'package:frontend_bangdeliv/models/chatbot_launch_args.dart';
import 'package:frontend_bangdeliv/widgets/bang_ui.dart';

List<ChatbotMenuSuggestion> _buildMenus(int count, {String? lastName}) {
  return List<ChatbotMenuSuggestion>.generate(count, (index) {
    final name = index == count - 1 && lastName != null
        ? lastName
        : 'Menu ${index + 1}';
    return ChatbotMenuSuggestion(
      name: name,
      presetMessage: '$name 1',
      priceLabel: 'Rp10.000',
    );
  });
}

Widget _wrapSelector({
  required List<ChatbotMenuSuggestion> menus,
  List<int>? quantities,
  String merchantName = 'Warung Uji',
  void Function(int index, int delta)? onQuantityDelta,
  VoidCallback? onChangeMerchant,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ChatbotMenuSelector(
          merchantName: merchantName,
          menus: menus,
          quantities: quantities ?? List<int>.filled(menus.length, 0),
          onQuantityDelta: onQuantityDelta ?? (_, _) {},
          onChangeMerchant: onChangeMerchant ?? () {},
        ),
      ),
    ),
  );
}

Finder _searchFieldFinder() {
  return find.descendant(
    of: find.byType(BangSearchField),
    matching: find.byType(TextField),
  );
}

void main() {
  testWidgets('12 menu: tampil 10 pertama plus tombol tampilkan lainnya', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapSelector(menus: _buildMenus(12)));

    for (var i = 1; i <= 10; i++) {
      expect(find.text('Menu $i'), findsOneWidget);
    }
    expect(find.text('Menu 11'), findsNothing);
    expect(find.text('Menu 12'), findsNothing);
    expect(find.text('Tampilkan 2 menu lainnya'), findsOneWidget);

    await tester.ensureVisible(find.text('Tampilkan 2 menu lainnya'));
    await tester.tap(find.text('Tampilkan 2 menu lainnya'));
    await tester.pump();

    expect(find.text('Menu 11'), findsOneWidget);
    expect(find.text('Menu 12'), findsOneWidget);
    expect(find.text('Tampilkan 2 menu lainnya'), findsNothing);
  });

  testWidgets('3 menu: tanpa kolom search dan tanpa tombol tampilkan', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapSelector(menus: _buildMenus(3)));

    expect(find.byType(BangSearchField), findsNothing);
    expect(find.textContaining('menu lainnya'), findsNothing);
    expect(find.text('Menu 1'), findsOneWidget);
    expect(find.text('Menu 3'), findsOneWidget);
  });

  testWidgets('search memfilter termasuk item di luar 10 pertama', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapSelector(menus: _buildMenus(12, lastName: 'Bakso Spesial')),
    );

    expect(find.text('Bakso Spesial'), findsNothing);

    await tester.enterText(_searchFieldFinder(), 'bakso');
    await tester.pump();

    expect(find.text('Bakso Spesial'), findsOneWidget);
    expect(find.text('Menu 1'), findsNothing);
    expect(find.textContaining('menu lainnya'), findsNothing);
  });

  testWidgets('tap stepper pada baris terfilter memakai indeks list penuh', (
    tester,
  ) async {
    final calls = <List<int>>[];
    await tester.pumpWidget(
      _wrapSelector(
        menus: _buildMenus(12, lastName: 'Bakso Spesial'),
        onQuantityDelta: (index, delta) => calls.add([index, delta]),
      ),
    );

    await tester.enterText(_searchFieldFinder(), 'bakso');
    await tester.pump();

    await tester.tap(find.byTooltip('Tambah Bakso Spesial'));
    await tester.pump();

    expect(calls, [
      [11, 1],
    ]);
  });

  testWidgets('qty item tersembunyi bertahan melewati perubahan filter', (
    tester,
  ) async {
    final menus = _buildMenus(12);
    final quantities = List<int>.filled(12, 0)..[10] = 2;

    await tester.pumpWidget(
      _wrapSelector(menus: menus, quantities: quantities),
    );

    expect(find.text('Menu 11'), findsNothing);

    await tester.enterText(_searchFieldFinder(), 'tidak ada menu ini');
    await tester.pump();
    expect(find.textContaining('Menu tidak ditemukan'), findsOneWidget);

    await tester.enterText(_searchFieldFinder(), 'menu 11');
    await tester.pump();

    expect(find.text('Menu 11'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('query tanpa hasil menampilkan pesan menu tidak ditemukan', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapSelector(menus: _buildMenus(12)));

    await tester.enterText(_searchFieldFinder(), 'zzz');
    await tester.pump();

    expect(
      find.text('Menu tidak ditemukan. Coba kata lain atau tulis item manual.'),
      findsOneWidget,
    );
    expect(find.text('Menu 1'), findsNothing);
  });

  testWidgets('ganti merchant mereset search dan kembali ke 10 pertama', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapSelector(
        merchantName: 'Warung A',
        menus: _buildMenus(12, lastName: 'Bakso Spesial'),
      ),
    );

    await tester.enterText(_searchFieldFinder(), 'bakso');
    await tester.pump();
    expect(find.text('Bakso Spesial'), findsOneWidget);

    final newMenus = List<ChatbotMenuSuggestion>.generate(
      13,
      (index) => ChatbotMenuSuggestion(
        name: 'Sate ${index + 1}',
        presetMessage: 'Sate ${index + 1} 1',
      ),
    );
    await tester.pumpWidget(
      _wrapSelector(merchantName: 'Warung B', menus: newMenus),
    );
    await tester.pump();

    expect(
      tester.widget<TextField>(_searchFieldFinder()).controller!.text,
      isEmpty,
    );
    expect(find.text('Sate 1'), findsOneWidget);
    expect(find.text('Sate 10'), findsOneWidget);
    expect(find.text('Sate 13'), findsNothing);
    expect(find.text('Tampilkan 3 menu lainnya'), findsOneWidget);
  });
}
