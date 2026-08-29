import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'daos/settings_dao.dart';
import 'tables/settings_table.dart';

part 'database.g.dart';

/// The app database. Adding a table later means a file in `tables/`, a DAO in
/// `daos/`, and an entry in the two lists below.
@DriftDatabase(tables: [Settings], daos: [SettingsDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor})
    : super(executor ?? driftDatabase(name: _databaseName, native: _location));

  /// drift_flutter defaults to the *documents* directory, which on Linux is the
  /// user's own `~/Documents`. The application support directory is app-scoped
  /// on all three target platforms, which is where an internal file belongs.
  static const _location = DriftNativeOptions(
    databaseDirectory: getApplicationSupportDirectory,
  );

  static const _databaseName = 'paats_dranklijst';

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
    },
    onUpgrade: (m, from, to) async {
      // Scaffolding: schemaVersion is still 1, so nothing runs here yet. Steps
      // get added here alongside every future schemaVersion bump.
    },
  );
}
