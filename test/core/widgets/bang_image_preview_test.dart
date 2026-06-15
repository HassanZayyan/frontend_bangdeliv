import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/core/widgets/bang_image_preview.dart';

void main() {
  testWidgets('opens network image preview dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.qr_code_2),
              onPressed: () => showBangNetworkImagePreview(
                context,
                imageUrl: 'https://example.test/qris.jpeg',
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.qr_code_2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.textContaining('QRIS'), findsNothing);
  });
}
