import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/screens/pending_top_ups_screen.dart';

import 'support/harness.dart';

const int seededGroup = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase(executor: NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addUser(String name) => db.usersDao.createUser(
    name: name,
    groupId: seededGroup,
    avatarEmoji: '🦊',
    seedColorArgb: 0xFF009688,
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        screen: const PendingTopUpsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgetsWithDatabase('lists pending top-ups oldest first', (tester) async {
    await db.transactionsDao.logTopUp(
      userId: await addUser('Wout'),
      amountMinorUnits: 1000,
    );
    await db.transactionsDao.logTopUp(
      userId: await addUser('Jonas'),
      amountMinorUnits: 2000,
    );
    await pump(tester);

    expect(find.text('€10.00'), findsOneWidget);
    expect(find.text('€20.00'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Wout')).dy,
      lessThan(tester.getTopLeft(find.text('Jonas')).dy),
    );
  });

  testWidgetsWithDatabase('an empty list says everything is confirmed', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Every top-up has been confirmed'), findsOneWidget);
  });

  testWidgetsWithDatabase(
    'confirming removes the row, and Undo brings it back',
    (tester) async {
      final jonas = await addUser('Jonas');
      await db.transactionsDao.logTopUp(userId: jonas, amountMinorUnits: 1000);
      await pump(tester);

      await tester.tap(find.byTooltip('Payment received'));
      await tester.pumpAndSettle();

      expect(find.text('Jonas'), findsNothing);
      expect(find.text('€10.00 from Jonas confirmed'), findsOneWidget);
      expect(await db.usersDao.readBalance(jonas), 1000);

      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await tester.pumpAndSettle();

      expect(find.text('Jonas'), findsOneWidget);
    },
  );

  testWidgetsWithDatabase(
    'confirm all asks first, empties the list, and Undo restores it',
    (tester) async {
      await db.transactionsDao.logTopUp(
        userId: await addUser('Wout'),
        amountMinorUnits: 1000,
      );
      await db.transactionsDao.logTopUp(
        userId: await addUser('Jonas'),
        amountMinorUnits: 2500,
      );
      await pump(tester);

      await tester.tap(find.byTooltip('Confirm all'));
      await tester.pumpAndSettle();
      expect(
        find.text('Mark 2 top-ups totalling €35.00 as received?'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Wout'), findsOneWidget);

      await tester.tap(find.byTooltip('Confirm all'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm all'));
      await tester.pumpAndSettle();

      expect(find.text('Every top-up has been confirmed'), findsOneWidget);
      expect(find.text('2 top-ups confirmed'), findsOneWidget);
      expect(find.byTooltip('Confirm all'), findsNothing);

      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await tester.pumpAndSettle();

      expect(find.text('Wout'), findsOneWidget);
      expect(find.text('Jonas'), findsOneWidget);
    },
  );

  testWidgetsWithDatabase('voiding asks why, then takes the credit back', (
    tester,
  ) async {
    final jonas = await addUser('Jonas');
    await db.transactionsDao.logTopUp(userId: jonas, amountMinorUnits: 1000);
    await pump(tester);

    await tester.tap(find.byTooltip('Not paid'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Never paid');
    await tester.tap(find.widgetWithText(FilledButton, 'Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Every top-up has been confirmed'), findsOneWidget);
    expect(await db.usersDao.readBalance(jonas), 0);
  });
}
