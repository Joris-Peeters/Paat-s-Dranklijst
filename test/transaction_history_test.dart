import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/daos/transactions_dao.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/data/tables/transactions_table.dart';
import 'package:paats_dranklijst/widgets/transaction_history.dart';

import 'support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final user = UserRow(
    id: 1,
    name: 'Jonas',
    avatarEmoji: '🦊',
    seedColorArgb: 0xFF009688,
    groupId: 1,
    sortOrder: 0,
    createdAt: DateTime(2026, 9, 9),
  );

  TransactionRow row({
    TransactionType type = TransactionType.consumption,
    int amountMinorUnits = -300,
    int quantity = 2,
    String? itemNameSnapshot = 'Cola',
    String? note,
    DateTime? voidedAt,
  }) => TransactionRow(
    id: 1,
    userId: 1,
    type: type,
    amountMinorUnits: amountMinorUnits,
    quantity: quantity,
    itemNameSnapshot: itemNameSnapshot,
    note: note,
    createdAt: DateTime(2026, 9, 9, 21, 30),
    logicalDate: '2026-09-09',
    voidedAt: voidedAt,
  );

  final cola = ItemRow(
    id: 1,
    name: 'Cola',
    emoji: '🥤',
    priceMinorUnits: 150,
    groupId: 1,
    sortOrder: 0,
    createdAt: DateTime(2026, 9, 9),
  );

  TransactionEntry entry(TransactionRow transaction, {ItemRow? item}) =>
      TransactionEntry(transaction: transaction, user: user, item: item);

  /// The mixed-feed form. [item] is left off for the types that reference
  /// none, so the tile is handed what the query would really give it.
  Future<void> pump(
    WidgetTester tester,
    TransactionRow transaction, {
    ItemRow? item,
  }) async => tester.pumpWidget(
    await settingsHarness(
      TransactionListTile(entry: entry(transaction, item: item)),
    ),
  );

  /// The form a user's own page uses: no name, and the item's emoji leading.
  Future<void> pumpForUser(
    WidgetTester tester,
    TransactionRow transaction, {
    ItemRow? item,
  }) async => tester.pumpWidget(
    await settingsHarness(
      TransactionListTile.forUser(entry: entry(transaction, item: item)),
    ),
  );

  testWidgets('a mixed feed names the user and the item on one line', (
    tester,
  ) async {
    await pump(tester, row(), item: cola);

    // The avatar slot is the user's on a mixed feed, so the item's emoji has
    // nowhere to go but inline.
    expect(find.text('Jonas · 🥤 Cola ×2'), findsOneWidget);
    // The line total, not the unit price.
    expect(find.text('-€3.00'), findsOneWidget);
  });

  testWidgets('a single item is named on its own', (tester) async {
    await pump(tester, row(quantity: 1, amountMinorUnits: -150), item: cola);

    expect(find.text('Jonas · 🥤 Cola'), findsOneWidget);
  });

  testWidgets('a top-up shows its note and an explicit plus', (tester) async {
    await pump(
      tester,
      row(
        type: TransactionType.topUp,
        amountMinorUnits: 1000,
        quantity: 1,
        itemNameSnapshot: null,
        note: 'Cash',
      ),
    );

    expect(find.text('Jonas · Cash'), findsOneWidget);
    expect(find.text('+€10.00'), findsOneWidget);
  });

  testWidgets('a top-up without a note falls back to a label', (tester) async {
    await pump(
      tester,
      row(
        type: TransactionType.topUp,
        amountMinorUnits: 1000,
        quantity: 1,
        itemNameSnapshot: null,
      ),
    );

    expect(find.text('Jonas · Top-up'), findsOneWidget);
  });

  testWidgets('a voided row stays visible, struck through and dimmed', (
    tester,
  ) async {
    await pump(tester, row(voidedAt: DateTime(2026, 9, 10)), item: cola);

    // Still in the record, just marked: hidden from balances, not from history.
    expect(find.text('Jonas · 🥤 Cola ×2'), findsOneWidget);
    for (final finder in [
      find.text('Jonas · 🥤 Cola ×2'),
      find.text('-€3.00'),
    ]) {
      expect(
        tester.widget<Text>(finder).style?.decoration,
        TextDecoration.lineThrough,
      );
    }
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, lessThan(1));
  });

  testWidgets('a live row is not struck through', (tester) async {
    await pump(tester, row(), item: cola);

    for (final finder in [
      find.text('Jonas · 🥤 Cola ×2'),
      find.text('-€3.00'),
    ]) {
      expect(
        tester.widget<Text>(finder).style?.decoration,
        isNot(TextDecoration.lineThrough),
      );
    }
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });

  testWidgets('the per-user form leads with the item and drops the name', (
    tester,
  ) async {
    await pumpForUser(tester, row(), item: cola);

    // The page already says whose it is.
    expect(find.text('Jonas'), findsNothing);
    expect(find.text('🥤'), findsOneWidget);
    expect(find.text('Cola ×2'), findsOneWidget);
  });

  testWidgets('a top-up has no item, so it falls back to an icon', (
    tester,
  ) async {
    await pumpForUser(
      tester,
      row(
        type: TransactionType.topUp,
        amountMinorUnits: 1000,
        quantity: 1,
        itemNameSnapshot: null,
      ),
    );

    expect(find.byIcon(Icons.add_card), findsOneWidget);
    expect(find.text('Top-up'), findsOneWidget);
  });
}
