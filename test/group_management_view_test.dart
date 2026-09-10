import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/group_usage.dart';
import 'package:paats_dranklijst/widgets/group_management_view.dart';

import 'support/harness.dart';

/// Driven by a hand-made stream rather than a database — the point of the
/// record seam is that the screen's behaviour is testable without one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GroupEntry entry(int id, String name, {int active = 0, int archived = 0}) => (
    id: id,
    name: name,
    emoji: null,
    usage: GroupUsage(activeCount: active, archivedCount: archived),
  );

  Future<void> pump(
    WidgetTester tester,
    List<GroupEntry> entries, {
    Stream<List<GroupEntry>>? groups,
    Future<void> Function(List<int> ids)? onReorder,
    Future<void> Function(int id)? onDelete,
    Future<void> Function(GroupEdit edit)? onCreate,
  }) async {
    await tester.pumpWidget(
      await settingsHarness(
        GroupManagementView(
          title: 'User groups',
          groups: groups ?? Stream.value(entries),
          emptyMessage: 'No groups yet',
          createLabel: 'New group',
          editLabel: 'Edit group',
          deleteLabel: 'Delete group',
          countLabel: (count) => '$count members',
          onCreate: onCreate ?? (_) async {},
          onEdit: (_, _) async {},
          onDelete: onDelete ?? (_) async {},
          onReorder: onReorder ?? (_) async {},
          onOpen: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty list shows the empty state, keeping the FAB', (
    tester,
  ) async {
    await pump(tester, []);

    expect(find.text('No groups yet'), findsOneWidget);
    expect(find.text('New group'), findsOneWidget);
  });

  testWidgets('a group holding nobody can be deleted', (tester) async {
    var deleted = 0;
    await pump(tester, [
      entry(1, 'Leiding'),
    ], onDelete: (id) async => deleted = id);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(deleted, 1);
  });

  testWidgets('an archived-only group cannot be deleted and says why', (
    tester,
  ) async {
    var deleted = 0;
    await pump(
      // Looks empty on screen, but the archived member still pins it.
      tester,
      [entry(1, 'Leiding', archived: 1)],
      onDelete: (id) async => deleted = id,
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(deleted, 0);
    expect(find.byType(AlertDialog), findsNothing);
    // The subtitle counts only live members, so the reason cannot quote a
    // number without appearing to contradict it.
    expect(find.text('0 members'), findsOneWidget);
    expect(
      find.text(
        'Cannot be deleted while it still holds entries, archived ones '
        'included.',
      ),
      findsOneWidget,
    );
  });

  // Measured rather than guessed, and dragged past the neighbour's midpoint
  // rather than exactly one row: the list re-evaluates the drop slot against
  // the dragged item's own extent as it moves. How far a drag travels is the
  // framework's business; these tests are about what happens on the drop.
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

  testWidgets('a drag reports the finished order as ids', (tester) async {
    List<int>? ordered;
    await pump(tester, [
      entry(1, 'A'),
      entry(2, 'B'),
      entry(3, 'C'),
    ], onReorder: (ids) async => ordered = ids);

    await dragFirstRowDown(tester);

    // Multi-position moves are covered in reorder_test.dart.
    expect(ordered, [2, 1, 3]);
  });

  testWidgets('a long name on a phone-width screen does not overflow', (
    tester,
  ) async {
    // The row carries a drag handle, an emoji, a two-line body and two icon
    // buttons. Portrait phone is the narrowest thing it has to survive.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pump(tester, [
      entry(1, 'Speelclub, Rakwis en Tito samen', active: 12, archived: 3),
    ]);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the edit dialog fits a phone-width screen with an emoji set', (
    tester,
  ) async {
    // With an emoji chosen the dialog also grows a clear button, which is the
    // widest this row ever gets.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      await settingsHarness(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showGroupEditDialog(
              context,
              title: 'Edit group',
              name: 'Leiding',
              emoji: '🦊',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the create dialog refuses a blank name', (tester) async {
    GroupEdit? created;
    await pump(tester, [], onCreate: (edit) async => created = edit);

    await tester.tap(find.text('New group'));
    await tester.pumpAndSettle();

    final save = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '  Leiding  ');
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(created?.name, 'Leiding');
    expect(created?.emoji, isNull);
  });
}
