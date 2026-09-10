import 'package:drift/drift.dart';

import '../database.dart';
import '../logical_day.dart';
import '../tables/items_table.dart';
import '../tables/transactions_table.dart';
import '../tables/users_table.dart';

part 'transactions_dao.g.dart';

/// A ledger row with the user it belongs to.
///
/// The row itself holds only a `userId` — users are identities, so history is
/// never snapshotted — which leaves a history line one lookup short. Joining it
/// once here beats a query per row.
class TransactionWithUser {
  const TransactionWithUser({required this.transaction, required this.user});

  final TransactionRow transaction;
  final UserRow user;
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

  /// Newest first, each row carrying its user — for a feed that mixes
  /// users and so cannot take the name from a page header.
  Stream<List<TransactionWithUser>> watchRecentTransactionsWithUsers({
    int limit = 50,
  }) {
    final query =
        select(transactions)
            .join([innerJoin(users, users.id.equalsExp(transactions.userId))])
          ..orderBy([
            OrderingTerm(
              expression: transactions.createdAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(limit);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => TransactionWithUser(
              transaction: row.readTable(transactions),
              user: row.readTable(users),
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

  /// Consumptions on the logical day containing [at], optionally for one
  /// user. Voided rows and non-consumption types are excluded: a mis-tap is
  /// not a drink, and a top-up is not one either.
  ///
  /// [at] is required rather than defaulting to now: a stream resolves its day
  /// once, at subscription, so on a kiosk left running for months an implicit
  /// "now" would keep reporting yesterday after 07:00. The caller decides how
  /// it refreshes.
  Stream<int> watchConsumptionCount({required DateTime at, int? userId}) {
    final count = countAll();
    final query = selectOnly(transactions)
      ..addColumns([count])
      ..where(
        transactions.logicalDate.equals(logicalDayKey(at)) &
            transactions.type.equalsValue(TransactionType.consumption) &
            transactions.voidedAt.isNull(),
      );
    if (userId != null) {
      query.where(transactions.userId.equals(userId));
    }
    return query.watchSingle().map((row) => row.read(count)!);
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
