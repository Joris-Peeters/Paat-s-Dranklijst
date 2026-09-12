import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/screens/history_screen.dart';

import 'support/harness.dart';

const int seededGroup = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late UserRow jonas;
  late ItemRow cola;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    final userId = await db.usersDao.createUser(
      name: 'Jonas',
      groupId: seededGroup,
      avatarEmoji: '🦊',
      seedColorArgb: 0xFF009688,
    );
    jonas = (await db.usersDao.readUser(userId))!;
    final itemId = await db.itemsDao.createItem(
      name: 'Cola',
      groupId: seededGroup,
      priceMinorUnits: 150,
      emoji: '🥤',
    );
    cola = await (db.select(
      db.items,
    )..where((i) => i.id.equals(itemId))).getSingle();
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {UserRow? initialUser}) async {
    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        screen: HistoryScreen(initialUser: initialUser),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgetsWithDatabase('the screen opens and lists the ledger', (
    tester,
  ) async {
    await db.transactionsDao.logConsumption(userId: jonas.id, item: cola);
    await pump(tester);

    // Regression: the subscription used to open in initState, where
    // `Database.of` asserts, so this screen threw the moment it was opened.
    expect(find.text('Jonas · 🥤 Cola'), findsOneWidget);
  });

  testWidgetsWithDatabase('an empty ledger says so rather than throwing', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Nothing yet'), findsOneWidget);
  });

  testWidgetsWithDatabase('initialUser pre-applies the user filter', (
    tester,
  ) async {
    await db.transactionsDao.logConsumption(userId: jonas.id, item: cola);
    await pump(tester, initialUser: jonas);

    // Filtered to one user, so rows drop the name and lead with the item.
    expect(find.text('Cola'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Jonas'), findsOneWidget);
  });
}
