import 'package:drift/drift.dart';

import 'item_groups_table.dart';

// An item on offer.
@DataClassName('ItemRow')
@TableIndex(name: 'items_group_id', columns: {#groupId})
class Items extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  /// Always set: the create screen picks a random one.
  TextColumn get emoji => text()();

  IntColumn get groupId => integer().references(ItemGroups, #id)();

  /// The *current* price. Transactions freeze their own copy, so changing this
  /// never rewrites what someone already paid.
  IntColumn get priceMinorUnits => integer()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Soft delete: a discontinued drink stays referenced by the ledger.
  DateTimeColumn get archivedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
