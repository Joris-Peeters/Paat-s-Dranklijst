import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/data/tables/transactions_table.dart';
import 'package:paats_dranklijst/widgets/adjustment_dialog.dart';

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

  Future<void> owe(int minorUnits) => db.transactionsDao.logAdjustment(
    userId: jonas.id,
    amountMinorUnits: -minorUnits,
    note: 'Opening',
  );

  Future<List<TransactionRow>> adjustments() async {
    final rows = await (db.select(
      db.transactions,
    )..where((t) => t.userId.equals(jonas.id))).get();
    return rows.where((r) => r.note != 'Opening').toList();
  }

  /// Opened over a real Scaffold, the way the management screen opens it: the
  /// save raises a snackbar, which needs one to sit in.
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        screen: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showAdjustmentDialog(context, user: jonas),
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

  TextField fieldWithLabel(WidgetTester tester, String label) => tester
      .widgetList<TextField>(find.byType(TextField))
      .firstWhere((f) => f.decoration?.labelText == label);

  String textOf(WidgetTester tester, String label) =>
      fieldWithLabel(tester, label).controller!.text;

  Future<void> enter(WidgetTester tester, String label, String value) async {
    await tester.enterText(find.byWidget(fieldWithLabel(tester, label)), value);
    await tester.pumpAndSettle();
  }

  testWidgetsWithDatabase('the balance it starts from is shown and fixed', (
    tester,
  ) async {
    await owe(450);
    await pump(tester);

    expect(find.text('Current balance'), findsOneWidget);
    expect(find.text('-€4.50'), findsOneWidget);
  });

  testWidgetsWithDatabase('an amount fills in where the balance would land', (
    tester,
  ) async {
    await owe(450);
    await pump(tester);

    await enter(tester, 'Amount', '10');

    expect(textOf(tester, 'New balance'), '5.50');
  });

  testWidgetsWithDatabase('a target balance fills in the amount to get there', (
    tester,
  ) async {
    await owe(450);
    await pump(tester);

    // The other direction: the admin knows where it should end up, not how far
    // that is from here.
    await enter(tester, 'New balance', '0');

    expect(textOf(tester, 'Amount'), '4.50');
  });

  testWidgetsWithDatabase('a negative amount is allowed and lands negative', (
    tester,
  ) async {
    await pump(tester);

    await enter(tester, 'Amount', '-2.50');

    expect(textOf(tester, 'New balance'), '-2.50');
  });

  testWidgetsWithDatabase('saving is refused until there is a reason', (
    tester,
  ) async {
    await pump(tester);
    await enter(tester, 'Amount', '10');

    // An adjustment exists to record why the balance moved.
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );

    await enter(tester, 'Note', 'Paid 10 euro cash');

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgetsWithDatabase('an adjustment of nothing is refused', (
    tester,
  ) async {
    await pump(tester);
    await enter(tester, 'Amount', '0');
    await enter(tester, 'Note', 'Nothing happened');

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
  });

  testWidgetsWithDatabase('saving writes one signed row with its note', (
    tester,
  ) async {
    await owe(450);
    await pump(tester);
    await enter(tester, 'Amount', '10');
    await enter(tester, 'Note', 'Paid 10 euro cash');

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final written = (await adjustments()).single;
    expect(written.type, TransactionType.adjustment);
    expect(written.amountMinorUnits, 1000);
    expect(written.note, 'Paid 10 euro cash');
    expect(await db.usersDao.readBalance(jonas.id), 550);
  });
}
