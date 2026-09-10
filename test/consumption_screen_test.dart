import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/screens/consumption_screen.dart';

import 'support/harness.dart';

const int seededGroup = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late UserRow jonas;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    final id = await db.usersDao.createUser(
      name: 'Jonas',
      groupId: seededGroup,
      avatarEmoji: '🦊',
      seedColorArgb: 0xFF009688,
    );
    jonas = (await db.usersDao.readUser(id))!;
  });
  tearDown(() => db.close());

  Future<void> addItem({required String name, int price = 150}) =>
      db.itemsDao.createItem(
        name: name,
        groupId: seededGroup,
        priceMinorUnits: price,
        emoji: '🥤',
      );

  // A plain Future, not `watchUserHistory(...).first`: awaiting a stream inside
  // a testWidgets body deadlocks under fake async.
  Future<List<TransactionRow>> history() => (db.select(
    db.transactions,
  )..where((t) => t.userId.equals(jonas.id))).get();

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        // Pushed onto a route so the screen can pop off it, as it does in the
        // app; a screen used as `home` has nothing to pop to.
        screen: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConsumptionScreen(user: jonas),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgetsWithDatabase('a tap logs one drink and leaves the screen', (
    tester,
  ) async {
    await addItem(name: 'Cola');
    await pump(tester);

    await tester.tap(find.text('Cola'));
    await tester.pumpAndSettle();

    expect(await db.usersDao.readBalance(jonas.id), -150);
    // Back on the page it was pushed from.
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Cola registered for Jonas'), findsOneWidget);
  });

  testWidgetsWithDatabase('undo removes the row outright', (tester) async {
    await addItem(name: 'Cola');
    await pump(tester);
    await tester.tap(find.text('Cola'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(await db.usersDao.readBalance(jonas.id), 0);
    // Deleted, not voided: nothing is left in the record.
    expect(await db.transactionsDao.readTransaction(1), isNull);
  });

  testWidgetsWithDatabase('a long press starts an order instead of logging', (
    tester,
  ) async {
    await addItem(name: 'Cola');
    await pump(tester);

    await tester.longPress(find.text('Cola'));
    await tester.pumpAndSettle();

    // Nothing written yet, and the screen is still open.
    expect(await db.usersDao.readBalance(jonas.id), 0);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('1 drink · €1.50'), findsOneWidget);
  });

  testWidgetsWithDatabase('taps accumulate and confirm writes one row', (
    tester,
  ) async {
    await addItem(name: 'Cola');
    await pump(tester);

    await tester.longPress(find.text('Cola'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cola'));
    await tester.tap(find.text('Cola'));
    await tester.pumpAndSettle();

    expect(find.text('3 drinks · €4.50'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(await db.usersDao.readBalance(jonas.id), -450);
    // One row of quantity 3, not three rows.
    final rows = await history();
    expect(rows, hasLength(1));
    expect(rows.single.quantity, 3);
    expect(find.text('3 drinks registered for Jonas'), findsOneWidget);
  });

  testWidgetsWithDatabase('an order spans items and writes a row each', (
    tester,
  ) async {
    await addItem(name: 'Cola');
    await addItem(name: 'Chips', price: 200);
    await pump(tester);

    await tester.longPress(find.text('Cola'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chips'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    final rows = await history();
    expect(rows, hasLength(2));
    expect(await db.usersDao.readBalance(jonas.id), -350);
  });

  testWidgetsWithDatabase('cancel clears the order and writes nothing', (
    tester,
  ) async {
    await addItem(name: 'Cola');
    await pump(tester);

    await tester.longPress(find.text('Cola'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(await db.usersDao.readBalance(jonas.id), 0);
    expect(find.text('Confirm'), findsNothing);
    // Still on the screen, and a tap logs normally again.
    await tester.tap(find.text('Cola'));
    await tester.pumpAndSettle();
    expect(await db.usersDao.readBalance(jonas.id), -150);
  });

  testWidgetsWithDatabase('a category with nothing on offer is not drawn', (
    tester,
  ) async {
    await db.itemsDao.createItemGroup(name: 'Snacks');
    await addItem(name: 'Cola');
    await pump(tester);

    expect(find.textContaining('General'), findsOneWidget);
    expect(find.textContaining('Snacks'), findsNothing);
  });

  // The undo window closing is what makes the row permanent, so it has to
  // actually close. A SnackBar carrying an action defaults to persisting until
  // it is tapped, which would leave the window open forever.
  testWidgetsWithDatabase('the undo window closes on its own', (tester) async {
    await addItem(name: 'Cola');
    await pump(tester);

    await tester.tap(find.text('Cola'));
    await tester.pumpAndSettle();
    expect(find.text('Cola registered for Jonas'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(find.text('Cola registered for Jonas'), findsNothing);
    // And the row it offered back is still there.
    expect(await db.usersDao.readBalance(jonas.id), -150);
  });
}
