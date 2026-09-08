import 'package:drift/drift.dart';

import 'items_table.dart';
import 'users_table.dart';

/// What a ledger row records.
///
/// Use [adjustment] for a genuine correction ("Jonas paid EUR 10 cash"), and
/// voiding for a mis-tap. Adjusting records; voiding erases.
enum TransactionType { consumption, topUp, adjustment }

/// The append-only ledger. See rule 1: rows are never DELETEd, and the only
/// permitted update is the one-way `voidedAt` transition.
@DataClassName('TransactionRow')
// For balance lookups
@TableIndex(
  name: 'transactions_user_id_voided_at',
  columns: {#userId, #voidedAt},
)
@TableIndex(name: 'transactions_created_at', columns: {#createdAt})
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  // A plain foreign key with no snapshot, unlike the item columns below: users
  // are identities, so renaming one should correct history everywhere. Items
  // are catalogue entries, so history keeps what it actually cost.
  IntColumn get userId => integer().references(Users, #id)();

  TextColumn get type => textEnum<TransactionType>()();

  /// The signed **line total**, never a unit price: negative is spending,
  /// positive is credit the member holds. Makes the balance one type-agnostic
  /// SUM, so a fourth transaction type would need no balance changes.
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

  /// One-way: null -> timestamp, never cleared. The row itself is never
  /// rewritten, and voided rows still render in history, just struck through.
  DateTimeColumn get voidedAt => dateTime().nullable()();
  TextColumn get voidedNote => text().nullable()();

  @override
  List<String> get customConstraints => const ['CHECK (quantity > 0)'];
}
