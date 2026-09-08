import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/items_table.dart';
import '../tables/transactions_table.dart';

part 'transactions_dao.g.dart';

/// The append-only ledger.
///
/// This is the only place in the app that writes a transaction row, so the sign
/// convention (rule 1) and the item snapshot freeze are decided in exactly one
/// file. Nothing here DELETEs.
@DriftAccessor(tables: [Transactions, Items])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  /// Takes the whole [item] rather than an id so the price that gets frozen is
  /// the one the member actually tapped, not one re-read afterwards.
  Future<int> logConsumption({
    required int userId,
    required ItemRow item,
    int quantity = 1,
  }) {
    assert(quantity > 0, 'quantity must be positive');
    return into(transactions).insert(
      TransactionsCompanion.insert(
        userId: userId,
        type: TransactionType.consumption,
        // Negative, and the line total rather than the unit price: the balance
        // is a plain SUM over this column. See rule 1.
        amountMinorUnits: -(item.priceMinorUnits * quantity),
        quantity: Value(quantity),
        itemId: Value(item.id),
        itemNameSnapshot: Value(item.name),
        itemUnitPriceSnapshot: Value(item.priceMinorUnits),
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
    return into(transactions).insert(
      TransactionsCompanion.insert(
        userId: userId,
        type: TransactionType.topUp,
        amountMinorUnits: amountMinorUnits,
        note: Value(note),
      ),
    );
  }

  /// Signed either way, and the note is required: an adjustment records a
  /// correction rather than erasing a mistake. Voiding erases; this does not.
  Future<int> logAdjustment({
    required int userId,
    required int amountMinorUnits,
    required String note,
  }) => into(transactions).insert(
    TransactionsCompanion.insert(
      userId: userId,
      type: TransactionType.adjustment,
      amountMinorUnits: amountMinorUnits,
      note: Value(note),
    ),
  );

  /// One-way: null -> timestamp, never cleared, never a DELETE. The
  /// `voidedAt IS NULL` guard makes a second call a no-op rather than a second
  /// timestamp. The amount, snapshots and createdAt are left untouched.
  ///
  /// Who may call this is UI policy: an inline undo within the first minute,
  /// the admin PIN and a note after that.
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

  Future<TransactionRow?> readTransaction(int id) => (select(
    transactions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();
}
