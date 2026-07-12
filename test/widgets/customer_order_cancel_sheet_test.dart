import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/features/orders/presentation/widgets/customer_order_cancel_sheet.dart';

void main() {
  testWidgets('quick cancellation reason is returned unchanged', (
    tester,
  ) async {
    String? selectedReason;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                selectedReason = await showCustomerOrderCancelSheet(context);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final cancelButton = find.widgetWithText(
      ElevatedButton,
      'Batalkan Pesanan',
    );
    expect(tester.widget<ElevatedButton>(cancelButton).onPressed, isNull);

    await tester.tap(find.text('Alamat salah'));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(cancelButton).onPressed, isNotNull);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();
    expect(selectedReason, 'Alamat salah');
  });

  testWidgets('custom cancellation reason is required and returned', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    String? selectedReason;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                selectedReason = await showCustomerOrderCancelSheet(context);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();

    final cancelButton = find.widgetWithText(
      ElevatedButton,
      'Batalkan Pesanan',
    );
    expect(tester.widget<ElevatedButton>(cancelButton).onPressed, isNull);

    await tester.enterText(
      find.byType(TextField),
      'Penerima tidak berada di lokasi',
    );
    await tester.pump();
    expect(tester.widget<ElevatedButton>(cancelButton).onPressed, isNotNull);

    await tester.tap(cancelButton);
    await tester.pumpAndSettle();
    expect(selectedReason, 'Penerima tidak berada di lokasi');
  });
}
