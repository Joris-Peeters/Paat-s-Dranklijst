import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/data/database_reset.dart';

import 'support/ledger.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(executor: NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Two users (one archived, one owing), an item, a consumption, a voided
  /// top-up and an adjustment: every kind of row a reset has to get past.
  Future<void> populate() async {
    final owing = await db.usersDao.createUser(
      name: 'Jonas',
      groupId: 1,
      avatarEmoji: '🦊',
      seedColorArgb: 0xFF009688,
    );
    final credit = await db.usersDao.createUser(
      name: 'Wout',
      groupId: 1,
      avatarEmoji: '🐻',
      seedColorArgb: 0xFF009688,
    );
    final leaver = await db.usersDao.createUser(
      name: 'Mira',
      groupId: 1,
      avatarEmoji: '🐼',
      seedColorArgb: 0xFF009688,
    );
    await db.usersDao.archiveUser(leaver);

    final itemId = await db.itemsDao.createItem(
      name: 'Cola',
      groupId: 1,
      priceMinorUnits: 150,
      emoji: '🥤',
    );
    final item = await (db.select(
      db.items,
    )..where((i) => i.id.equals(itemId))).getSingle();

    await db.logConsumption(userId: owing, item: item, quantity: 2);
    final topUp = await db.transactionsDao.logTopUp(
      userId: owing,
      amountMinorUnits: 500,
    );
    await db.transactionsDao.voidTransaction(topUp);
    await db.transactionsDao.logAdjustment(
      userId: credit,
      amountMinorUnits: 700,
      note: 'cash',
    );
  }

  Future<Map<String, int>> tableSizes() async => {
    'transactions': (await db.select(db.transactions).get()).length,
    'users': (await db.select(db.users).get()).length,
    'user_groups': (await db.select(db.userGroups).get()).length,
    'items': (await db.select(db.items).get()).length,
    'item_groups': (await db.select(db.itemGroups).get()).length,
  };

  test('counts what would go, and the balances it would clear', () async {
    await populate();
    final counts = await readResetCounts(db, ResetScope.users);
    expect(counts.transactions, 3);
    expect(counts.users, 3);
    expect(counts.userGroups, 1);
    expect(counts.items, 0, reason: 'this scope leaves items alone');
    expect(counts.debtorCount, 1);
    expect(counts.owedMinorUnits, -300);
    expect(counts.creditorCount, 1);
    expect(counts.heldMinorUnits, 700);

    final everything = await readResetCounts(db, ResetScope.everything);
    expect(everything.items, 1);
    expect(everything.itemGroups, 1);
  });

  final expected = <ResetScope, Map<String, int>>{
    ResetScope.transactions: {
      'transactions': 0,
      'users': 3,
      'user_groups': 1,
      'items': 1,
      'item_groups': 1,
    },
    ResetScope.users: {
      'transactions': 0,
      'users': 0,
      'user_groups': 0,
      'items': 1,
      'item_groups': 1,
    },
    ResetScope.items: {
      'transactions': 0,
      'users': 3,
      'user_groups': 1,
      'items': 0,
      'item_groups': 0,
    },
    ResetScope.everything: {
      'transactions': 0,
      'users': 0,
      'user_groups': 0,
      'items': 0,
      'item_groups': 0,
    },
  };

  for (final MapEntry(key: scope, value: sizes) in expected.entries) {
    test('${scope.name} empties exactly its tables', () async {
      await populate();
      await resetDatabase(db, scope);
      expect(await tableSizes(), sizes);
    });
  }
}
