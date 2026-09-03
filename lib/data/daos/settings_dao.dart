import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/settings_table.dart';

part 'settings_dao.g.dart';

/// Queries against the single settings row.
@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  /// Always emits: the row is created in `onCreate`, so it is never missing.
  Stream<SettingsRow> watchSettings() =>
      (select(settings)..where((t) => t.id.equals(1))).watchSingle();

  Future<SettingsRow> readSettings() =>
      (select(settings)..where((t) => t.id.equals(1))).getSingle();

  Future<void> updateSettings(SettingsCompanion changes) async {
    await (update(settings)..where((t) => t.id.equals(1))).write(changes);
  }
}
