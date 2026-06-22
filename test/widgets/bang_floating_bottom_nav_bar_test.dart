import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/config/app_colors.dart';
import 'package:frontend_bangdeliv/features/navigation/presentation/widgets/bang_floating_bottom_nav_bar.dart';

void main() {
  testWidgets('renders floating nav items, badge, and handles taps', (
    tester,
  ) async {
    var selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              bottomNavigationBar: BangFloatingBottomNavBar(
                currentIndex: selectedIndex,
                onTap: (index) => setState(() => selectedIndex = index),
                items: const [
                  BangFloatingNavItem(
                    icon: Icons.home_filled,
                    label: 'Beranda',
                  ),
                  BangFloatingNavItem(
                    icon: Icons.assignment_rounded,
                    label: 'Orderan',
                    badgeCount: 3,
                  ),
                  BangFloatingNavItem(icon: Icons.history, label: 'Riwayat'),
                  BangFloatingNavItem(
                    icon: Icons.person_outline,
                    label: 'Profil',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Orderan'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(selectedIndex, 3);
  });

  testWidgets('renders a subtle selected item indicator', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BangFloatingBottomNavBar(
            currentIndex: 0,
            onTap: _noopTap,
            items: [
              BangFloatingNavItem(icon: Icons.home_filled, label: 'Beranda'),
              BangFloatingNavItem(
                icon: Icons.assignment_rounded,
                label: 'Aktivitas',
              ),
              BangFloatingNavItem(icon: Icons.history, label: 'Riwayat'),
              BangFloatingNavItem(icon: Icons.person_outline, label: 'Profil'),
            ],
          ),
        ),
      ),
    );

    final activeIndicators = tester.widgetList<AnimatedContainer>(
      find.byWidgetPredicate((widget) {
        if (widget is! AnimatedContainer) {
          return false;
        }
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.color == AppColors.primaryLight;
      }),
    );

    expect(activeIndicators, hasLength(1));
  });

  testWidgets('scales the selected icon without changing the nav slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BangFloatingBottomNavBar(
            currentIndex: 0,
            onTap: _noopTap,
            items: [
              BangFloatingNavItem(icon: Icons.home_filled, label: 'Beranda'),
              BangFloatingNavItem(
                icon: Icons.assignment_rounded,
                label: 'Aktivitas',
              ),
              BangFloatingNavItem(icon: Icons.person_outline, label: 'Profil'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final iconScales = tester
        .widgetList<Transform>(find.byType(Transform))
        .map((widget) => widget.transform.storage[0])
        .where((scale) => scale >= 1.0)
        .toList(growable: false);
    final maxScale = iconScales.reduce((value, scale) {
      return value > scale ? value : scale;
    });

    expect(maxScale, greaterThan(1.05));
    expect(tester.getSize(find.text('Beranda')).height, lessThan(16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses activeIcon for the selected profile item', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BangFloatingBottomNavBar(
            currentIndex: 2,
            onTap: _noopTap,
            items: [
              BangFloatingNavItem(icon: Icons.home_filled, label: 'Beranda'),
              BangFloatingNavItem(
                icon: Icons.assignment_rounded,
                label: 'Aktivitas',
              ),
              BangFloatingNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);
  });

  testWidgets(
    'host pins the floating nav to the bottom without wrapper paint',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BangFloatingBottomNavHost(
              navigationBar: BangFloatingBottomNavBar(
                currentIndex: 0,
                onTap: _noopTap,
                items: [
                  BangFloatingNavItem(
                    icon: Icons.home_filled,
                    label: 'Beranda',
                  ),
                  BangFloatingNavItem(
                    icon: Icons.assignment_rounded,
                    label: 'Aktivitas',
                  ),
                  BangFloatingNavItem(icon: Icons.history, label: 'Riwayat'),
                  BangFloatingNavItem(
                    icon: Icons.person_outline,
                    label: 'Profil',
                  ),
                ],
              ),
              child: SizedBox.expand(
                key: ValueKey('content-space'),
                child: ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
      );

      final contentBottom = tester.getBottomLeft(
        find.byKey(const ValueKey('content-space')),
      );
      final logicalHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      expect(contentBottom.dy, logicalHeight);
      expect(tester.getTopLeft(find.text('Beranda')).dy, greaterThan(540));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('overlay theme keeps snackbars above the floating nav', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BangFloatingBottomNavOverlayTheme(
          child: Scaffold(
            body: BangFloatingBottomNavHost(
              navigationBar: const BangFloatingBottomNavBar(
                currentIndex: 0,
                onTap: _noopTap,
                items: [
                  BangFloatingNavItem(
                    icon: Icons.home_filled,
                    label: 'Beranda',
                  ),
                  BangFloatingNavItem(
                    icon: Icons.assignment_rounded,
                    label: 'Aktivitas',
                  ),
                  BangFloatingNavItem(
                    icon: Icons.person_outline,
                    label: 'Profil',
                  ),
                ],
              ),
              child: Builder(
                builder: (context) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Status tersimpan')),
                        );
                      },
                      child: const Text('Show snackbar'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show snackbar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    final navMaterial = find
        .ancestor(of: find.text('Beranda'), matching: find.byType(Material))
        .first;
    final navTop = tester.getTopLeft(navMaterial).dy;
    final snackBarMaterial = find
        .ancestor(
          of: find.text('Status tersimpan'),
          matching: find.byType(Material),
        )
        .first;
    final snackBarBottom = tester.getBottomLeft(snackBarMaterial).dy;
    final visualGap = navTop - snackBarBottom;

    expect(snackBarBottom, lessThan(navTop));
    expect(
      visualGap,
      moreOrLessEquals(BangFloatingBottomNavBar.snackBarGap, epsilon: 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('stays compact on narrow screens', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BangFloatingBottomNavHost(
            navigationBar: BangFloatingBottomNavBar(
              currentIndex: 0,
              onTap: _noopTap,
              items: [
                BangFloatingNavItem(icon: Icons.home_filled, label: 'Beranda'),
                BangFloatingNavItem(
                  icon: Icons.assignment_rounded,
                  label: 'Aktivitas',
                ),
                BangFloatingNavItem(icon: Icons.history, label: 'Riwayat'),
                BangFloatingNavItem(
                  icon: Icons.person_outline,
                  label: 'Profil',
                ),
              ],
            ),
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(find.text('Aktivitas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a restrained max width on wide screens', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BangFloatingBottomNavHost(
            navigationBar: BangFloatingBottomNavBar(
              currentIndex: 0,
              onTap: _noopTap,
              items: [
                BangFloatingNavItem(icon: Icons.home_filled, label: 'Beranda'),
                BangFloatingNavItem(
                  icon: Icons.assignment_rounded,
                  label: 'Aktivitas',
                ),
                BangFloatingNavItem(icon: Icons.history, label: 'Riwayat'),
                BangFloatingNavItem(
                  icon: Icons.person_outline,
                  label: 'Profil',
                ),
              ],
            ),
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find
          .ancestor(of: find.text('Beranda'), matching: find.byType(Material))
          .first,
    );
    final barSize = tester.getSize(find.byWidget(material));

    expect(barSize.width, lessThanOrEqualTo(520));
    expect(tester.takeException(), isNull);
  });
}

void _noopTap(int index) {}
