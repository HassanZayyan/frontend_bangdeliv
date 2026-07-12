import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/widgets/driver_order_sheet_drag_region.dart';

void main() {
  testWidgets('header title, blank space, and chip area drag the sheet', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_SheetDragHarnessState>();
    await tester.pumpWidget(_SheetDragHarness(key: harnessKey));
    await tester.pumpAndSettle();

    final state = harnessKey.currentState!;
    expect(state.sheetController.size, closeTo(0.3, 0.01));

    await tester.drag(find.text('Antar ke tujuan'), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(state.sheetController.size, closeTo(0.6, 0.01));

    await tester.dragFrom(
      tester.getCenter(find.byKey(const ValueKey('sheet-header-blank-space'))),
      const Offset(0, 180),
    );
    await tester.pumpAndSettle();
    expect(state.sheetController.size, closeTo(0.3, 0.01));

    await tester.drag(
      find.byKey(const ValueKey('sheet-header-chip-list')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    expect(state.sheetController.size, closeTo(0.6, 0.01));
  });

  testWidgets('horizontal chips, chip taps, and problem action still work', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_SheetDragHarnessState>();
    await tester.pumpWidget(_SheetDragHarness(key: harnessKey));
    await tester.pumpAndSettle();

    final state = harnessKey.currentState!;
    final initialSheetSize = state.sheetController.size;

    await tester.drag(
      find.byKey(const ValueKey('sheet-header-chip-list')),
      const Offset(-240, 0),
    );
    await tester.pumpAndSettle();
    expect(state.chipScrollController.offset, greaterThan(0));
    expect(state.sheetController.size, closeTo(initialSheetSize, 0.01));

    await tester.tap(find.text('Resto 4'));
    await tester.pump();
    expect(state.selectedChip, 'Resto 4');

    await tester.tap(find.byKey(const ValueKey('sheet-problem-button')));
    await tester.pump();
    expect(state.problemTapCount, 1);

    await tester.drag(
      find.byKey(const ValueKey('sheet-problem-button')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    expect(state.problemTapCount, 1);
    expect(state.sheetController.size, closeTo(0.6, 0.01));
  });
}

class _SheetDragHarness extends StatefulWidget {
  const _SheetDragHarness({super.key});

  @override
  State<_SheetDragHarness> createState() => _SheetDragHarnessState();
}

class _SheetDragHarnessState extends State<_SheetDragHarness> {
  final sheetController = DraggableScrollableController();
  final chipScrollController = ScrollController();
  String selectedChip = 'Ringkasan';
  int problemTapCount = 0;

  static const chips = <String>[
    'Ringkasan',
    'Jemput',
    'Antar',
    'Resto 1',
    'Resto 2',
    'Resto 3',
    'Resto 4',
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
          initialChildSize: 0.3,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Material(
              child: Column(
                children: [
                  DriverOrderSheetDragRegion(
                    controller: sheetController,
                    minExtent: 0.3,
                    mediumExtent: 0.6,
                    maxExtent: 0.9,
                    child: SizedBox(
                      height: 172,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          const Text('Antar ke tujuan'),
                          Expanded(
                            child: Row(
                              children: [
                                const Expanded(
                                  child: SizedBox(
                                    key: ValueKey('sheet-header-blank-space'),
                                  ),
                                ),
                                IconButton(
                                  key: const ValueKey('sheet-problem-button'),
                                  onPressed: () => setState(() {
                                    problemTapCount += 1;
                                  }),
                                  icon: const Icon(
                                    Icons.report_problem_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 52,
                            child: ListView.separated(
                              key: const ValueKey('sheet-header-chip-list'),
                              controller: chipScrollController,
                              scrollDirection: Axis.horizontal,
                              itemCount: chips.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final chip = chips[index];
                                return ChoiceChip(
                                  label: Text(chip),
                                  selected: selectedChip == chip,
                                  onSelected: (_) => setState(() {
                                    selectedChip = chip;
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
