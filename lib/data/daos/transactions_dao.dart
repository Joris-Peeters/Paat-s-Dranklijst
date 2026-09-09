import 'package:drift/drift.dart';

import '../database.dart';
import '../logical_day.dart';
import '../tables/items_table.dart';
import '../tables/transactions_table.dart';

part 'transactions_dao.g.dart';

/// The append-only ledger.
///
/// This is the only place in the app that writes a transaction row, so the sign
/// convention and the item snapshot freeze are decided in exactly one file.
/// Nothing here DELETEs.
@DriftAccessor(tables: [Transactions, Items])
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

  /// Takes the whole [item] rather than an id so the price that gets frozen is
  /// the one the member actually tapped, not one re-read afterwards.
  Future<int> logConsumption({
    required int userId,
    required ItemRow item,
    int quantity = 1,
  }) {
    assert(quantity > 0, 'quantity must be positive');
    final stamp = _stamp();
    return into(transactions).insert(
      TransactionsCompanion.insert(
        userId: userId,
        type: TransactionType.consumption,
        // Negative, and the line total rather than the unit price: the balance
        // is a plain SUM over this column.
        amountMinorUnits: -(item.priceMinorUnits * quantity),
        quantity: Value(quantity),
        itemId: Value(item.id),
        itemNameSnapshot: Value(item.name),
        itemUnitPriceSnapshot: Value(item.priceMinorUnits),
        createdAt: stamp.createdAt,
        logicalDate: stamp.logicalDate,
      ),
    );
  }

  /// Positive: the member handed over money.
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
    await (update(transactions)
          ..where((t) => t.id.equals(id) & t.voidedAt.isNull()))
        .write(
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
  /// member. Voided rows and non-consumption types are excluded: a mis-tap is
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
  }) => (select(transactions)
        ..where((t) => t.logicalDate.equals(logicalDayKey(at)))
        ..orderBy([
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
        ]))
      .watch();

  Future<TransactionRow?> readTransaction(int id) => (select(
    transactions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();
}
