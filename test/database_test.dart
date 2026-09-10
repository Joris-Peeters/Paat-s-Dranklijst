import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/data/errors.dart';
import 'package:paats_dranklijst/data/logical_day.dart';
import 'package:paats_dranklijst/data/tables/transactions_table.dart';

/// The seeded group every fixture hangs off. `onCreate` inserts exactly one of
/// each kind, so this is always id 1.
const int seededGroup = 1;

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(executor: NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addUser({String name = 'Jonas', int groupId = seededGroup}) =>
      db.usersDao.createUser(
        name: name,
        groupId: groupId,
        avatarEmoji: '🦊',
        seedColorArgb: 0xFF009688,
      );

  Future<ItemRow> addItem({
    String name = 'Cola',
    int price = 150,
    int groupId = seededGroup,
  }) async {
    final id = await db.itemsDao.createItem(
      name: name,
      groupId: groupId,
      priceMinorUnits: price,
      emoji: '🥤',
    );
    return (db.select(db.items)..where((i) => i.id.equals(id))).getSingle();
  }

  group('schema', () {
    test('foreign key enforcement is actually on', () async {
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(row.read<bool>('foreign_keys'), isTrue);
    });

    test('onCreate seeds one group of each kind', () async {
      expect(await db.select(db.userGroups).get(), hasLength(1));
      expect(await db.select(db.itemGroups).get(), hasLength(1));
    });

    test('a user cannot point at a group that does not exist', () async {
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
      final user = await addUser();
      await expectLater(
        db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                userId: user,
                type: TransactionType.consumption,
                amountMinorUnits: -150,
                quantity: const Value(0),
                logicalDate: logicalDayKey(DateTime.now()),
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
    test('a user with no transactions has a zero balance', () async {
      final user = await addUser();
      expect(await db.usersDao.readBalance(user), 0);
    });

    test('balance is the signed sum of every live row', () async {
      final user = await addUser();
      final cola = await addItem(price: 150);

      await db.transactionsDao.logTopUp(userId: user, amountMinorUnits: 1000);
      await db.transactionsDao.logConsumption(userId: user, item: cola);
      await db.transactionsDao.logConsumption(userId: user, item: cola);

      // 1000 - 150 - 150
      expect(await db.usersDao.readBalance(user), 700);
    });

    test('a consumption stores the line total, not the unit price', () async {
      final user = await addUser();
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
      final user = await addUser();
      await db.transactionsDao.logAdjustment(
        userId: user,
        amountMinorUnits: -250,
        note: 'Broke a glass',
      );
      expect(await db.usersDao.readBalance(user), -250);
    });

    test('watchUsersWithBalances reports zero for an untouched user', () async {
      await addUser(name: 'Silent');
      final users = await db.usersDao.watchUsersWithBalances().first;
      expect(users, hasLength(1));
      expect(users.single.balanceMinorUnits, 0);
      expect(users.single.group.id, seededGroup);
    });
  });

  group('voiding', () {
    test('a voided row leaves the balance but stays in the history', () async {
      final user = await addUser();
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
      final user = await addUser();
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
      final user = await addUser();
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
      final user = await addUser();
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
    test('a user with a balance cannot be archived', () async {
      final user = await addUser();
      final cola = await addItem();
      await db.transactionsDao.logConsumption(userId: user, item: cola);

      await expectLater(
        db.usersDao.archiveUser(user),
        throwsA(isA<UserHasBalanceException>()),
      );
    });

    test('a settled user can be archived and restored', () async {
      final user = await addUser();
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
    test('an archived user still pins their group', () async {
      final user = await addUser();
      await db.usersDao.archiveUser(user);
      final extra = await db.usersDao.createUserGroup(name: 'Rakkers');

      // The seeded group looks empty on screen — the user is archived — but
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
      await addUser(name: 'A');
      await addUser(name: 'B');
      await addUser(name: 'C');

      final names = (await db.usersDao.watchUsers().first)
          .map((u) => u.name)
          .toList();
      expect(names, ['A', 'B', 'C']);
    });

    test('reorderUsers renumbers 0..n-1', () async {
      final a = await addUser(name: 'A');
      final b = await addUser(name: 'B');
      final c = await addUser(name: 'C');

      await db.usersDao.reorderUsers(
        groupId: seededGroup,
        idsInOrder: [c, a, b],
      );

      final users = await db.usersDao.watchUsers().first;
      expect(users.map((u) => u.name), ['C', 'A', 'B']);
      expect(users.map((u) => u.sortOrder), [0, 1, 2]);
    });

    test('a new user starts at 0 in a group of its own', () async {
      await addUser(name: 'A');
      await addUser(name: 'B');

      final other = await db.usersDao.createUserGroup(name: 'Leiding');
      await addUser(name: 'X', groupId: other);

      final inOther = await db.usersDao.watchUsersInGroup(other).first;
      expect(inOther.single.sortOrder, 0);
    });

    test('a reorder renumbers only its own group', () async {
      final other = await db.usersDao.createUserGroup(name: 'Leiding');
      await addUser(name: 'A');
      await addUser(name: 'B');
      final x = await addUser(name: 'X', groupId: other);
      final y = await addUser(name: 'Y', groupId: other);

      await db.usersDao.reorderUsers(groupId: other, idsInOrder: [y, x]);

      expect(
        (await db.usersDao.watchUsersInGroup(other).first).map((u) => u.name),
        ['Y', 'X'],
      );
      expect(
        (await db.usersDao.watchUsersInGroup(seededGroup).first).map(
          (u) => u.name,
        ),
        ['A', 'B'],
      );
    });

    test('a reorder ignores an id from another group', () async {
      final other = await db.usersDao.createUserGroup(name: 'Leiding');
      final a = await addUser(name: 'A');
      final b = await addUser(name: 'B');
      final x = await addUser(name: 'X', groupId: other);

      // X is passed first but belongs elsewhere, so it keeps its own number and
      // takes no slot in this group.
      await db.usersDao.reorderUsers(
        groupId: seededGroup,
        idsInOrder: [x, b, a],
      );

      final seeded = await db.usersDao.watchUsersInGroup(seededGroup).first;
      expect(seeded.map((u) => u.name), ['B', 'A']);
      expect(
        (await db.usersDao.watchUsersInGroup(other).first).single.sortOrder,
        0,
      );
    });

    test('a restored user lands last in their group', () async {
      final a = await addUser(name: 'A');
      final b = await addUser(name: 'B');
      final c = await addUser(name: 'C');

      await db.usersDao.archiveUser(a);
      // The two left are renumbered 0..1, so A cannot go back to its old 0.
      await db.usersDao.reorderUsers(groupId: seededGroup, idsInOrder: [c, b]);
      await db.usersDao.restoreUser(a);

      final users = await db.usersDao.watchUsersInGroup(seededGroup).first;
      expect(users.map((u) => u.name), ['C', 'B', 'A']);
    });

    test('watchUsers orders by group before user', () async {
      // The second group sorts after the seeded one, so its users follow even
      // though their own sortOrder restarts at 0.
      final other = await db.usersDao.createUserGroup(name: 'Leiding');
      await addUser(name: 'X', groupId: other);
      await addUser(name: 'A');

      final users = await db.usersDao.watchUsers().first;
      expect(users.map((u) => u.name), ['A', 'X']);
    });
  });

  group('orders', () {
    test('an order writes one row per distinct item', () async {
      final user = await addUser();
      final cola = await addItem(name: 'Cola', price: 150);
      final chips = await addItem(name: 'Chips', price: 200);

      final ids = await db.transactionsDao.logConsumptions(
        userId: user,
        lines: [(item: cola, quantity: 3), (item: chips, quantity: 1)],
      );

      expect(ids, hasLength(2));
      final rows = await db.transactionsDao.watchUserHistory(user).first;
      // Sets, not lists: the rows share one timestamp, so history's
      // createdAt ordering has nothing to break the tie with.
      expect(rows.map((r) => r.itemNameSnapshot).toSet(), {'Cola', 'Chips'});
      // The line total, with the quantity already multiplied in.
      expect(rows.map((r) => r.amountMinorUnits).toSet(), {-450, -200});
      expect(await db.usersDao.readBalance(user), -650);
    });

    test('every row of an order shares one logical day', () async {
      final user = await addUser();
      final cola = await addItem();
      final chips = await addItem(name: 'Chips');

      await db.transactionsDao.logConsumptions(
        userId: user,
        lines: [(item: cola, quantity: 1), (item: chips, quantity: 1)],
      );

      final rows = await db.transactionsDao.watchUserHistory(user).first;
      expect(rows.map((r) => r.logicalDate).toSet(), hasLength(1));
    });

    test('undo removes the rows and the balance returns', () async {
      final user = await addUser();
      final cola = await addItem();
      await db.transactionsDao.logTopUp(userId: user, amountMinorUnits: 1000);

      final ids = await db.transactionsDao.logConsumptions(
        userId: user,
        lines: [(item: cola, quantity: 2)],
      );
      expect(await db.usersDao.readBalance(user), 700);

      await db.transactionsDao.undoConsumption(ids);

      expect(await db.usersDao.readBalance(user), 1000);
      // Gone outright, not voided: the row leaves no trace.
      expect(
        await db.transactionsDao.watchUserHistory(user).first,
        hasLength(1),
      );
    });

    test('undo leaves other rows alone', () async {
      final user = await addUser();
      final cola = await addItem();
      final keep = await db.transactionsDao.logConsumption(
        userId: user,
        item: cola,
      );
      final drop = await db.transactionsDao.logConsumption(
        userId: user,
        item: cola,
      );

      await db.transactionsDao.undoConsumption([drop]);

      final rows = await db.transactionsDao.watchUserHistory(user).first;
      expect(rows.single.id, keep);
    });
  });

  group('items by category', () {
    test('categories and items both come back in order', () async {
      final snacks = await db.itemsDao.createItemGroup(name: 'Snacks');
      await addItem(name: 'Cola');
      await addItem(name: 'Fanta');
      await addItem(name: 'Chips', groupId: snacks);

      final sections = await db.itemsDao.watchItemsByCategory().first;

      expect(sections.map((s) => s.group.name), ['General', 'Snacks']);
      expect(sections.first.items.map((i) => i.name), ['Cola', 'Fanta']);
      expect(sections.last.items.map((i) => i.name), ['Chips']);
    });

    test('a category with nothing on offer is left out', () async {
      final snacks = await db.itemsDao.createItemGroup(name: 'Snacks');
      await addItem(name: 'Cola');
      final chips = await addItem(name: 'Chips', groupId: snacks);
      await db.itemsDao.archiveItem(chips.id);

      final sections = await db.itemsDao.watchItemsByCategory().first;

      expect(sections.map((s) => s.group.name), ['General']);
    });

    test('nothing on offer at all is an empty list', () async {
      expect(await db.itemsDao.watchItemsByCategory().first, isEmpty);
    });
  });

  group('editing details', () {
    test(
      'a group move lands last there and closes the gap left behind',
      () async {
        final other = await db.usersDao.createUserGroup(name: 'Leiding');
        final a = await addUser(name: 'A');
        final b = await addUser(name: 'B');
        final c = await addUser(name: 'C');
        await addUser(name: 'X', groupId: other);

        await db.usersDao.updateUserDetails(
          id: a,
          name: 'A',
          avatarEmoji: '🦊',
          seedColorArgb: 0xFF009688,
          groupId: other,
        );

        final moved = await db.usersDao.watchUsersInGroup(other).first;
        expect(moved.map((u) => u.name), ['X', 'A']);
        expect(moved.map((u) => u.sortOrder), [0, 1]);

        // B and C were 1 and 2; the gap A left is closed.
        final source = await db.usersDao.watchUsersInGroup(seededGroup).first;
        expect(source.map((u) => u.name), ['B', 'C']);
        expect(source.map((u) => u.sortOrder), [0, 1]);
        expect([b, c], isNotEmpty);
      },
    );

    test('an edit that keeps the group leaves sortOrder alone', () async {
      await addUser(name: 'A');
      final b = await addUser(name: 'B');

      await db.usersDao.updateUserDetails(
        id: b,
        name: 'Bea',
        avatarEmoji: '🐸',
        seedColorArgb: 0xFFE91E63,
        groupId: seededGroup,
      );

      final users = await db.usersDao.watchUsersInGroup(seededGroup).first;
      expect(users.map((u) => u.name), ['A', 'Bea']);
      expect(users.last.sortOrder, 1);
      expect(users.last.avatarEmoji, '🐸');
    });

    test('an item moved between categories behaves the same way', () async {
      final other = await db.itemsDao.createItemGroup(name: 'Snacks');
      final cola = await addItem(name: 'Cola');
      await addItem(name: 'Fanta');

      await db.itemsDao.updateItemDetails(
        id: cola.id,
        name: 'Cola',
        emoji: '🥤',
        priceMinorUnits: 175,
        groupId: other,
      );

      final moved = await db.itemsDao.watchItemsInGroup(other).first;
      expect(moved.single.name, 'Cola');
      expect(moved.single.priceMinorUnits, 175);
      final source = await db.itemsDao.watchItemsInGroup(seededGroup).first;
      expect(source.map((i) => i.sortOrder), [0]);
    });
  });

  group('balances per group', () {
    test('the groupId filter narrows to one group', () async {
      final other = await db.usersDao.createUserGroup(name: 'Leiding');
      final a = await addUser(name: 'A');
      await addUser(name: 'X', groupId: other);
      await db.transactionsDao.logTopUp(userId: a, amountMinorUnits: 500);

      final inSeeded = await db.usersDao
          .watchUsersWithBalances(groupId: seededGroup)
          .first;
      expect(inSeeded.single.user.name, 'A');
      expect(inSeeded.single.balanceMinorUnits, 500);

      final inOther = await db.usersDao
          .watchUsersWithBalances(groupId: other)
          .first;
      expect(inOther.single.user.name, 'X');
      expect(inOther.single.balanceMinorUnits, 0);
    });

    test('archived users come through when asked for', () async {
      final a = await addUser(name: 'A');
      await db.usersDao.archiveUser(a);

      expect(
        await db.usersDao.watchUsersWithBalances(groupId: seededGroup).first,
        isEmpty,
      );
      final all = await db.usersDao
          .watchUsersWithBalances(groupId: seededGroup, includeArchived: true)
          .first;
      expect(all.single.user.name, 'A');
    });
  });

  group('group usage', () {
    test('an empty group still appears, with zero counts', () async {
      final rows = await db.usersDao.watchUserGroupsWithUsage().first;

      expect(rows.single.group.id, seededGroup);
      expect(rows.single.usage.total, 0);
    });

    test('an archived user still pins the group', () async {
      await db.usersDao.archiveUser(await addUser());

      final usage =
          (await db.usersDao.watchUserGroupsWithUsage().first).single.usage;
      expect(usage.activeCount, 0);
      expect(usage.archivedCount, 1);
      expect(usage.total, 1);
    });

    test('counts follow the group they belong to', () async {
      final other = await db.usersDao.createUserGroup(name: 'Leiding');
      await addUser(name: 'A');
      await addUser(name: 'X', groupId: other);
      await addUser(name: 'Y', groupId: other);

      final rows = await db.usersDao.watchUserGroupsWithUsage().first;
      expect(rows.map((row) => row.usage.activeCount), [1, 2]);
    });

    test('categories count their items', () async {
      await addItem();

      final rows = await db.itemsDao.watchItemGroupsWithUsage().first;
      expect(rows.single.usage.activeCount, 1);
      expect(rows.single.usage.archivedCount, 0);
    });
  });

  group('logical day', () {
    // The DAO reads its own clock, so rows at a chosen instant go in directly.
    // The write path's own stamping is covered by the test below it, and the
    // 07:00 rule itself by test/logical_day_test.dart.
    Future<void> addConsumptionAt(
      DateTime at, {
      required int userId,
      required int itemId,
      bool voided = false,
    }) async {
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              userId: userId,
              type: TransactionType.consumption,
              amountMinorUnits: -150,
              itemId: Value(itemId),
              createdAt: Value(at),
              logicalDate: logicalDayKey(at),
              voidedAt: Value(voided ? at : null),
            ),
          );
    }

    test(
      'a logged consumption stamps the day its timestamp falls in',
      () async {
        final user = await addUser();
        final cola = await addItem();
        final id = await db.transactionsDao.logConsumption(
          userId: user,
          item: cola,
        );

        final row = await db.transactionsDao.readTransaction(id);
        expect(row!.logicalDate, logicalDayKey(row.createdAt));
      },
    );

    test('rows either side of 07:00 land on different days', () async {
      final user = await addUser();
      final cola = await addItem();
      final evening = DateTime(2026, 9, 7, 23);
      final afterMidnight = DateTime(2026, 9, 8, 1);
      final nextMorning = DateTime(2026, 9, 8, 8);

      await addConsumptionAt(evening, userId: user, itemId: cola.id);
      await addConsumptionAt(afterMidnight, userId: user, itemId: cola.id);
      await addConsumptionAt(nextMorning, userId: user, itemId: cola.id);

      // 23:00 and 01:00 are the same night; 08:00 is a new day.
      expect(
        await db.transactionsDao.watchConsumptionCount(at: evening).first,
        2,
      );
      expect(
        await db.transactionsDao.watchConsumptionCount(at: afterMidnight).first,
        2,
      );
      expect(
        await db.transactionsDao.watchConsumptionCount(at: nextMorning).first,
        1,
      );
    });

    test('the count ignores voided rows, top-ups and adjustments', () async {
      final user = await addUser();
      final cola = await addItem();
      final at = DateTime(2026, 9, 8, 20);

      await addConsumptionAt(at, userId: user, itemId: cola.id);
      await addConsumptionAt(at, userId: user, itemId: cola.id, voided: true);
      await db.transactionsDao.logTopUp(userId: user, amountMinorUnits: 1000);
      await db.transactionsDao.logAdjustment(
        userId: user,
        amountMinorUnits: -50,
        note: 'Broke a glass',
      );

      expect(await db.transactionsDao.watchConsumptionCount(at: at).first, 1);
    });

    test('the count can be narrowed to one user', () async {
      final jonas = await addUser(name: 'Jonas');
      final marie = await addUser(name: 'Marie');
      final cola = await addItem();
      final at = DateTime(2026, 9, 8, 20);

      await addConsumptionAt(at, userId: jonas, itemId: cola.id);
      await addConsumptionAt(at, userId: jonas, itemId: cola.id);
      await addConsumptionAt(at, userId: marie, itemId: cola.id);

      expect(await db.transactionsDao.watchConsumptionCount(at: at).first, 3);
      expect(
        await db.transactionsDao
            .watchConsumptionCount(at: at, userId: jonas)
            .first,
        2,
      );
    });

    test('watchTransactionsForDay returns the night, newest first', () async {
      final user = await addUser();
      final cola = await addItem();
      final evening = DateTime(2026, 9, 7, 23);
      final afterMidnight = DateTime(2026, 9, 8, 1);

      await addConsumptionAt(evening, userId: user, itemId: cola.id);
      await addConsumptionAt(afterMidnight, userId: user, itemId: cola.id);
      await addConsumptionAt(
        DateTime(2026, 9, 8, 8),
        userId: user,
        itemId: cola.id,
      );

      final rows = await db.transactionsDao
          .watchTransactionsForDay(at: evening)
          .first;
      expect(rows.map((t) => t.createdAt), [afterMidnight, evening]);
    });
  });
}
