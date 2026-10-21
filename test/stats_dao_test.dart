import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/data/logical_day.dart';
import 'package:paats_dranklijst/data/stat_buckets.dart';
import 'package:paats_dranklijst/data/stat_period.dart';
import 'package:paats_dranklijst/data/tables/transactions_table.dart';

const int seededGroup = 1;

/// Records every SELECT, so the query-plan test checks the SQL the DAO really
/// sends rather than a copy of it.
class _SelectRecorder extends QueryInterceptor {
  final selects = <({String sql, List<Object?> args})>[];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selects.add((sql: statement, args: args));
    return executor.runSelect(statement, args);
  }
}

void main() {
  late AppDatabase db;
  late _SelectRecorder recorder;

  // A Monday evening, so the current calendar week is a single day old.
  final now = DateTime(2026, 9, 14, 21);

  setUp(() {
    recorder = _SelectRecorder();
    db = AppDatabase(executor: NativeDatabase.memory().interceptWith(recorder));
  });
  tearDown(() => db.close());

  Future<int> addUser(String name, {int groupId = seededGroup}) =>
      db.usersDao.createUser(
        name: name,
        groupId: groupId,
        avatarEmoji: '🦊',
        seedColorArgb: 0xFF009688,
      );

  Future<ItemRow> addItem(
    String name, {
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

  /// Bypasses the DAO, which always stamps the real clock.
  Future<int> consume(
    int userId,
    ItemRow item,
    DateTime at, {
    int quantity = 1,
  }) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          userId: userId,
          type: TransactionType.consumption,
          amountMinorUnits: -(item.priceMinorUnits * quantity),
          quantity: Value(quantity),
          itemId: Value(item.id),
          itemNameSnapshot: Value(item.name),
          itemUnitPriceSnapshot: Value(item.priceMinorUnits),
          createdAt: Value(at),
          logicalDate: logicalDayKey(at),
        ),
      );

  Future<void> topUp(int userId, DateTime at) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          userId: userId,
          type: TransactionType.topUp,
          amountMinorUnits: 1000,
          createdAt: Value(at),
          logicalDate: logicalDayKey(at),
        ),
      );

  DateTime daysAgo(int days, {int hour = 21}) =>
      DateTime(now.year, now.month, now.day - days, hour);

  group('podium', () {
    test('ranks by each user\'s single best item, not their total', () async {
      final cola = await addItem('Cola');
      final water = await addItem('Water');
      final ann = await addUser('Ann');
      final bob = await addUser('Bob');
      final cas = await addUser('Cas');

      // Ann: 5 in total, but her best item is only 3.
      await consume(ann, cola, now, quantity: 3);
      await consume(ann, water, now, quantity: 2);
      await consume(bob, water, now, quantity: 4);
      await consume(cas, cola, now);
      await consume(cas, cola, now);

      final podium = await db.statsDao.watchPodium(at: now).first;
      expect(podium.map((p) => p.user.name), ['Bob', 'Ann', 'Cas']);
      expect(podium.map((p) => p.item.name), ['Water', 'Cola', 'Cola']);
      expect(podium.map((p) => p.count), [4, 3, 2]);
    });

    test('has fewer than three places until three people tapped', () async {
      final cola = await addItem('Cola');
      final ann = await addUser('Ann');
      final bob = await addUser('Bob');
      final cas = await addUser('Cas');
      await consume(ann, cola, now);
      await consume(bob, cola, now);
      // Yesterday, voided, and a top-up: none of them count tonight.
      await consume(cas, cola, daysAgo(1));
      final voided = await consume(cas, cola, now);
      await db.transactionsDao.voidTransaction(voided);
      await topUp(cas, now);

      expect(await db.statsDao.watchPodium(at: now).first, hasLength(2));
    });
  });

  group('user detail', () {
    test('spend splits into windows and ignores top-ups', () async {
      final cola = await addItem('Cola');
      final ann = await addUser('Ann');
      await consume(ann, cola, now); // 150, month
      await consume(ann, cola, daysAgo(29)); // 150, still month
      await consume(ann, cola, daysAgo(30), quantity: 2); // 300, year
      await consume(ann, cola, daysAgo(200)); // 150, year
      await consume(ann, cola, daysAgo(400)); // 150, all time only
      await topUp(ann, now);

      final spend = await db.statsDao.watchUserSpend(ann, at: now).first;
      expect(spend.month, 300);
      expect(spend.year, 750);
      expect(spend.allTime, 900);
    });

    test('top items count quantity, all time', () async {
      final cola = await addItem('Cola');
      final water = await addItem('Water');
      final ann = await addUser('Ann');
      await consume(ann, water, daysAgo(900), quantity: 3);
      await consume(ann, cola, now, quantity: 2);

      final top = await db.statsDao.watchUserTopItems(ann).first;
      expect(top.map((r) => (r.item.name, r.count)), [
        ('Water', 3),
        ('Cola', 2),
      ]);
    });

    test('weekly bars cover the past year, from the first week', () async {
      final cola = await addItem('Cola');
      final ann = await addUser('Ann');
      await consume(ann, cola, daysAgo(400));
      await consume(ann, cola, daysAgo(360));
      // Monday 02:00 still belongs to Sunday, so to last week.
      await consume(ann, cola, DateTime(2026, 9, 14, 2), quantity: 2);
      await consume(ann, cola, now);

      final weeks = await db.statsDao.watchUserWeekly(ann, at: now).first;
      expect(weeks, hasLength(53));
      expect(weeks.first, StatBucket(DateTime(2025, 9, 15), 1));
      expect(weeks[51], StatBucket(DateTime(2026, 9, 7), 2));
      expect(weeks.last, StatBucket(DateTime(2026, 9, 14), 1));
    });

    test('weekly bars start at a newer user\'s first week', () async {
      final cola = await addItem('Cola');
      final bob = await addUser('Bob');
      final cas = await addUser('Cas');
      final dirk = await addUser('Dirk');
      // A Wednesday.
      await consume(bob, cola, DateTime(2026, 8, 26, 21));
      await consume(cas, cola, daysAgo(400));

      final weeks = await db.statsDao.watchUserWeekly(bob, at: now).first;
      expect(weeks, hasLength(4));
      expect(weeks.first, StatBucket(DateTime(2026, 8, 24), 1));
      // Nothing in the past year, or nothing ever: no weeks at all.
      expect(await db.statsDao.watchUserWeekly(cas, at: now).first, isEmpty);
      expect(await db.statsDao.watchUserWeekly(dirk, at: now).first, isEmpty);
    });

    test('hour of night and weekday cover one user, all time', () async {
      final cola = await addItem('Cola');
      final ann = await addUser('Ann');
      final bob = await addUser('Bob');
      await consume(ann, cola, daysAgo(400, hour: 23));
      // Sunday 01:30 is still Saturday night.
      await consume(ann, cola, DateTime(2026, 9, 13, 1, 30), quantity: 2);
      final voided = await consume(ann, cola, daysAgo(2, hour: 18));
      await db.transactionsDao.voidTransaction(voided);
      await consume(bob, cola, daysAgo(1, hour: 18), quantity: 5);

      final hours = await db.statsDao.watchUserHourOfNight(ann).first;
      expect(hours, [
        (hour: 23, count: 1),
        (hour: 0, count: 0),
        (hour: 1, count: 2),
      ]);

      final days = await db.statsDao.watchUserWeekday(ann).first;
      expect(days.fold(0, (sum, d) => sum + d.count), 3);
      expect(days[5], (weekday: DateTime.saturday, count: 2));
    });
  });

  group('stats page', () {
    test('KPIs compare against the window before', () async {
      final cola = await addItem('Cola');
      final ann = await addUser('Ann');
      final bob = await addUser('Bob');
      await consume(ann, cola, now, quantity: 2);
      await consume(bob, cola, now);
      await consume(ann, cola, daysAgo(3));
      await consume(ann, cola, daysAgo(45));
      final voided = await consume(bob, cola, daysAgo(45));
      await db.transactionsDao.voidTransaction(voided);

      final month = await db.statsDao.readKpis(StatPeriod.month, at: now);
      expect(month.current, (consumptions: 4, activeUsers: 2, activeDays: 2));
      expect(month.previous, (consumptions: 1, activeUsers: 1, activeDays: 1));

      final all = await db.statsDao.readKpis(StatPeriod.all, at: now);
      expect(all.current, (consumptions: 5, activeUsers: 2, activeDays: 3));
      expect(all.previous, isNull);
    });

    test('volume buckets by day, week and month', () async {
      final cola = await addItem('Cola');
      final ann = await addUser('Ann');
      await consume(ann, cola, now, quantity: 2);
      await consume(ann, cola, daysAgo(40));
      await consume(ann, cola, daysAgo(800));

      final month = await db.statsDao.readVolume(StatPeriod.month, at: now);
      expect(month.size, BucketSize.day);
      expect(month.buckets, hasLength(30));
      expect(month.buckets.last.count, 2);

      final year = await db.statsDao.readVolume(StatPeriod.year, at: now);
      expect(year.size, BucketSize.week);
      expect(year.buckets.map((b) => b.count).reduce((a, b) => a + b), 3);

      final all = await db.statsDao.readVolume(StatPeriod.all, at: now);
      expect(all.size, BucketSize.month);
      // July 2024 through September 2026.
      expect(all.buckets, hasLength(27));
      expect(all.buckets.first, StatBucket(DateTime(2024, 7), 1));
    });

    test('hour of night reads the local clock, in night order', () async {
      final cola = await addItem('Cola');
      final ann = await addUser('Ann');
      await consume(ann, cola, DateTime(2026, 9, 14, 1, 30));
      await consume(ann, cola, DateTime(2026, 9, 13, 22), quantity: 3);

      final hours = await db.statsDao.readHourOfNight(
        StatPeriod.month,
        at: now,
      );
      expect(hours.first, (hour: 22, count: 3));
      expect(hours.last, (hour: 1, count: 1));
      expect(hours, hasLength(4));
    });

    test('weekday counts by logical day, Monday first', () async {
      final cola = await addItem('Cola');
      final ann = await addUser('Ann');
      // Sunday 01:30 is still Saturday night.
      await consume(ann, cola, DateTime(2026, 9, 13, 1, 30), quantity: 2);
      await consume(ann, cola, DateTime(2026, 9, 13, 22));

      final days = await db.statsDao.readWeekday(StatPeriod.month, at: now);
      expect(days, hasLength(7));
      expect(days.first, (weekday: DateTime.monday, count: 0));
      expect(days[5], (weekday: DateTime.saturday, count: 2));
      expect(days.last, (weekday: DateTime.sunday, count: 1));
    });
  });

  group('leaderboard', () {
    test('filters by user group and item, ranks by count or days', () async {
      final cola = await addItem('Cola');
      final water = await addItem('Water');
      final leaders = await db.usersDao.createUserGroup(name: 'Leiding');
      final ann = await addUser('Ann');
      final bob = await addUser('Bob', groupId: leaders);
      await consume(ann, cola, now, quantity: 5);
      await consume(bob, water, now);
      await consume(bob, water, daysAgo(1));

      final consumers = await db.statsDao.readTopConsumers(
        StatPeriod.month,
        at: now,
      );
      expect(consumers.map((r) => (r.user.name, r.count)), [
        ('Ann', 5),
        ('Bob', 2),
      ]);

      final present = await db.statsDao.readMostPresent(
        StatPeriod.month,
        at: now,
      );
      expect(present.map((r) => (r.user.name, r.count)), [
        ('Bob', 2),
        ('Ann', 1),
      ]);

      expect(
        (await db.statsDao.readTopConsumers(
          StatPeriod.month,
          at: now,
          userGroupId: leaders,
        )).map((r) => r.user.name),
        ['Bob'],
      );
      expect(
        (await db.statsDao.readTopConsumers(
          StatPeriod.all,
          at: now,
          itemId: cola.id,
        )).map((r) => r.user.name),
        ['Ann'],
      );
    });

    test('a category filter counts every item in it, and only those', () async {
      final beer = await db.itemsDao.createItemGroup(name: 'Bier');
      final cola = await addItem('Cola');
      final pils = await addItem('Pils', groupId: beer);
      final duvel = await addItem('Duvel', groupId: beer);
      final ann = await addUser('Ann');
      final bob = await addUser('Bob');
      await consume(ann, cola, now, quantity: 5);
      await consume(ann, pils, now);
      await consume(bob, pils, now, quantity: 2);
      await consume(bob, duvel, daysAgo(1));

      final consumers = await db.statsDao.readTopConsumers(
        StatPeriod.month,
        at: now,
        itemGroupId: beer,
      );
      expect(consumers.map((r) => (r.user.name, r.count)), [
        ('Bob', 3),
        ('Ann', 1),
      ]);

      final best = await db.statsDao.readBestDays(
        StatPeriod.month,
        at: now,
        itemGroupId: beer,
      );
      expect(best.map((b) => (b.user.name, b.count)), [('Bob', 2), ('Ann', 1)]);
    });

    test('best day counts a logical day, keeps the earlier of a tie', () async {
      final cola = await addItem('Cola');
      final water = await addItem('Water');
      final ann = await addUser('Ann');
      final bob = await addUser('Bob');
      await consume(ann, cola, daysAgo(5), quantity: 2);
      // 01:00 the next morning is still the same evening.
      await consume(ann, cola, daysAgo(4, hour: 1));
      await consume(ann, water, daysAgo(2), quantity: 3);
      await consume(bob, water, now);

      final best = await db.statsDao.readBestDays(StatPeriod.month, at: now);
      expect(best.map((b) => (b.user.name, b.count, b.day)), [
        ('Ann', 3, logicalDayOf(daysAgo(5))),
        ('Bob', 1, logicalDayOf(now)),
      ]);

      final onWater = await db.statsDao.readBestDays(
        StatPeriod.month,
        at: now,
        itemId: water.id,
      );
      expect(onWater.first.day, logicalDayOf(daysAgo(2)));
    });

    test(
      'most loyal ranks a share of the full total, over a minimum',
      () async {
        final cola = await addItem('Cola');
        final water = await addItem('Water');
        final leaders = await db.usersDao.createUserGroup(name: 'Leiding');
        final ann = await addUser('Ann');
        final bob = await addUser('Bob');
        final cas = await addUser('Cas');
        final dirk = await addUser('Dirk', groupId: leaders);
        await consume(ann, cola, now, quantity: 3);
        await consume(ann, water, now);
        await consume(bob, water, daysAgo(1), quantity: 4);
        await consume(cas, cola, now);
        await consume(dirk, cola, now, quantity: 2);
        await consume(dirk, water, now, quantity: 2);

        Future<List<(String, String, int, int)>> loyal({
          int? itemId,
          int? userGroupId,
        }) async => [
          for (final l in await db.statsDao.readMostLoyal(
            StatPeriod.month,
            at: now,
            minimumTotal: 4,
            itemId: itemId,
            userGroupId: userGroupId,
          ))
            (l.user.name, l.item.name, l.count, l.total),
        ];

        // Cas is under the minimum; Dirk's tie goes to the lower item id.
        expect(await loyal(), [
          ('Bob', 'Water', 4, 4),
          ('Ann', 'Cola', 3, 4),
          ('Dirk', 'Cola', 2, 4),
        ]);
        expect(await loyal(itemId: cola.id), [
          ('Ann', 'Cola', 3, 4),
          ('Dirk', 'Cola', 2, 4),
        ]);
        expect(await loyal(userGroupId: leaders), [('Dirk', 'Cola', 2, 4)]);
      },
    );

    test(
      'most loyal in a category picks a favourite out of the category total',
      () async {
        final beer = await db.itemsDao.createItemGroup(name: 'Bier');
        final cola = await addItem('Cola');
        final pils = await addItem('Pils', groupId: beer);
        final duvel = await addItem('Duvel', groupId: beer);
        final ann = await addUser('Ann');
        final bob = await addUser('Bob');
        final cas = await addUser('Cas');
        await consume(ann, pils, now, quantity: 3);
        await consume(ann, duvel, now);
        await consume(ann, cola, now, quantity: 6);
        await consume(bob, duvel, now, quantity: 4);
        // Over the minimum overall, but not within the category.
        await consume(cas, cola, now, quantity: 10);
        await consume(cas, pils, now, quantity: 2);

        final loyal = await db.statsDao.readMostLoyal(
          StatPeriod.month,
          at: now,
          minimumTotal: 4,
          itemGroupId: beer,
        );
        expect(loyal.map((l) => (l.user.name, l.item.name, l.count, l.total)), [
          ('Bob', 'Duvel', 4, 4),
          ('Ann', 'Pils', 3, 4),
        ]);
      },
    );
  });

  group('group activity', () {
    test('counts one group over the past year, live rows only', () async {
      final cola = await addItem('Cola');
      final leaders = await db.usersDao.createUserGroup(name: 'Leiding');
      final ann = await addUser('Ann');
      final bob = await addUser('Bob');
      final idle = await addUser('Idle');
      final other = await addUser('Other', groupId: leaders);

      await consume(ann, cola, now, quantity: 3);
      await consume(ann, cola, daysAgo(10));
      await consume(bob, cola, now);
      await db.transactionsDao.voidTransaction(
        await consume(bob, cola, daysAgo(2), quantity: 4),
      );
      await consume(idle, cola, daysAgo(400));
      await consume(other, cola, now);

      final activity = await db.statsDao.readGroupActivity(
        seededGroup,
        at: now,
      );
      expect(activity, {
        ann: (consumptions: 4, days: 2),
        bob: (consumptions: 1, days: 1),
      });
    });
  });

  test(
    'every stats query is an index-only scan of a consumption index',
    () async {
      final cola = await addItem('Cola');
      final ann = await addUser('Ann');
      await consume(ann, cola, now);

      final stats = db.statsDao;
      await stats.watchPodium(at: now).first;
      await stats.watchUserSpend(ann, at: now).first;
      await stats.watchUserTopItems(ann).first;
      await stats.watchUserWeekly(ann, at: now).first;
      await stats.watchUserHourOfNight(ann).first;
      await stats.watchUserWeekday(ann).first;
      await stats.readGroupActivity(seededGroup, at: now);
      for (final period in StatPeriod.values) {
        await stats.readKpis(period, at: now);
        await stats.readVolume(period, at: now);
        await stats.readTopItems(period, at: now);
        await stats.readHourOfNight(period, at: now);
        await stats.readWeekday(period, at: now);
        await stats.readTopConsumers(period, at: now);
        await stats.readMostPresent(period, at: now);
        await stats.readBestDays(period, at: now);
        await stats.readMostLoyal(period, at: now, minimumTotal: 1);
        await stats.readBestDays(
          period,
          at: now,
          userGroupId: seededGroup,
          itemId: cola.id,
        );
        await stats.readMostLoyal(
          period,
          at: now,
          minimumTotal: 1,
          userGroupId: seededGroup,
          itemId: cola.id,
        );
        await stats.readBestDays(period, at: now, itemGroupId: seededGroup);
        await stats.readMostLoyal(
          period,
          at: now,
          minimumTotal: 1,
          itemGroupId: seededGroup,
        );
        await stats.readTopConsumers(
          period,
          at: now,
          userGroupId: seededGroup,
          itemGroupId: seededGroup,
        );
        await stats.readTopConsumers(
          period,
          at: now,
          userGroupId: seededGroup,
          itemId: cola.id,
        );
      }

      final queries = recorder.selects
          .where((s) => s.sql.contains("type = 'consumption'"))
          .toList();
      expect(queries, isNotEmpty);

      for (final query in queries) {
        final plan = await db
            .customSelect(
              'EXPLAIN QUERY PLAN ${query.sql}',
              variables: [for (final arg in query.args) Variable<Object>(arg)],
            )
            .get();
        final touches = plan
            .map((row) => row.read<String>('detail'))
            .where((d) => RegExp(r'^(SCAN|SEARCH) transactions\b').hasMatch(d));
        expect(touches, isNotEmpty, reason: query.sql);
        // One user's rows are found by seeking, not by scanning everyone's.
        final index = query.sql.contains('user_id = ?')
            ? 'SEARCH transactions USING COVERING INDEX '
                  'transactions_consumptions_by_user'
            : 'COVERING INDEX transactions_consumptions_by_';
        for (final detail in touches) {
          expect(detail, contains(index), reason: query.sql);
        }
      }
    },
  );
}
