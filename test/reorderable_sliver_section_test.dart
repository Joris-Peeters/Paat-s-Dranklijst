import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/l10n/app_localizations.dart';
import 'package:paats_dranklijst/widgets/reorderable_sliver_section.dart';

/// The section exists for one reason — holding the dropped order for the frames
/// before the write lands — so that is what these pin down.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(
    WidgetTester tester,
    List<String> items, {
    void Function(List<String> ordered)? onReorder,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        // DragHandle reads its tooltip from the ARB files.
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              ReorderableSliverSection<String>(
                items: items,
                keyOf: ValueKey.new,
                onReorder: onReorder ?? (_) {},
                // Carded like the real rows: the dragged proxy is lifted out
                // of the Scaffold, and a bare ListTile would find no Material.
                itemBuilder: (context, item, index) => Card(
                  child: ListTile(
                    // Sized, or the handle claims the whole tile width.
                    leading: SizedBox(
                      width: 48,
                      child: DragHandle(index: index),
                    ),
                    title: Text(item),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Dragged past the neighbour's midpoint rather than exactly one row: the list
  // re-evaluates the drop slot against the dragged item's own extent as it
  // moves. Multi-position moves are covered in reorder_test.dart.
  Future<void> dragFirstRowDown(WidgetTester tester) async {
    final handles = find.byIcon(Icons.drag_handle);
    final rowHeight =
        tester.getCenter(handles.at(1)).dy - tester.getCenter(handles.first).dy;

    final gesture = await tester.startGesture(tester.getCenter(handles.first));
    await tester.pump();
    await gesture.moveBy(Offset(0, rowHeight * 2));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('reports the finished order', (tester) async {
    List<String>? ordered;
    await pump(tester, ['A', 'B', 'C'], onReorder: (o) => ordered = o);

    await dragFirstRowDown(tester);

    expect(ordered, ['B', 'A', 'C']);
  });

  testWidgets('a dropped row keeps its new place before the write lands', (
    tester,
  ) async {
    // Nothing is pushed back in, standing in for the frames between the finger
    // lifting and the transaction committing. Without the local copy the row
    // snaps back to where it started.
    await pump(tester, ['A', 'B', 'C']);

    await dragFirstRowDown(tester);

    expect(
      tester.getCenter(find.text('A')).dy,
      greaterThan(tester.getCenter(find.text('B')).dy),
    );
  });

  testWidgets('a later value overrules the dropped order', (tester) async {
    // The source of truth stays outside: if the write never landed, the next
    // build has to put the row back.
    await pump(tester, ['A', 'B', 'C']);
    await dragFirstRowDown(tester);
    await pump(tester, ['A', 'B', 'C']);

    expect(
      tester.getCenter(find.text('A')).dy,
      lessThan(tester.getCenter(find.text('B')).dy),
    );
  });
}
