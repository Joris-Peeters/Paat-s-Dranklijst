import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/daos/transactions_dao.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/widgets/transaction_detail_dialog.dart';

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

  Future<TransactionRow> logDrink() async {
    final id = await db.transactionsDao.logConsumption(
      userId: jonas.id,
      item: cola,
      quantity: 2,
    );
    return (await db.transactionsDao.readTransaction(id))!;
  }

  /// Opened over a real Scaffold, the way a history row opens it: the undo
  /// raises a snackbar, which needs one to sit in.
  Future<void> pump(
    WidgetTester tester,
    TransactionRow transaction, {
    String? pin,
  }) async {
    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        preferences: pin == null ? const {} : {'adminPin': pin},
        screen: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showTransactionDetailDialog(
                  context,
                  entry: TransactionEntry(
                    transaction: transaction,
                    user: jonas,
                    item: cola,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapDigits(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.widgetWithText(FilledButton, digit));
      await tester.pumpAndSettle();
    }
  }

  testWidgetsWithDatabase('the frozen snapshots are what is shown', (
    tester,
  ) async {
    await pump(tester, await logDrink());

    expect(find.text('Cola'), findsOneWidget);
    // The unit price as it was, and the line total with the quantity in it.
    expect(find.text('€1.50'), findsOneWidget);
    expect(find.text('-€3.00'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgetsWithDatabase('without a PIN set the undo asks only for a reason', (
    tester,
  ) async {
    final transaction = await logDrink();
    await pump(tester, transaction);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    // No gate to pass: an open kiosk is a supported configuration.
    expect(find.text('Undo this transaction?'), findsOneWidget);
  });

  testWidgetsWithDatabase('a PIN stands between the row and the undo', (
    tester,
  ) async {
    // The keypad is built for a portrait tablet and does not fit the default
    // 800x600 test window.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final transaction = await logDrink();
    await pump(tester, transaction, pin: '1234');

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the admin PIN'), findsOneWidget);
    // Dismissing the gate leaves the row entirely alone.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(
      (await db.transactionsDao.readTransaction(transaction.id))!.voidedAt,
      null,
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await tapDigits(tester, '1234');

    expect(find.text('Undo this transaction?'), findsOneWidget);
  });

  testWidgetsWithDatabase('an empty reason still undoes, and stores none', (
    tester,
  ) async {
    final transaction = await logDrink();
    await pump(tester, transaction);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    // The reason is optional, so the confirm is never disabled.
    await tester.tap(find.widgetWithText(FilledButton, 'Undo'));
    await tester.pumpAndSettle();

    final voided = (await db.transactionsDao.readTransaction(transaction.id))!;
    expect(voided.voidedAt, isA<DateTime>());
    expect(voided.voidedNote, null);
    // Out of the balance, still in the record.
    expect(await db.usersDao.readBalance(jonas.id), 0);
  });

  testWidgetsWithDatabase('a reason is kept when one is given', (tester) async {
    final transaction = await logDrink();
    await pump(tester, transaction);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Wrong person');
    await tester.tap(find.widgetWithText(FilledButton, 'Undo'));
    await tester.pumpAndSettle();

    expect(
      (await db.transactionsDao.readTransaction(transaction.id))!.voidedNote,
      'Wrong person',
    );
  });

  testWidgetsWithDatabase('an already-undone row offers no way back', (
    tester,
  ) async {
    final transaction = await logDrink();
    await db.transactionsDao.voidTransaction(transaction.id, note: 'Mistake');

    await pump(
      tester,
      (await db.transactionsDao.readTransaction(transaction.id))!,
    );

    // One-way: the details replace the action rather than sitting beside it.
    expect(find.text('Undo'), findsNothing);
    expect(find.textContaining('Undone on'), findsOneWidget);
    expect(find.text('Mistake'), findsOneWidget);
  });
}
