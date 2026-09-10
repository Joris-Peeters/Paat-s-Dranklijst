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

  testWidgets('tileHeight holds as the window widens', (tester) async {
    Future<Size> tileAt(double width) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveTileGrid(
              minTileWidth: 260,
              tileHeight: 88,
              children: [ColoredBox(key: ValueKey(0), color: Colors.blue)],
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getSize(find.byKey(const ValueKey(0)));
    }

    // A row of avatar, name and amount does not get taller with the window,
    // which is exactly what an aspect ratio would do to it. Width is left out
    // on purpose: a wider window adds columns, so tiles get narrower, not
    // wider.
    expect((await tileAt(400)).height, 88);
    expect((await tileAt(900)).height, 88);
    expect((await tileAt(1600)).height, 88);
  });

  testWidgets('a shrinkWrap grid sizes to its rows and does not scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                ResponsiveTileGrid(
                  minTileWidth: 180,
                  tileHeight: 100,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  spacing: 0,
                  children: [
                    ColoredBox(key: ValueKey('a'), color: Colors.blue),
                    ColoredBox(key: ValueKey('b'), color: Colors.blue),
                  ],
                ),
                SizedBox(key: ValueKey('after'), height: 10),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // One row of two tiles at 400px wide, so the grid claims exactly 100px and
    // the widget after it starts right below.
    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(find.byKey(const ValueKey('after'))).dy, 100);
    expect(
      tester.widget<GridView>(find.byType(GridView)).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
  });
}
