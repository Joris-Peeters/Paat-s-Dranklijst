import 'package:drift/drift.dart';

import '../database.dart';
import '../logical_day.dart';
import '../tables/items_table.dart';
import '../tables/transactions_table.dart';
import '../tables/users_table.dart';

part 'transactions_dao.g.dart';

/// A ledger row with everything a history line needs to draw itself.
///
/// The row holds a `userId` and an `itemId` and snapshots neither the user nor
/// the item's emoji, so a line is two joins short of renderable. Doing them once
/// here beats two queries per row.
///
/// [item] is null for top-ups and adjustments, which reference none. It is also
/// the *current* item, so an emoji that has since changed shows as it is now —
/// the same trade the user's name makes, and the opposite of the price, which is
/// snapshotted because what was paid is a fact.
class TransactionEntry {
  const TransactionEntry({
    required this.transaction,
    required this.user,
    required this.item,
  });

  final TransactionRow transaction;
  final UserRow user;
  final ItemRow? item;
}

/// The append-only ledger.
///
/// This is the only place in the app that writes a transaction row, so the sign
/// convention and the item snapshot freeze are decided in exactly one file. The
/// only DELETE is [undoConsumption], which the five-second snackbar owns.
@DriftAccessor(tables: [Transactions, Items, Users])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  // Both stamps come from one clock read, so the column's own
  // `currentDateAndTime` default is deliberately not used here: a row inserted
  // microseconds either side of 07:00 must not take its timestamp and its
  // logical day from different days.
  ({Value<DateTime> createdAt, String logicalDate}) _stamp() {
    final now = DateTime.now();
    return (createdAt: Value(now), logicalDate: logicalDayKey(now));
  }

  /// One consumption line. Shared by the single tap and the multi-item order so
  /// the sign convention and the snapshot freeze are written once.
  TransactionsCompanion _consumption({
    required int userId,
    required ItemRow item,
    required int quantity,
    required ({Value<DateTime> createdAt, String logicalDate}) stamp,
  }) => TransactionsCompanion.insert(
    userId: userId,
    type: TransactionType.consumption,
    // Negative, and the line total rather than the unit price: the balance is a
    // plain SUM over this column.
    amountMinorUnits: -(item.priceMinorUnits * quantity),
    quantity: Value(quantity),
    itemId: Value(item.id),
    itemNameSnapshot: Value(item.name),
    itemUnitPriceSnapshot: Value(item.priceMinorUnits),
    createdAt: stamp.createdAt,
    logicalDate: stamp.logicalDate,
  );

  /// Takes the whole [item] rather than an id so the price that gets frozen is
  /// the one the user actually tapped, not one re-read afterwards.
  Future<int> logConsumption({
    required int userId,
    required ItemRow item,
    int quantity = 1,
  }) {
    assert(quantity > 0, 'quantity must be positive');
    return into(transactions).insert(
      _consumption(
        userId: userId,
        item: item,
        quantity: quantity,
        stamp: _stamp(),
      ),
    );
  }

  /// One order of several different items, as a row each.
  ///
  /// All in one transaction and all sharing a single clock read: the rows are
  /// one trip to the fridge, so they must not straddle the 07:00 boundary,
  /// appear in the balance one at a time, or half-survive a failure.
  Future<List<int>> logConsumptions({
    required int userId,
    required List<({ItemRow item, int quantity})> lines,
  }) {
    assert(lines.isNotEmpty, 'an order needs at least one line');
    final stamp = _stamp();

    return transaction(() async {
      final ids = <int>[];
      for (final line in lines) {
        assert(line.quantity > 0, 'quantity must be positive');
        ids.add(
          await into(transactions).insert(
            _consumption(
              userId: userId,
              item: line.item,
              quantity: line.quantity,
              stamp: stamp,
            ),
          ),
        );
      }
      return ids;
    });
  }

  /// Removes rows the five-second snackbar undo is still offering to take back.
  ///
  /// The only DELETE anywhere in the app, and the only reversal that does not
  /// take the admin PIN. It is safe precisely because it is unreachable by
  /// anyone but the person still standing at the fridge, and a row that existed
  /// for five seconds has told nobody anything. Every later correction voids
  /// instead, which leaves the row in the record.
  Future<void> undoConsumption(List<int> transactionIds) async {
    if (transactionIds.isEmpty) return;
    await (delete(transactions)..where((t) => t.id.isIn(transactionIds))).go();
  }

  /// Positive: the user handed over money.
  Future<int> logTopUp({
    required int userId,
    required int amountMinorUnits,
    String? note,
  }) {
    assert(amountMinorUnits > 0, 'a top-up adds credit');
    final stamp = _stamp();
    return into(transactions).insert(
      TransactionsCompanion.insert(
        userId: userId,
        type: TransactionType.topUp,
        amountMinorUnits: amountMinorUnits,
        note: Value(note),
        createdAt: stamp.createdAt,
        logicalDate: stamp.logicalDate,
      ),
    );
  }

  /// Signed either way, and the note is required: an adjustment records a
  /// correction rather than erasing a mistake. Voiding erases; this does not.
  Future<int> logAdjustment({
    required int userId,
    required int amountMinorUnits,
    required String note,
  }) {
    final stamp = _stamp();
    return into(transactions).insert(
      TransactionsCompanion.insert(
        userId: userId,
        type: TransactionType.adjustment,
        amountMinorUnits: amountMinorUnits,
        note: Value(note),
        createdAt: stamp.createdAt,
        logicalDate: stamp.logicalDate,
      ),
    );
  }

  /// One-way: null -> timestamp, never cleared, never a DELETE. The
  /// `voidedAt IS NULL` guard makes a second call a no-op, and the amount,
  /// snapshots and createdAt are left untouched.
  Future<void> voidTransaction(int id, {String? note}) async {
    await (update(
      transactions,
    )..where((t) => t.id.equals(id) & t.voidedAt.isNull())).write(
      TransactionsCompanion(
        voidedAt: Value(DateTime.now()),
        voidedNote: Value(note),
      ),
    );
  }

  /// Newest first. Voided rows are included — they stay in the record, struck
  /// through; they are only hidden from balances.
  Stream<List<TransactionRow>> watchRecentTransactions({int limit = 50}) =>
      (select(transactions)
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.createdAt,
                mode: OrderingMode.desc,
              ),
            ])
            ..limit(limit))
          .watch();

  /// Newest first, with every filter the history screen offers.
  ///
  /// Voided rows are always included — they stay in the record, struck through,
  /// and are only hidden from balances.
  ///
  /// [from] and [to] are logical *days*, both ends inclusive, and their time of
  /// day is ignored — they name which days to keep, not an instant to measure
  /// from. So a range of "6 to 10 September" holds a drink taken at 01:00 on
  /// the 11th, the way every other per-day question in the app does.
  Stream<List<TransactionEntry>> watchHistory({
    int? userId,
    int? itemGroupId,
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int limit = 50,
  }) {
    final query =
        select(transactions).join([
            innerJoin(users, users.id.equalsExp(transactions.userId)),
            // Outer, because a top-up references no item at all.
            leftOuterJoin(items, items.id.equalsExp(transactions.itemId)),
          ])
          ..orderBy([
            OrderingTerm(
              expression: transactions.createdAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(limit);

    if (userId != null) {
      query.where(transactions.userId.equals(userId));
    }
    // Over the outer join this also drops top-ups and adjustments, which is
    // right: asking for a category is asking about drinks.
    if (itemGroupId != null) {
      query.where(items.groupId.equals(itemGroupId));
    }
    if (type != null) {
      query.where(transactions.type.equalsValue(type));
    }
    // Compared as `YYYY-MM-DD` text, which sorts the same way the dates do and
    // is what `transactions_logical_date` indexes.
    if (from != null) {
      query.where(
        transactions.logicalDate.isBiggerOrEqualValue(logicalDayToKey(from)),
      );
    }
    if (to != null) {
      query.where(
        transactions.logicalDate.isSmallerOrEqualValue(logicalDayToKey(to)),
      );
    }

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => TransactionEntry(
              transaction: row.readTable(transactions),
              user: row.readTable(users),
              item: row.readTableOrNull(items),
            ),
          )
          .toList(),
    );
  }

  Stream<List<TransactionRow>> watchUserHistory(int userId) =>
      (select(transactions)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.createdAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  /// What left the fridge on the logical day containing [at]: how many items,
  /// and what they came to. Optionally for one user.
  ///
  /// Voided rows and the non-consumption types are excluded — a mis-tap is not
  /// a drink, and a top-up is not turnover. [quantity] sums the column rather
  /// than counting rows, because an order of three colas is one row.
  ///
  /// `turnoverMinorUnits` comes back positive. Consumption amounts are
  /// negative, being balance movements; turnover is money taken, so the sign is
  /// flipped once here rather than at every call site.
  ///
  /// [at] is required rather than defaulting to now: a stream resolves its day
  /// once, at subscription, so on a kiosk left running for months an implicit
  /// "now" would keep reporting yesterday after 07:00. The caller decides how
  /// it refreshes.
  Stream<({int quantity, int turnoverMinorUnits})> watchDayTotals({
    required DateTime at,
    int? userId,
  }) {
    final quantity = transactions.quantity.sum();
    final amount = transactions.amountMinorUnits.sum();

    final query = selectOnly(transactions)
      ..addColumns([quantity, amount])
      ..where(
        transactions.logicalDate.equals(logicalDayKey(at)) &
            transactions.type.equalsValue(TransactionType.consumption) &
            transactions.voidedAt.isNull(),
      );
    if (userId != null) {
      query.where(transactions.userId.equals(userId));
    }

    // Both sums are null over a day with nothing in it, so the `?? 0` lands
    // here rather than at every call site.
    return query.watchSingle().map(
      (row) => (
        quantity: row.read(quantity) ?? 0,
        turnoverMinorUnits: -(row.read(amount) ?? 0),
      ),
    );
  }

  /// Everything on that logical day, newest first. Voided rows are included —
  /// they stay in the record, struck through.
  Stream<List<TransactionRow>> watchTransactionsForDay({
    required DateTime at,
  }) =>
      (select(transactions)
            ..where((t) => t.logicalDate.equals(logicalDayKey(at)))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.createdAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  Future<TransactionRow?> readTransaction(int id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
}
