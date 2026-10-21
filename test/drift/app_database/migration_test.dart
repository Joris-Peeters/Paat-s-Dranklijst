import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;

/// Upgrades from each schema dumped in `drift_schemas/` by
/// `drift_dev make-migrations`, the versions installed devices can still hold.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  // Migrated must equal freshly created, indexes included.
  group('every upgrade ends at the current schema', () {
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      for (final toVersion in versions.skip(i + 1)) {
        test('from $fromVersion to $toVersion', () async {
          final schema = await verifier.schemaAt(fromVersion);
          final db = AppDatabase(executor: schema.newConnection());
          await verifier.migrateAndValidate(db, toVersion);
          await db.close();
        });
      }
    }
  });

  test('a v1 ledger reads by hour per user after upgrading', () async {
    final schema = await verifier.schemaAt(1);
    // Written through the frozen v1 classes, so this keeps meaning a v1 file.
    final old = v1.DatabaseAtV1(schema.newConnection());
    await old.batch((batch) {
      batch
        ..insert(old.userGroups, v1.UserGroupsCompanion.insert(name: 'General'))
        ..insert(old.itemGroups, v1.ItemGroupsCompanion.insert(name: 'General'))
        ..insert(
          old.users,
          v1.UsersCompanion.insert(
            name: 'Ann',
            avatarEmoji: '🦊',
            seedColorArgb: 0xFF00897B,
            groupId: 1,
          ),
        )
        ..insert(
          old.items,
          v1.ItemsCompanion.insert(
            name: 'Cola',
            emoji: '🥤',
            groupId: 1,
            priceMinorUnits: 150,
          ),
        )
        ..insert(
          old.transactions,
          v1.TransactionsCompanion.insert(
            userId: 1,
            type: 'consumption',
            amountMinorUnits: -300,
            quantity: const Value(2),
            itemId: const Value(1),
            itemNameSnapshot: const Value('Cola'),
            itemUnitPriceSnapshot: const Value(150),
            createdAt: Value(
              DateTime(2026, 9, 13, 1, 30).millisecondsSinceEpoch ~/ 1000,
            ),
            logicalDate: '2026-09-12',
          ),
        );
    });
    await old.close();

    // Opening it as the app runs the upgrade.
    final db = AppDatabase(executor: schema.newConnection());
    addTearDown(db.close);
    expect(await db.statsDao.watchUserHourOfNight(1).first, [
      (hour: 1, count: 2),
    ]);
  });
}
