import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/widgets/responsive_tile_grid.dart';

/// The column count is measured rather than chosen per breakpoint, so the
/// arithmetic — which has to take the gaps out of the budget first — is worth
/// pinning down at a few real widths.
void main() {
  Future<int> columnsAt(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsiveTileGrid(
            minTileWidth: 180,
            children: [
              for (var i = 0; i < 12; i++)
                ColoredBox(key: ValueKey(i), color: Colors.blue),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // Distinct left edges across the tiles that exist is the column count.
    // Only the visible ones are built — a GridView is lazy — which is enough:
    // the first row is always among them.
    final lefts = <double>{};
    for (var i = 0; i < 12; i++) {
      final tile = find.byKey(ValueKey(i));
      if (tile.evaluate().isNotEmpty) {
        lefts.add(tester.getTopLeft(tile).dx);
      }
    }
    return lefts.length;
  }

  testWidgets('a phone-width portrait screen gets one column', (tester) async {
    expect(await columnsAt(tester, 360), 1);
  });

  testWidgets('a tablet-width portrait screen gets more', (tester) async {
    expect(await columnsAt(tester, 800), 4);
  });

  testWidgets('a very narrow screen never drops below one column', (
    tester,
  ) async {
    expect(await columnsAt(tester, 100), 1);
  });

  testWidgets('no tile is drawn narrower than minTileWidth', (tester) async {
    tester.view.physicalSize = const Size(760, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResponsiveTileGrid(
            minTileWidth: 180,
            children: [
              ColoredBox(key: ValueKey(0), color: Colors.blue),
              ColoredBox(key: ValueKey(1), color: Colors.blue),
              ColoredBox(key: ValueKey(2), color: Colors.blue),
              ColoredBox(key: ValueKey(3), color: Colors.blue),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byKey(const ValueKey(0))).width,
      greaterThanOrEqualTo(180),
    );
  });
}
