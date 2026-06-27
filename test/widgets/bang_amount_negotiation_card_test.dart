import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/core/widgets/bang_amount_negotiation_card.dart';
import 'package:frontend_bangdeliv/core/widgets/bang_counter_amount_dialog.dart';

void main() {
  testWidgets('only the selected negotiation action shows loading', (
    tester,
  ) async {
    var approved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BangAmountNegotiationCard(
            label: 'Harga baru',
            amount: 15000,
            approveLoading: true,
            onApprove: () => approved = true,
            onCounter: () {},
            onCancel: () {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Tawar'), findsOneWidget);
    expect(find.text('Batalkan pesanan'), findsOneWidget);

    final counterButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Tawar'),
    );
    final cancelButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Batalkan pesanan'),
    );

    expect(counterButton.onPressed, isNull);
    expect(cancelButton.onPressed, isNull);
    expect(approved, isFalse);
  });

  testWidgets('counter amount dialog parses formatted rupiah input', (
    tester,
  ) async {
    double? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showBangCounterAmountDialog(
                    context,
                    title: 'Tawar harga',
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Rp 15.000');
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();

    expect(result, 15000);
  });

  testWidgets('delivery fee revision card shows previous amount and reason', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BangAmountNegotiationCard(
            label: 'Revisi ongkir',
            amount: 12000,
            previousAmount: 5000,
            reason: 'BBM naik.',
            onApprove: () {},
            onCounter: () {},
            onCancel: () {},
          ),
        ),
      ),
    );

    expect(find.text('Revisi ongkir'), findsOneWidget);
    expect(find.text('Rp 12.000'), findsOneWidget);
    expect(find.text('Nominal sebelumnya'), findsOneWidget);
    expect(find.text('Rp 5.000'), findsOneWidget);
    expect(find.text('Alasan driver'), findsOneWidget);
    expect(find.text('BBM naik.'), findsOneWidget);

    final previousAmountText = tester.widget<Text>(find.text('Rp 5.000'));
    expect(previousAmountText.style?.fontSize, 13);
    expect(previousAmountText.style?.fontWeight, FontWeight.w800);

    final reasonText = tester.widget<Text>(find.text('BBM naik.'));
    expect(reasonText.style?.fontSize, 13);
    expect(reasonText.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('embedded negotiation card removes leading icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BangAmountNegotiationCard(
            label: 'Konfirmasi revisi ongkir',
            amount: 7000,
            previousAmount: 5000,
            approveLabel: 'Setujui',
            showIcon: false,
            embedded: true,
            onApprove: () {},
            onCounter: () {},
            onCancel: () {},
          ),
        ),
      ),
    );

    expect(find.text('Konfirmasi revisi ongkir'), findsOneWidget);
    expect(find.text('Setujui'), findsOneWidget);
    expect(find.byIcon(Icons.request_quote_outlined), findsNothing);
  });
}
