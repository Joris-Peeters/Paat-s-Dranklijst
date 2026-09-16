import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/balance_csv.dart';
import 'package:paats_dranklijst/data/balance_import.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/data/tables/transactions_table.dart';

/// The group `onCreate` seeds, named 'General'.
const int seededGroup = 1;

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(executor: NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addUser(String name, {int groupId = seededGroup}) =>
      db.usersDao.createUser(
        name: name,
        groupId: groupId,
        avatarEmoji: '🦊',
        seedColorArgb: 0xFF009688,
      );

  Future<BalanceImportPlan> plan(String csv) async {
    final parsed = parseBalancesCsv(csv, decimalDigits: 2);
    return planBalanceImport(
      rows: parsed.rows,
      csvErrors: parsed.errors,
      users: await db.usersDao.readUsersWithBalances(),
      groups: await db.usersDao.readUserGroups(),
    );
  }

  Future<void> apply(BalanceImportPlan plan) => applyBalanceImport(
    db,
    plan,
    appearance: () => (avatarEmoji: '🐻', seedColorArgb: 0xFF3F51B5),
    note: 'Imported',
  );

  Future<List<TransactionRow>> ledger() => db.select(db.transactions).get();

  test(
    'a new name creates the user, a missing group, and an adjustment',
    () async {
      final result = await plan(
        'name,group,balance\nJonas,general,-12.50\nWout,Oud-leiding,0\n',
      );
      expect(result.hasErrors, isFalse);
      expect(result.newGroups, ['Oud-leiding']);
      expect(result.newUsers.map((u) => u.name), ['Jonas', 'Wout']);
      // "general" matched the seeded "General" rather than making a second.
      expect(result.newUsers.first.existingGroupId, seededGroup);

      await apply(result);

      final users = await db.usersDao.readUsersWithBalances();
      expect(
        [
          for (final u in users)
            (u.user.name, u.group.name, u.balanceMinorUnits),
        ],
        [('Jonas', 'General', -1250), ('Wout', 'Oud-leiding', 0)],
      );
      expect(users.first.user.avatarEmoji, '🐻');
      // A zero opening balance writes nothing.
      final rows = await ledger();
      expect(rows, hasLength(1));
      expect(rows.single.type, TransactionType.adjustment);
      expect(rows.single.note, 'Imported');
    },
  );

  test(
    'an existing user is corrected by the difference and keeps history',
    () async {
      final id = await addUser('Jonas');
      await db.transactionsDao.logTopUp(userId: id, amountMinorUnits: 1000);
      final other = await db.usersDao.createUserGroup(name: 'Elsewhere');

      final result = await plan(
        'name,group,balance\n  jonas ,Elsewhere,2.50\n',
      );
      expect(result.newUsers, isEmpty);
      expect(result.newGroups, isEmpty);
      expect(result.corrections.single.differenceMinorUnits, -750);

      await apply(result);

      expect(await db.usersDao.readBalance(id), 250);
      final user = await db.usersDao.readUser(id);
      expect(
        user!.groupId,
        seededGroup,
        reason: 'the group column never moves',
      );
      expect(user.groupId, isNot(other));
      final rows = await ledger();
      expect(rows.map((r) => r.type), [
        TransactionType.topUp,
        TransactionType.adjustment,
      ]);
      expect(rows.last.amountMinorUnits, -750);
    },
  );

  test('an unchanged balance writes no row', () async {
    await addUser('Jonas');
    final result = await plan('name,group,balance\nJonas,General,0\n');
    expect(result.unchangedCount, 1);
    expect(result.changesNothing, isTrue);
    await apply(result);
    expect(await ledger(), isEmpty);
  });

  test('a correction uses the balance at apply time, not at preview', () async {
    final id = await addUser('Jonas');
    final result = await plan('name,group,balance\nJonas,General,5\n');
    await db.transactionsDao.logTopUp(userId: id, amountMinorUnits: 200);
    await apply(result);
    expect(await db.usersDao.readBalance(id), 500);
  });

  group('archived users', () {
    test('are ignored: a shared name creates a new active user', () async {
      final archived = await addUser('Jonas');
      await db.usersDao.archiveUser(archived);

      final result = await plan('name,group,balance\nJonas,General,1\n');
      expect(result.newUsers.single.name, 'Jonas');
      await apply(result);

      final archivedRow = await db.usersDao.readUser(archived);
      expect(archivedRow!.archivedAt, isNotNull);
      final active = await db.usersDao.readUsersWithBalances();
      expect(active.single.user.id, isNot(archived));
    });

    test('never count as duplicates', () async {
      await db.usersDao.archiveUser(await addUser('Jonas'));
      await db.usersDao.archiveUser(await addUser('Jonas'));
      await addUser('Jonas');
      final result = await plan('name,group,balance\nJonas,General,1\n');
      expect(result.hasErrors, isFalse);
      expect(result.corrections, hasLength(1));
    });

    test('are left out of the export', () async {
      await db.usersDao.archiveUser(await addUser('Gone'));
      await addUser('Here');
      final csv = await exportBalancesCsv(db, decimalDigits: 2);
      expect(csv, 'name,group,balance\r\nHere,General,0.00\r\n');
    });
  });

  group('errors', () {
    test('a name twice in the CSV lists every line', () async {
      final result = await plan(
        'name,group,balance\nJonas,A,1\nWout,A,1\njonas,B,2\n',
      );
      expect(result.hasErrors, isTrue);
      expect(result.duplicateNames.single.lines, [2, 4]);
      expect(result.newUsers.single.name, 'Wout');
    });

    test('a CSV name two active users share names their groups', () async {
      final group = await db.usersDao.createUserGroup(name: 'Oud-leiding');
      await addUser('Jonas');
      await addUser('Jonas', groupId: group);
      final result = await plan('name,group,balance\nJonas,General,1\n');
      expect(result.ambiguousNames.single.groups, ['General', 'Oud-leiding']);
    });

    test('a database duplicate the CSV does not name is fine', () async {
      await addUser('Jonas');
      await addUser('Jonas');
      final result = await plan('name,group,balance\nWout,General,1\n');
      expect(result.hasErrors, isFalse);
    });

    test('parse errors carry through', () async {
      final result = await plan('name,group,balance\n,General,1\n');
      expect(result.csvErrors.single.kind, BalanceCsvErrorKind.emptyName);
      expect(result.hasErrors, isTrue);
    });
  });

  test('importing an export of the same database changes nothing', () async {
    final group = await db.usersDao.createUserGroup(name: 'Leiding, oud');
    final jonas = await addUser('Jonas');
    final wout = await addUser('Wout "W"', groupId: group);
    await db.transactionsDao.logTopUp(userId: jonas, amountMinorUnits: 1234);
    await db.transactionsDao.logAdjustment(
      userId: wout,
      amountMinorUnits: -5,
      note: 'x',
    );

    final csv = await exportBalancesCsv(db, decimalDigits: 2);
    final result = await plan(csv);
    expect(result.hasErrors, isFalse);
    expect(result.changesNothing, isTrue);
    expect(result.unchangedCount, 2);
  });
}
