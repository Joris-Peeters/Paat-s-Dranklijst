import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'daos/items_dao.dart';
import 'daos/transactions_dao.dart';
import 'daos/users_dao.dart';
import 'tables/item_groups_table.dart';
import 'tables/items_table.dart';
import 'tables/transactions_table.dart';
import 'tables/user_groups_table.dart';
import 'tables/users_table.dart';
import 'views/user_balances_view.dart';

part 'database.g.dart';

/// The app database. Adding a table later means a file in `tables/`, a DAO in
/// `daos/`, and an entry in the lists below. Indexes are not listed: the
/// `@TableIndex` annotations put them in the schema on their own.
@DriftDatabase(
  tables: [UserGroups, Users, ItemGroups, Items, Transactions],
  views: [UserBalances],
  daos: [UsersDao, ItemsDao, TransactionsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor})
    : super(
        executor ??
            driftDatabase(
              name: 'paats_dranklijst',
              native: const DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // groupId is non-null on both users and items, so without one group of
      // each kind a fresh install could not create either. Plain names, so an
      // admin renames them rather than reading them as sample data.
      await into(userGroups).insert(UserGroupsCompanion.insert(name: 'General'));
      await into(itemGroups).insert(ItemGroupsCompanion.insert(name: 'General'));
    },
    // SQLite leaves foreign keys OFF by default, and drift only toggles it
    // around alterTable. Never wrap this in a transaction — the pragma is
    // silently ignored there.
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
