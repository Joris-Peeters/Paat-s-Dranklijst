import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/data/errors.dart';
import 'package:paats_dranklijst/data/tables/transactions_table.dart';

/// The seeded group every fixture hangs off. `onCreate` inserts exactly one of
/// each kind, so this is always id 1.
const int seededGroup = 1;

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(executor: NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addMember({String name = 'Jonas'}) => db.usersDao.createUser(
    name: name,
    groupId: seededGroup,
    avatarEmoji: '🦊',
    seedColorArgb: 0xFF009688,
  );

  Future<ItemRow> addItem({String name = 'Cola', int price = 150}) async {
    final id = await db.itemsDao.createItem(
      name: name,
      groupId: seededGroup,
      priceMinorUnits: price,
      emoji: '🥤',
    );
    return (db.select(
      db.items,
    )..where((i) => i.id.equals(id))).getSingle();
  }

  group('schema', () {
    test('foreign key enforcement is actually on', () async {
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(row.read<bool>('foreign_keys'), isTrue);
    });

    test('onCreate seeds the settings row and one group of each kind', () async {
      expect((await db.settingsDao.readSettings()).id, 1);
      expect(await db.select(db.userGroups).get(), hasLength(1));
      expect(await db.select(db.itemGroups).get(), hasLength(1));
    });

    test('a member cannot point at a group that does not exist', () async {
      // Matched on the message rather than the type: a constraint violation
      // surfaces as SqliteException here but as DriftRemoteException in the
      // app, which runs the database on a background isolate.
      await expectLater(
        db.usersDao.createUser(
          name: 'Ghost',
          groupId: 999,
          avatarEmoji: '👻',
          seedColorArgb: 0xFF009688,
        ),
        throwsA(
          isA<Object>().having(
            (e) => e.toString(),
            'message',
            contains('FOREIGN KEY'),
          ),
        ),
      );
    });

    test('quantity must be positive', () async {
      final user = await addMember();
      await expectLater(
        db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                userId: user,
                type: TransactionType.consumption,
                amountMinorUnits: -150,
                quantity: const Value(0),
              ),
            ),
        throwsA(
          isA<Object>().having(
            (e) => e.toString(),
            'message',
            contains('CHECK constraint'),
          ),
        ),
      );
    });
  });

  group('balances', () {
    test('a member with no transactions has a zero balance', () async {
      final user = await addMember();
      expect(await db.usersDao.readBalance(user), 0);
    });

    test('balance is the signed sum of every live row', () async {
      final user = await addMember();
      final cola = await addItem(price: 150);

      await db.transactionsDao.logTopUp(userId: user, amountMinorUnits: 1000);
      await db.transactionsDao.logConsumption(userId: user, item: cola);
      await db.transactionsDao.logConsumption(userId: user, item: cola);

      // 1000 - 150 - 150
      expect(await db.usersDao.readBalance(user), 700);
    });

    test('a consumption stores the line total, not the unit price', () async {
      final user = await addMember();
      final cola = await addItem(price: 150);

      final id = await db.transactionsDao.logConsumption(
        userId: user,
        item: cola,
        quantity: 2,
      );

      final row = await db.transactionsDao.readTransaction(id);
      expect(row!.amountMinorUnits, -300);
      expect(row.quantity, 2);
      expect(row.itemUnitPriceSnapshot, 150);
      expect(await db.usersDao.readBalance(user), -300);
    });

    test('an adjustment moves the balance either way', () async {
      final user = await addMember();
      await db.transactionsDao.logAdjustment(
        userId: user,
        amountMinorUnits: -250,
        note: 'Broke a glass',
      );
      expect(await db.usersDao.readBalance(user), -250);
    });

    test('watchMembersWithBalances reports zero for an untouched member', () async {
      await addMember(name: 'Silent');
      final members = await db.usersDao.watchMembersWithBalances().first;
      expect(members, hasLength(1));
      expect(members.single.balanceMinorUnits, 0);
      expect(members.single.group.id, seededGroup);
    });
  });

  group('voiding', () {
    test('a voided row leaves the balance but stays in the history', () async {
      final user = await addMember();
      final cola = await addItem(price: 150);
      final id = await db.transactionsDao.logConsumption(
        userId: user,
        item: cola,
      );

      expect(await db.usersDao.readBalance(user), -150);
      await db.transactionsDao.voidTransaction(id, note: 'mis-tap');
      expect(await db.usersDao.readBalance(user), 0);

      final history = await db.transactionsDao.watchUserHistory(user).first;
      expect(history, hasLength(1));
      expect(history.single.voidedNote, 'mis-tap');
    });

    test('voiding is one-way: a second call changes nothing', () async {
      final user = await addMember();
      final cola = await addItem();
      final id = await db.transactionsDao.logConsumption(
        userId: user,
        item: cola,
      );

      await db.transactionsDao.voidTransaction(id, note: 'first');
      final first = await db.transactionsDao.readTransaction(id);

      await db.transactionsDao.voidTransaction(id, note: 'second');
      final second = await db.transactionsDao.readTransaction(id);

      expect(second!.voidedAt, first!.voidedAt);
      expect(second.voidedNote, 'first');
    });

    test('the ledger row itself is never rewritten', () async {
      final user = await addMember();
      final cola = await addItem(name: 'Cola', price: 150);
      final id = await db.transactionsDao.logConsumption(
        userId: user,
        item: cola,
      );
      final before = await db.transactionsDao.readTransaction(id);

      await db.transactionsDao.voidTransaction(id);
      final after = await db.transactionsDao.readTransaction(id);

      expect(after!.amountMinorUnits, before!.amountMinorUnits);
      expect(after.itemNameSnapshot, before.itemNameSnapshot);
      expect(after.itemUnitPriceSnapshot, before.itemUnitPriceSnapshot);
      expect(after.createdAt, before.createdAt);
    });
  });

  group('snapshots', () {
    test('renaming and repricing an item does not rewrite history', () async {
      final user = await addMember();
      final cola = await addItem(name: 'Cola', price: 150);
      final id = await db.transactionsDao.logConsumption(
        userId: user,
        item: cola,
      );

      await db.itemsDao.updateItem(
        cola.id,
        const ItemsCompanion(
          name: Value('Coca-Cola'),
          priceMinorUnits: Value(200),
        ),
      );

      final row = await db.transactionsDao.readTransaction(id);
      expect(row!.itemNameSnapshot, 'Cola');
      expect(row.itemUnitPriceSnapshot, 150);
      expect(row.amountMinorUnits, -150);
      expect(await db.usersDao.readBalance(user), -150);
    });
  });

  group('archiving', () {
    test('a member with a balance cannot be archived', () async {
      final user = await addMember();
      final cola = await addItem();
      await db.transactionsDao.logConsumption(userId: user, item: cola);

      await expectLater(
        db.usersDao.archiveUser(user),
        throwsA(isA<MemberHasBalanceException>()),
      );
    });

    test('a settled member can be archived and restored', () async {
      final user = await addMember();
      final cola = await addItem(price: 150);
      await db.transactionsDao.logConsumption(userId: user, item: cola);
      await db.transactionsDao.logTopUp(userId: user, amountMinorUnits: 150);

      await db.usersDao.archiveUser(user);
      expect(await db.usersDao.watchUsers().first, isEmpty);
      expect(
        await db.usersDao.watchUsers(includeArchived: true).first,
        hasLength(1),
      );

      await db.usersDao.restoreUser(user);
      expect(await db.usersDao.watchUsers().first, hasLength(1));
    });
  });

  group('group deletion', () {
    test('an archived member still pins their group', () async {
      final user = await addMember();
      await db.usersDao.archiveUser(user);
      final extra = await db.usersDao.createUserGroup(name: 'Rakkers');

      // The seeded group looks empty on screen — the member is archived — but
      // still holds a foreign key, so deleting it would dangle.
      final usage = await db.usersDao.userGroupUsage(seededGroup);
      expect(usage.activeCount, 0);
      expect(usage.archivedCount, 1);

      await expectLater(
        db.usersDao.deleteUserGroup(seededGroup),
        throwsA(isA<GroupInUseException>()),
      );
      // The empty one deletes fine.
      await db.usersDao.deleteUserGroup(extra);
    });

    test('the last group may be deleted while it is empty', () async {
      // Including the seeded one: the management screen has a + button, so an
      // admin can always make another.
      await db.usersDao.deleteUserGroup(seededGroup);
      await db.itemsDao.deleteItemGroup(seededGroup);

      expect(await db.select(db.userGroups).get(), isEmpty);
      expect(await db.select(db.itemGroups).get(), isEmpty);
    });

    test('an item group holding an archived item cannot be deleted', () async {
      final item = await addItem();
      await db.itemsDao.archiveItem(item.id);
      await db.itemsDao.createItemGroup(name: 'Bier');

      await expectLater(
        db.itemsDao.deleteItemGroup(seededGroup),
        throwsA(isA<GroupInUseException>()),
      );
    });
  });

  group('ordering', () {
    test('new rows land at the end', () async {
      await addMember(name: 'A');
      await addMember(name: 'B');
      await addMember(name: 'C');

      final names = (await db.usersDao.watchUsers().first)
          .map((u) => u.name)
          .toList();
      expect(names, ['A', 'B', 'C']);
    });

    test('reorderUsers renumbers 0..n-1', () async {
      final a = await addMember(name: 'A');
      final b = await addMember(name: 'B');
      final c = await addMember(name: 'C');

      await db.usersDao.reorderUsers([c, a, b]);

      final users = await db.usersDao.watchUsers().first;
      expect(users.map((u) => u.name), ['C', 'A', 'B']);
      expect(users.map((u) => u.sortOrder), [0, 1, 2]);
    });
  });
}
