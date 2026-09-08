import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
// The generated part below is a `part of` this file, so it has no imports of
// its own: every converter and every type one surfaces has to be in scope here.
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:path_provider/path_provider.dart';

import 'converters.dart';
import 'daos/items_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/transactions_dao.dart';
import 'daos/users_dao.dart';
import 'tables/item_groups_table.dart';
import 'tables/items_table.dart';
import 'tables/settings_table.dart';
import 'tables/transactions_table.dart';
import 'tables/user_groups_table.dart';
import 'tables/users_table.dart';
import 'views/user_balances_view.dart';

part 'database.g.dart';

/// The app database. Adding a table later means a file in `tables/`, a DAO in
/// `daos/`, and an entry in the lists below. Indexes are not listed: the
/// `@TableIndex` annotations put them in the schema on their own.
@DriftDatabase(
  tables: [Settings, UserGroups, Users, ItemGroups, Items, Transactions],
  views: [UserBalances],
  daos: [SettingsDao, UsersDao, ItemsDao, TransactionsDao],
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
      // Insert the settings row up front so nothing anywhere has to handle
      // "settings is null because the table is empty". Every column takes its
      // schema default; the first-run wizard is where those get changed.
      await into(settings).insert(SettingsCompanion.insert(id: const Value(1)));
      // groupId is non-null on both users and items, so without one group of
      // each kind a fresh install could not create either — "add member" would
      // have nothing to point at. Plain names an admin renames.
      await into(userGroups).insert(UserGroupsCompanion.insert(name: 'General'));
      await into(itemGroups).insert(ItemGroupsCompanion.insert(name: 'General'));
    },
    onUpgrade: (m, from, to) async {
      // Scaffolding: schemaVersion is still 1, so nothing runs here yet. Steps
      // get added here alongside every future schemaVersion bump.
    },
    // SQLite leaves foreign keys OFF by default, and drift only toggles it
    // around alterTable. Never wrap this in a transaction — the pragma is
    // silently ignored there.
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
