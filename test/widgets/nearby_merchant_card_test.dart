import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/config/app_theme.dart';
import 'package:frontend_bangdeliv/features/home/presentation/widgets/nearby_merchant_card.dart';
import 'package:frontend_bangdeliv/models/merchant_model.dart';

void main() {
  testWidgets(
    'distance label keeps same vertical position for one and two line names',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 344,
                height: 230,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: NearbyMerchantCard(
                        merchant: MerchantModel(
                          id: 'short',
                          name: "Rendy's Chicken",
                          distance: '60 m',
                          imageUrl: '',
                        ),
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NearbyMerchantCard(
                        merchant: MerchantModel(
                          id: 'long',
                          name: 'Martabak Bangka Idola Cabang Krenceng',
                          distance: '140 m',
                          imageUrl: '',
                        ),
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final shortDistanceTop = tester.getTopLeft(find.text('60 m')).dy;
      final longDistanceTop = tester.getTopLeft(find.text('140 m')).dy;

      expect(shortDistanceTop, moreOrLessEquals(longDistanceTop, epsilon: 0.1));
    },
  );
}
