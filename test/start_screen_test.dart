import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/screens/start_screen.dart';

import 'support/harness.dart';

const int seededGroup = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int jonas;
  late ItemRow cola;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    jonas = await db.usersDao.createUser(
      name: 'Jonas',
      groupId: seededGroup,
      avatarEmoji: '🦊',
      seedColorArgb: 0xFF009688,
    );
    final id = await db.itemsDao.createItem(
      name: 'Cola',
      groupId: seededGroup,
      priceMinorUnits: 150,
      emoji: '🥤',
    );
    cola = await (db.select(
      db.items,
    )..where((i) => i.id.equals(id))).getSingle();
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {VoidCallback? onOpenUsers}) async {
    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        screen: StartScreen(onOpenUsers: onOpenUsers ?? () {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgetsWithDatabase('a quiet day reads zero rather than blank', (
    tester,
  ) async {
    await pump(tester);

    // The card heading is upper-cased; the stat labels under the figures are not.
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Consumptions'), findsOneWidget);
    expect(find.text('Turnover'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('€0.00'), findsOneWidget);
  });

  testWidgetsWithDatabase('an order counts its items and their total', (
    tester,
  ) async {
    await db.transactionsDao.logConsumption(
      userId: jonas,
      item: cola,
      quantity: 3,
    );
    await pump(tester);

    // One row, three drinks: the figure is SUM(quantity), not a row count.
    expect(find.text('3'), findsOneWidget);
    // Positive, because turnover is money taken rather than a balance.
    expect(find.text('€4.50'), findsOneWidget);
  });

  testWidgetsWithDatabase('a voided row counts towards neither figure', (
    tester,
  ) async {
    final id = await db.transactionsDao.logConsumption(
      userId: jonas,
      item: cola,
      quantity: 2,
    );
    await db.transactionsDao.voidTransaction(id, note: 'Wrong person');
    await pump(tester);

    expect(find.text('0'), findsOneWidget);
    expect(find.text('€0.00'), findsOneWidget);
  });

  testWidgetsWithDatabase('the big button asks the shell to switch tabs', (
    tester,
  ) async {
    var opened = 0;
    await pump(tester, onOpenUsers: () => opened++);

    // A callback, not a push: Users is a tab of the shell.
    await tester.tap(find.text('Choose your name'));
    await tester.pumpAndSettle();

    expect(opened, 1);
  });

  testWidgetsWithDatabase('the settings cog is still the way in', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
  });
}
