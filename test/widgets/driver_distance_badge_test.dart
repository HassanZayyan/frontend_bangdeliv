import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/widgets/driver_distance_badge.dart';

void main() {
  testWidgets('DriverDistanceBadge shows backend distance label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DriverDistanceBadge(
            dispatch: DriverDispatchModel(
              distanceLabel: '1,3 km dari titik jemput',
              distanceBucket: 'NEAR',
              locationFresh: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('1,3 km dari titik jemput'), findsOneWidget);
    expect(find.byIcon(Icons.near_me_outlined), findsOneWidget);
  });

  testWidgets('DriverDistanceBadge shows unknown fallback', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DriverDistanceBadge(dispatch: null)),
      ),
    );

    expect(find.text('Jarak belum tersedia'), findsOneWidget);
  });
}
