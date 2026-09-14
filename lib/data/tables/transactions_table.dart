import 'package:drift/drift.dart';

import 'items_table.dart';
import 'users_table.dart';

/// What a ledger row records.
///
/// Use [adjustment] for a genuine correction ("Jonas paid EUR 10 cash"), and
/// voiding for a mis-tap. Adjusting records; voiding erases.
enum TransactionType { consumption, topUp, adjustment }

/// The append-only ledger: rows are never DELETEd, and the only permitted
/// updates are the one-way `voidedAt` transition and confirming a top-up.
@DataClassName('TransactionRow')
// For balance lookups
@TableIndex(
  name: 'transactions_user_id_voided_at',
  columns: {#userId, #voidedAt},
)
@TableIndex(name: 'transactions_created_at', columns: {#createdAt})
// For the history and day lists, which include voided rows and every type.
@TableIndex(name: 'transactions_logical_date', columns: {#logicalDate})
// Statistics only ever read live consumptions, so these two hold nothing else
// and cover every column a stats query touches: each is an index-only scan.
// A query must repeat the predicate for SQLite to use them. `type` and
// `voided_at` trail because SQLite does not count the WHERE's own columns as
// covered, and would otherwise read every row back from the table.
@TableIndex.sql('''
  CREATE INDEX transactions_consumptions_by_day ON transactions (
    logical_date, user_id, item_id, quantity, created_at, type, voided_at
  ) WHERE type = 'consumption' AND voided_at IS NULL
''')
@TableIndex.sql('''
  CREATE INDEX transactions_consumptions_by_user ON transactions (
    user_id, logical_date, item_id, quantity, amount_minor_units, type,
    voided_at
  ) WHERE type = 'consumption' AND voided_at IS NULL
''')
// Partial, so it holds only the admin's backlog rather than every ledger row.
// The pending queries must repeat this predicate exactly for SQLite to use it.
@TableIndex.sql('''
  CREATE INDEX transactions_pending_top_ups ON transactions (created_at)
  WHERE type = 'topUp' AND confirmed_at IS NULL AND voided_at IS NULL
''')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  // A plain foreign key with no snapshot, unlike the item columns below: users
  // are identities, so renaming one should correct history everywhere. Items
  // are catalogue entries, so history keeps what it actually cost.
  IntColumn get userId => integer().references(Users, #id)();

  TextColumn get type => textEnum<TransactionType>()();

  /// The signed line total, never a unit price: negative is spending, positive
  /// is credit. Keeps the balance a single type-agnostic SUM.
  IntColumn get amountMinorUnits => integer()();

  /// Display only — [amountMinorUnits] already has this multiplied in.
  IntColumn get quantity => integer().withDefault(const Constant(1))();

  IntColumn get itemId => integer().nullable().references(Items, #id)();

  // Frozen at purchase time so renaming or repricing the item never rewrites
  // history. Null for top-ups and adjustments, which reference no item.
  TextColumn get itemNameSnapshot => text().nullable()();
  IntColumn get itemUnitPriceSnapshot => integer().nullable()();

  /// Required by the UI for an adjustment, optional otherwise.
  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// The 07:00 -> 07:00 day this row belongs to, as `YYYY-MM-DD`. Frozen at
  /// insert from [createdAt] like the item snapshots, and stored rather than
  /// derived because a `localtime` expression can never be indexed.
  TextColumn get logicalDate => text()();

  /// One-way: null -> timestamp, never cleared. The row itself is never
  /// rewritten, and voided rows still render in history, just struck through.
  DateTimeColumn get voidedAt => dateTime().nullable()();
  TextColumn get voidedNote => text().nullable()();

  /// Top-ups only: when an admin confirmed the money arrived. Bookkeeping, not
  /// accounting — balances ignore it.
  DateTimeColumn get confirmedAt => dateTime().nullable()();

  @override
  List<String> get customConstraints => const ['CHECK (quantity > 0)'];
}
