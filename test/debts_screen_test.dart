import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/screens/debts_screen.dart';

import 'support/harness.dart';

const int seededGroup = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase(executor: NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addUser(
    String name, {
    int groupId = seededGroup,
    int balance = 0,
  }) async {
    final id = await db.usersDao.createUser(
      name: name,
      groupId: groupId,
      avatarEmoji: '🦊',
      seedColorArgb: 0xFF009688,
    );
    if (balance != 0) {
      await db.transactionsDao.logAdjustment(
        userId: id,
        amountMinorUnits: balance,
        note: 'test',
      );
    }
    return id;
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      await settingsHarness(null, database: db, screen: const DebtsScreen()),
    );
    await tester.pumpAndSettle();
  }

  testWidgetsWithDatabase('lists debtors most first, filterable by group', (
    tester,
  ) async {
    final leaders = await db.usersDao.createUserGroup(name: 'Leiding');
    await addUser('Wout', balance: -250);
    await addUser('Jonas', groupId: leaders, balance: -1000);
    await addUser('Bea', balance: 500);
    await pump(tester);

    expect(find.text('Bea'), findsNothing);
    expect(find.textContaining('2 people · -€12.50 total'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Jonas')).dy,
      lessThan(tester.getTopLeft(find.text('Wout')).dy),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Leiding'));
    await tester.pumpAndSettle();

    expect(find.text('Wout'), findsNothing);
    expect(find.text('Jonas'), findsOneWidget);
    expect(find.textContaining('1 person · -€10.00 total'), findsOneWidget);
  });

  testWidgetsWithDatabase('says so when nobody owes anything', (tester) async {
    await addUser('Bea', balance: 500);
    await pump(tester);

    expect(find.text('Nobody owes anything'), findsOneWidget);
  });
}
