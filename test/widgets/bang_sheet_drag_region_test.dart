import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/core/widgets/bang_sheet_drag_region.dart';

void main() {
  testWidgets('customer header surfaces drag through all configured snaps', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_CustomerSheetHarnessState>();
    await tester.pumpWidget(_CustomerSheetHarness(key: harnessKey));
    await tester.pumpAndSettle();

    final controller = harnessKey.currentState!.sheetController;
    expect(controller.size, closeTo(0.38, 0.01));

    await tester.drag(
      find.byKey(const ValueKey('customer-sheet-handle')),
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();
    expect(controller.size, closeTo(0.62, 0.01));

    await tester.dragFrom(
      tester.getCenter(
        find.byKey(const ValueKey('customer-sheet-blank-space')),
      ),
      const Offset(0, 150),
    );
    await tester.pumpAndSettle();
    expect(controller.size, closeTo(0.38, 0.01));

    await tester.drag(
      find.byKey(const ValueKey('customer-sheet-chip-list')),
      const Offset(0, 260),
    );
    await tester.pumpAndSettle();
    expect(controller.size, closeTo(0.20, 0.01));
  });

  testWidgets('horizontal chip scroll and chip taps remain available', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_CustomerSheetHarnessState>();
    await tester.pumpWidget(_CustomerSheetHarness(key: harnessKey));
    await tester.pumpAndSettle();

    final state = harnessKey.currentState!;
    final initialSize = state.sheetController.size;

    await tester.drag(
      find.byKey(const ValueKey('customer-sheet-chip-list')),
      const Offset(-220, 0),
    );
    await tester.pumpAndSettle();

    expect(state.chipScrollController.offset, greaterThan(0));
    expect(state.sheetController.size, closeTo(initialSize, 0.01));

    await tester.tap(find.text('Tempat 4'));
    await tester.pump();
    expect(state.selectedPoint, 'Tempat 4');
  });
}

class _CustomerSheetHarness extends StatefulWidget {
  const _CustomerSheetHarness({super.key});

  @override
  State<_CustomerSheetHarness> createState() => _CustomerSheetHarnessState();
}

class _CustomerSheetHarnessState extends State<_CustomerSheetHarness> {
  final sheetController = DraggableScrollableController();
  final chipScrollController = ScrollController();
  String selectedPoint = 'Ringkasan';

  static const points = <String>[
    'Ringkasan',
    'Tempat 1',
    'Tempat 2',
    'Tempat 3',
    'Tempat 4',
  ];

  @override
  void dispose() {
    sheetController.dispose();
    chipScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: DraggableScrollableSheet(
          controller: sheetController,
          initialChildSize: 0.38,
          minChildSize: 0.20,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Material(
              child: Column(
                children: [
                  BangSheetDragRegion(
                    controller: sheetController,
                    minExtent: 0.20,
                    maxExtent: 0.92,
                    snapExtents: const [0.20, 0.38, 0.62, 0.92],
                    child: SizedBox(
                      height: 100,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Container(
                            key: const ValueKey('customer-sheet-handle'),
                            width: 48,
                            height: 4,
                            color: Colors.grey,
                          ),
                          const Expanded(
                            child: ColoredBox(
                              key: ValueKey('customer-sheet-blank-space'),
                              color: Colors.transparent,
                            ),
                          ),
                          SizedBox(
                            height: 52,
                            child: ListView.separated(
                              key: const ValueKey('customer-sheet-chip-list'),
                              controller: chipScrollController,
                              scrollDirection: Axis.horizontal,
                              itemCount: points.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final point = points[index];
                                return ChoiceChip(
                                  label: Text(point),
                                  selected: selectedPoint == point,
                                  onSelected: (_) => setState(() {
                                    selectedPoint = point;
                                  }),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: const [SizedBox(height: 1200)],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
