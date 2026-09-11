import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/data/tables/transactions_table.dart';
import 'package:paats_dranklijst/widgets/epc_qr_code.dart';
import 'package:paats_dranklijst/widgets/top_up_sheet.dart';

import 'support/harness.dart';

const int seededGroup = 1;

/// A real IBAN, because the QR page only appears once the details are usable.
const _iban = 'BE68539007547034';

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

  // A plain Future: awaiting a stream inside a testWidgets body deadlocks
  // under fake async.
  Future<List<TransactionRow>> rows() => (db.select(
    db.transactions,
  )..where((t) => t.userId.equals(jonas.id))).get();

  Future<void> owe(int minorUnits) => db.transactionsDao.logAdjustment(
    userId: jonas.id,
    amountMinorUnits: -minorUnits,
    note: 'Opening',
  );

  /// Opens the sheet the way a screen does, with or without bank details set.
  Future<void> pump(WidgetTester tester, {bool withBankDetails = true}) async {
    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        preferences: withBankDetails
            ? {'payeeName': "Paat's Dranklijst", 'payeeIban': _iban}
            : const {},
        screen: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showTopUpSheet(context, user: jonas),
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

  ButtonStyleButton primary(WidgetTester tester, String label) =>
      tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(FilledButton),
        ),
      );

  testWidgetsWithDatabase('the debt preset is offered only when they owe', (
    tester,
  ) async {
    await pump(tester);
    // A balance of zero has no debt to clear, so an exact-debt chip would be a
    // button that does nothing.
    expect(find.text('Debt €0.00'), findsNothing);

    await owe(450);
    await tester.pumpAndSettle();
    expect(find.text('Debt €4.50'), findsOneWidget);
  });

  testWidgetsWithDatabase('the debt preset fills the exact amount owed', (
    tester,
  ) async {
    await owe(450);
    await pump(tester);

    await tester.tap(find.text('Debt €4.50'));
    await tester.pumpAndSettle();

    // Straight into the field, so the chips and the amount cannot disagree.
    expect(find.widgetWithText(TextField, '4.50'), findsOneWidget);
    // The preview shows where it lands: back to zero.
    expect(find.text('€0.00'), findsOneWidget);
  });

  testWidgetsWithDatabase('nothing is offered until an amount is entered', (
    tester,
  ) async {
    await pump(tester);

    expect(primary(tester, 'Continue').onPressed, isNull);

    await tester.enterText(find.byType(TextField), '10');
    await tester.pumpAndSettle();

    expect(primary(tester, 'Continue').onPressed, isNotNull);
  });

  testWidgetsWithDatabase('with no bank details it commits without a QR', (
    tester,
  ) async {
    await pump(tester, withBankDetails: false);

    // The cash case: no page whose only content would be a grey placeholder.
    expect(find.text('Continue'), findsNothing);
    await tester.enterText(find.byType(TextField), '10');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paid'));
    await tester.pumpAndSettle();

    final written = await rows();
    expect(written.single.type, TransactionType.topUp);
    expect(written.single.amountMinorUnits, 1000);
  });

  testWidgetsWithDatabase('with bank details the QR page comes first', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '10');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(EpcQrCode), findsOneWidget);
    // The same details in text, for a scanner that will not focus.
    expect(find.text('BE68 5390 0754 7034'), findsOneWidget);
    // Still nothing written: the money has not been handed over yet.
    expect(await rows(), isEmpty);
  });

  testWidgetsWithDatabase('going back from the QR keeps the amount and writes '
      'nothing', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '12,50');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '12,50'), findsOneWidget);
    expect(await rows(), isEmpty);
  });

  testWidgetsWithDatabase(
    'paid writes one positive row and moves the balance',
    (tester) async {
      await owe(450);
      await pump(tester);
      await tester.enterText(find.byType(TextField), '10');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Paid'));
      await tester.pumpAndSettle();

      final topUps = (await rows())
          .where((r) => r.type == TransactionType.topUp)
          .toList();
      expect(topUps.single.amountMinorUnits, 1000);
      expect(await db.usersDao.readBalance(jonas.id), 550);
    },
  );
}
