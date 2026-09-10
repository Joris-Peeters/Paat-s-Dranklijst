import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/screens/user_group_contents_screen.dart';

import 'support/harness.dart';

/// The seeded group, inserted by `onCreate`, so always id 1.
const int seededGroup = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase(executor: NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addMember({String name = 'Jonas'}) => db.usersDao.createUser(
    name: name,
    groupId: seededGroup,
    avatarEmoji: '🦊',
    seedColorArgb: 0xFF009688,
  );

  Future<void> pump(WidgetTester tester) async {
    final group = await db.usersDao.readUserGroup(seededGroup);
    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        screen: UserGroupContentsScreen(group: group!),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgetsWithDatabase(
    'an archived member is shown dimmed, last, and undraggable',
    (tester) async {
      await db.usersDao.archiveUser(await addMember(name: 'Jonas'));
      await addMember(name: 'Bea');
      await pump(tester);

      // Always visible: there is no toggle to reach for.
      expect(find.text('Jonas'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
      // Below the active member, whatever their sort order was.
      expect(
        tester.getCenter(find.text('Jonas')).dy,
        greaterThan(tester.getCenter(find.text('Bea')).dy),
      );
      // One handle, on the one row that can still be ordered.
      expect(find.byIcon(Icons.drag_handle), findsOneWidget);
      expect(find.byType(Opacity), findsOneWidget);
      expect(find.byIcon(Icons.unarchive_outlined), findsOneWidget);
    },
  );

  testWidgetsWithDatabase('restoring is immediate and needs no confirmation', (
    tester,
  ) async {
    await db.usersDao.archiveUser(await addMember(name: 'Jonas'));
    await pump(tester);

    await tester.tap(find.byIcon(Icons.unarchive_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byIcon(Icons.archive_outlined), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsOneWidget);
  });

  testWidgetsWithDatabase('a member who still holds money cannot be archived', (
    tester,
  ) async {
    final id = await addMember(name: 'Jonas');
    await db.transactionsDao.logTopUp(userId: id, amountMinorUnits: 450);
    await pump(tester);

    await tester.tap(find.byIcon(Icons.archive_outlined));
    // Pumped rather than settled: the SnackBar sits on a timer, and settling
    // would wait it out.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Refused before the tap reaches the DAO, and it says why.
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text(
        'Jonas still has €4.50. Settle up or post an adjustment first.',
      ),
      findsOneWidget,
    );
    // Nothing was written: no archived section appeared, and the row is still
    // orderable.
    expect(find.text('Archived'), findsNothing);
    expect(find.byIcon(Icons.drag_handle), findsOneWidget);
  });

  testWidgetsWithDatabase('archiving a settled member asks first', (
    tester,
  ) async {
    await addMember(name: 'Jonas');
    await pump(tester);

    await tester.tap(find.byIcon(Icons.archive_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    // Still listed, now under the archived heading and no longer orderable.
    expect(find.text('Jonas'), findsOneWidget);
    expect(find.text('Archived'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(find.byIcon(Icons.unarchive_outlined), findsOneWidget);
  });

  testWidgetsWithDatabase(
    'the adjustment action is present but not yet wired',
    (tester) async {
      await addMember(name: 'Jonas');
      await pump(tester);

      final button = find.widgetWithIcon(IconButton, Icons.tune);
      expect(button, findsOneWidget);
      expect(tester.widget<IconButton>(button).onPressed, isNull);
    },
  );

  testWidgetsWithDatabase('three trailing actions fit a phone-width row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await addMember(name: 'Jonas van der Elsdonckstraat');
    await pump(tester);

    expect(tester.takeException(), isNull);
  });
}
