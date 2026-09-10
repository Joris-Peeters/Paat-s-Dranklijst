import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/data/tables/transactions_table.dart';
import 'package:paats_dranklijst/widgets/transaction_list_tile.dart';

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

  Future<void> pump(WidgetTester tester, TransactionRow transaction) async =>
      tester.pumpWidget(
        await settingsHarness(
          TransactionListTile(transaction: transaction, user: user),
        ),
      );

  testWidgets('more than one of an item says so', (tester) async {
    await pump(tester, row());

    expect(find.text('Cola ×2'), findsOneWidget);
    // The line total, not the unit price.
    expect(find.text('-€3.00'), findsOneWidget);
  });

  testWidgets('a single item is named on its own', (tester) async {
    await pump(tester, row(quantity: 1, amountMinorUnits: -150));

    expect(find.text('Cola'), findsOneWidget);
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

    expect(find.text('Cash'), findsOneWidget);
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

    expect(find.text('Top-up'), findsOneWidget);
  });

  testWidgets('a voided row stays visible, struck through and dimmed', (
    tester,
  ) async {
    await pump(tester, row(voidedAt: DateTime(2026, 9, 10)));

    // Still in the record, just marked: hidden from balances, not from history.
    expect(find.text('Cola ×2'), findsOneWidget);
    for (final finder in [
      find.text('Jonas'),
      find.text('Cola ×2'),
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
    await pump(tester, row());

    for (final finder in [
      find.text('Jonas'),
      find.text('Cola ×2'),
      find.text('-€3.00'),
    ]) {
      expect(
        tester.widget<Text>(finder).style?.decoration,
        isNot(TextDecoration.lineThrough),
      );
    }
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });
}
