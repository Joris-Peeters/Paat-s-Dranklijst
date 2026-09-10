import 'package:drift/drift.dart';

import 'user_groups_table.dart';

/// A user. Never hard-deleted once they have a ledger row.
///
/// No unique constraint on [name]: two users really can both be called Jonas.
/// The management screen warns on a duplicate; the schema does not forbid one.
@DataClassName('UserRow')
@TableIndex(name: 'users_group_id', columns: {#groupId})
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  // Always set: the create screen picks a random one.
  TextColumn get avatarEmoji => text()();

  // Reserved for the camera feature; here now so it needs no migration later.
  BlobColumn get avatarImage => blob().nullable()();

  // Resolved ARGB.
  IntColumn get seedColorArgb => integer()();

  IntColumn get groupId => integer().references(UserGroups, #id)();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Soft delete: a departed user's ledger history stays intact and readable.
  DateTimeColumn get archivedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
