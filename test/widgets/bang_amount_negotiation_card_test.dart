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
    expect(find.text('Batal'), findsOneWidget);

    final counterButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Tawar'),
    );
    final cancelButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Batal'),
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
}
