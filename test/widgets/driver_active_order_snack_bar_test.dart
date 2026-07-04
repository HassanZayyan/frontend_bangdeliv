import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/config/app_colors.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/widgets/driver_active_order_widget_helpers.dart';
import 'package:frontend_bangdeliv/features/navigation/presentation/widgets/bang_floating_bottom_nav_bar.dart';

void main() {
  testWidgets(
    'active order snackbar appears above sticky action bar with success color',
    (tester) async {
      tester.view.physicalSize = const Size(390, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final stickyActionBarKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverActiveOrderSnackBarScope(
              stickyActionBarKey: stickyActionBarKey,
              child: Scaffold(
                body: Builder(
                  builder: (context) {
                    return Center(
                      child: FilledButton(
                        onPressed: () {
                          showDriverActiveOrderSnackBar(
                            context,
                            message: 'Aksi berhasil.',
                          );
                        },
                        child: const Text('Show toast'),
                      ),
                    );
                  },
                ),
                bottomNavigationBar: SizedBox(
                  key: stickyActionBarKey,
                  height: 142,
                  child: const ColoredBox(
                    color: AppColors.white,
                    child: Center(child: Text('Sticky action')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show toast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      final stickyTop = tester.getTopLeft(find.byKey(stickyActionBarKey)).dy;
      final snackBarMaterial = find
          .ancestor(
            of: find.text('Aksi berhasil.'),
            matching: find.byType(Material),
          )
          .first;
      final snackBarBottom = tester.getBottomLeft(snackBarMaterial).dy;
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));

      expect(snackBar.backgroundColor, AppColors.success);
      expect(snackBarBottom, lessThan(stickyTop));
      expect(
        stickyTop - snackBarBottom,
        moreOrLessEquals(BangFloatingBottomNavBar.snackBarGap, epsilon: 1),
      );
    },
  );
}
