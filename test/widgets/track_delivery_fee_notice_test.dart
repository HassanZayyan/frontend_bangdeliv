import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/features/tracking/presentation/widgets/track_order_widgets.dart';

void main() {
  testWidgets('delivery fee notice shows reason separately', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrackDeliveryFeeNotice(
            text: 'Ongkir diperbarui menjadi Rp 7.000.',
            reason: 'BBM naik.',
          ),
        ),
      ),
    );

    expect(find.text('Ongkir diperbarui menjadi Rp 7.000.'), findsOneWidget);
    expect(find.text('Alasan: BBM naik.'), findsOneWidget);
    expect(find.textContaining('driver'), findsNothing);
  });
}
