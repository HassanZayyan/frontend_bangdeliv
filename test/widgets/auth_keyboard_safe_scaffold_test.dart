import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/widgets/bang_ui.dart';

void main() {
  testWidgets(
    'AuthKeyboardSafeScaffold removes collapsed header while keyboard is open',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              viewInsets: EdgeInsets.only(bottom: 320),
            ),
            child: AuthKeyboardSafeScaffold(
              header: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [SizedBox(height: 48), Text('Collapsed auth header')],
              ),
              headerHeightBuilder: (context, isKeyboardOpen) {
                return isKeyboardOpen ? 0 : 120;
              },
              cardPaddingBuilder: (context, isKeyboardOpen) {
                return const EdgeInsets.all(16);
              },
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text('Scrollable auth form'), SizedBox(height: 520)],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Collapsed auth header'), findsNothing);
      expect(find.text('Scrollable auth form'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
