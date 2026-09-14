import 'package:drift/drift.dart';

import '../database.dart';
import '../logical_day.dart';
import '../stat_buckets.dart';
import '../stat_period.dart';
import '../tables/items_table.dart';
import '../tables/transactions_table.dart';
import '../tables/users_table.dart';

part 'stats_dao.g.dart';

/// A user and how they scored: consumptions, or days present.
class RankedUser {
  const RankedUser({required this.user, required this.count});

  final UserRow user;
  final int count;
}

/// An item and how many of it were taken.
class RankedItem {
  const RankedItem({required this.item, required this.count});

  final ItemRow item;
  final int count;
}

/// One podium place: a user, the item they took most of tonight, and how many.
class PodiumEntry {
  const PodiumEntry({
    required this.user,
    required this.item,
    required this.count,
  });

  final UserRow user;
  final ItemRow item;
  final int count;
}

typedef KpiFigures = ({int consumptions, int activeUsers, int activeDays});

/// Figures for a window and, except for all time, the window before it.
typedef StatsKpis = ({KpiFigures current, KpiFigures? previous});

/// What a user spent on consumptions, as positive minor units.
typedef UserSpend = ({int month, int year, int allTime});

/// A user's consumptions per calendar week, and the logical day of their very
/// first one — null if they never took anything.
typedef UserWeekly = ({List<StatBucket> weeks, DateTime? firstDay});

/// A user's consumptions and distinct logical days with one, over a window.
typedef UserActivity = ({int consumptions, int days});

typedef Volume = ({BucketSize size, List<StatBucket> buckets});

/// Read-only statistics over live consumptions.
///
/// Written as SQL rather than with the query builder: a ranking aggregates
/// first and joins users or items to its five rows only, the hour of night
/// needs `strftime`, and the predicate below matches the partial indexes as a
/// literal rather than through SQLite re-preparing with a bound value.
///
/// `test/stats_dao_test.dart` checks every query here is an index-only scan.
@DriftAccessor(tables: [Transactions, Users, Items])
class StatsDao extends DatabaseAccessor<AppDatabase> with _$StatsDaoMixin {
  StatsDao(super.db);

  /// Word for word the WHERE of both `transactions_consumptions_*` indexes.
  static const _live = "type = 'consumption' AND voided_at IS NULL";

  /// Every column of [table] under [alias], named `alias.column` so the
  /// generated `map` can read it back with `tablePrefix`.
  String _columns(TableInfo<Table, Object?> table, String alias) => table
      .$columns
      .map((c) => '$alias."${c.name}" AS "$alias.${c.name}"')
      .join(', ');

  /// The live-consumption WHERE clause plus whichever filters are set, with
  /// its variables in placeholder order.
  ({String sql, List<Variable<Object>> variables}) _where({
    String? from,
    String? to,
    int? userId,
    int? itemId,
    int? userGroupId,
  }) {
    final sql = StringBuffer('WHERE $_live');
    final variables = <Variable<Object>>[];
    if (from != null) {
      sql.write(' AND logical_date >= ?');
      variables.add(Variable.withString(from));
    }
    if (to != null) {
      sql.write(' AND logical_date <= ?');
      variables.add(Variable.withString(to));
    }
    if (userId != null) {
      sql.write(' AND user_id = ?');
      variables.add(Variable.withInt(userId));
    }
    if (itemId != null) {
      sql.write(' AND item_id = ?');
      variables.add(Variable.withInt(itemId));
    }
    if (userGroupId != null) {
      sql.write(' AND user_id IN (SELECT id FROM users WHERE group_id = ?)');
      variables.add(Variable.withInt(userGroupId));
    }
    return (sql: sql.toString(), variables: variables);
  }

  // ---- Start page ----

  /// Tonight's top three by the count of their single most-taken item.
  ///
  /// Everyone who tapped has a best item, so fewer than three rows means fewer
  /// than three people tapped. Ties go to the lower id.
  Stream<List<PodiumEntry>> watchPodium({required DateTime at}) {
    final where = _where(from: logicalDayKey(at), to: logicalDayKey(at));
    return customSelect(
      '''
      WITH per_item AS (
        SELECT user_id, item_id, SUM(quantity) AS n
        FROM transactions ${where.sql}
        GROUP BY user_id, item_id
      ), best AS (
        SELECT user_id, item_id, n,
          ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY n DESC, item_id)
            AS place
        FROM per_item
      )
      SELECT best.n AS n, ${_columns(users, 'u')}, ${_columns(items, 'i')}
      FROM best
      JOIN users u ON u.id = best.user_id
      JOIN items i ON i.id = best.item_id
      WHERE best.place = 1
      ORDER BY best.n DESC, best.user_id
      LIMIT 3
      ''',
      variables: where.variables,
      readsFrom: {transactions, users, items},
    ).watch().map(
      (rows) => [
        for (final row in rows)
          PodiumEntry(
            user: users.map(row.data, tablePrefix: 'u'),
            item: items.map(row.data, tablePrefix: 'i'),
            count: row.read<int>('n'),
          ),
      ],
    );
  }

  // ---- User detail ----

  Stream<UserSpend> watchUserSpend(int userId, {required DateTime at}) {
    final month = statWindow(StatPeriod.month, at: at);
    final year = statWindow(StatPeriod.year, at: at);
    final where = _where(userId: userId, to: month.to);

    // Consumption amounts are negative balance movements; spend is money
    // taken, so the sign flips here once.
    return customSelect(
      '''
      SELECT
        -COALESCE(SUM(CASE WHEN logical_date >= ?
          THEN amount_minor_units END), 0) AS month,
        -COALESCE(SUM(CASE WHEN logical_date >= ?
          THEN amount_minor_units END), 0) AS year,
        -COALESCE(SUM(amount_minor_units), 0) AS all_time
      FROM transactions ${where.sql}
      ''',
      variables: [
        Variable.withString(month.from!),
        Variable.withString(year.from!),
        ...where.variables,
      ],
      readsFrom: {transactions},
    ).watchSingle().map(
      (row) => (
        month: row.read<int>('month'),
        year: row.read<int>('year'),
        allTime: row.read<int>('all_time'),
      ),
    );
  }

  /// All time: a user's history is short, and their favourites are a fact
  /// about them rather than about this month.
  Stream<List<RankedItem>> watchUserTopItems(int userId) =>
      _topItems(_where(userId: userId)).watch().map(_rankedItems);

  /// The last 12 calendar weeks, the current one included.
  Stream<UserWeekly> watchUserWeekly(int userId, {required DateTime at}) {
    final today = logicalDayOf(at);
    final from = logicalDayToKey(addDays(mondayOf(today), -7 * 11));
    final to = logicalDayToKey(today);
    final first = _where(userId: userId);
    final window = _where(userId: userId, from: from, to: to);

    // Joined to a one-row CTE so the first day comes back even when the
    // window holds nothing.
    return customSelect(
      '''
      WITH first AS (
        SELECT MIN(logical_date) AS day FROM transactions ${first.sql}
      ), per_day AS (
        SELECT logical_date AS day, SUM(quantity) AS n
        FROM transactions ${window.sql}
        GROUP BY logical_date
      )
      SELECT first.day AS first_day, per_day.day AS day, per_day.n AS n
      FROM first LEFT JOIN per_day ON 1
      ''',
      variables: [...first.variables, ...window.variables],
      readsFrom: {transactions},
    ).watch().map((rows) {
      final firstDay = rows.first.readNullable<String>('first_day');
      return (
        weeks: weeklyBuckets(
          {
            for (final row in rows)
              ?row.readNullable<String>('day'): row.readNullable<int>('n') ?? 0,
          },
          from: from,
          to: to,
        ),
        firstDay: firstDay == null ? null : logicalDayFromKey(firstDay),
      );
    });
  }

  // ---- Stats page ----

  Future<StatsKpis> readKpis(StatPeriod period, {required DateTime at}) async {
    final current = statWindow(period, at: at);
    final previous = previousStatWindow(period, at: at);

    if (previous == null) {
      final where = _where(to: current.to);
      final row = await customSelect(
        '''
        SELECT
          COALESCE(SUM(quantity), 0) AS consumptions,
          COUNT(DISTINCT user_id) AS users,
          COUNT(DISTINCT logical_date) AS days
        FROM transactions ${where.sql}
        ''',
        variables: where.variables,
        readsFrom: {transactions},
      ).getSingle();
      return (current: _kpiFigures(row, ''), previous: null);
    }

    // One range scan over both windows; each figure picks its own half.
    final where = _where(from: previous.from, to: current.to);
    final split = Variable.withString(current.from!);
    final row = await customSelect(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN logical_date >= ?1 THEN quantity END), 0)
          AS consumptions,
        COUNT(DISTINCT CASE WHEN logical_date >= ?1 THEN user_id END) AS users,
        COUNT(DISTINCT CASE WHEN logical_date >= ?1 THEN logical_date END)
          AS days,
        COALESCE(SUM(CASE WHEN logical_date < ?1 THEN quantity END), 0)
          AS previous_consumptions,
        COUNT(DISTINCT CASE WHEN logical_date < ?1 THEN user_id END)
          AS previous_users,
        COUNT(DISTINCT CASE WHEN logical_date < ?1 THEN logical_date END)
          AS previous_days
      FROM transactions ${where.sql}
      ''',
      // A plain `?` after `?1` numbers itself from 2, so the WHERE's own
      // variables follow the split.
      variables: [split, ...where.variables],
      readsFrom: {transactions},
    ).getSingle();
    return (
      current: _kpiFigures(row, ''),
      previous: _kpiFigures(row, 'previous_'),
    );
  }

  KpiFigures _kpiFigures(QueryRow row, String prefix) => (
    consumptions: row.read<int>('${prefix}consumptions'),
    activeUsers: row.read<int>('${prefix}users'),
    activeDays: row.read<int>('${prefix}days'),
  );

  /// Per day for a month, per calendar week for a year, per calendar month for
  /// all time — the last 60 at most.
  Future<Volume> readVolume(StatPeriod period, {required DateTime at}) async {
    final window = statWindow(period, at: at);

    if (period == StatPeriod.all) {
      final today = logicalDayOf(at);
      // Nothing older than the 60 months that can be drawn is read at all.
      final oldest = logicalDayToKey(DateTime(today.year, today.month - 59));
      final where = _where(from: oldest, to: window.to);
      final rows = await customSelect(
        '''
        SELECT substr(logical_date, 1, 7) AS month, SUM(quantity) AS n
        FROM transactions ${where.sql}
        GROUP BY month
        ''',
        variables: where.variables,
        readsFrom: {transactions},
      ).get();
      return (
        size: BucketSize.month,
        buckets: monthlyBuckets({
          for (final row in rows) row.read<String>('month'): row.read<int>('n'),
        }, today: today),
      );
    }

    final where = _where(from: window.from, to: window.to);
    final rows = await customSelect(
      '''
      SELECT logical_date AS day, SUM(quantity) AS n
      FROM transactions ${where.sql}
      GROUP BY logical_date
      ''',
      variables: where.variables,
      readsFrom: {transactions},
    ).get();
    final perDay = {
      for (final row in rows) row.read<String>('day'): row.read<int>('n'),
    };
    return period == StatPeriod.month
        ? (
            size: BucketSize.day,
            buckets: dailyBuckets(perDay, from: window.from!, to: window.to),
          )
        : (
            size: BucketSize.week,
            buckets: weeklyBuckets(perDay, from: window.from!, to: window.to),
          );
  }

  Future<List<RankedItem>> readTopItems(
    StatPeriod period, {
    required DateTime at,
  }) {
    final window = statWindow(period, at: at);
    return _topItems(_where(from: window.from, to: window.to))
        .get()
        .then(_rankedItems);
  }

  /// Consumptions per hour of the local clock, in night order and trimmed.
  Future<List<({int hour, int count})>> readHourOfNight(
    StatPeriod period, {
    required DateTime at,
  }) async {
    final window = statWindow(period, at: at);
    final where = _where(from: window.from, to: window.to);
    // `created_at` is stored as unix seconds. `localtime` is fine here, in a
    // query; it is only an index that cannot hold it.
    final rows = await customSelect(
      '''
      SELECT
        CAST(strftime('%H', created_at, 'unixepoch', 'localtime') AS INTEGER)
          AS hour,
        SUM(quantity) AS n
      FROM transactions ${where.sql}
      GROUP BY hour
      ''',
      variables: where.variables,
      readsFrom: {transactions},
    ).get();
    return hourOfNightBuckets({
      for (final row in rows) row.read<int>('hour'): row.read<int>('n'),
    });
  }

  // ---- Leaderboard ----

  /// Top five by consumptions. Fewer than five rows means fewer than five
  /// people qualify.
  Future<List<RankedUser>> readTopConsumers(
    StatPeriod period, {
    required DateTime at,
    int? userGroupId,
    int? itemId,
  }) => _rankUsers(
    'SUM(quantity)',
    period,
    at: at,
    userGroupId: userGroupId,
    itemId: itemId,
  );

  /// Top five by distinct logical days with at least one consumption.
  Future<List<RankedUser>> readMostPresent(
    StatPeriod period, {
    required DateTime at,
    int? userGroupId,
    int? itemId,
  }) => _rankUsers(
    'COUNT(DISTINCT logical_date)',
    period,
    at: at,
    userGroupId: userGroupId,
    itemId: itemId,
  );

  Future<List<RankedUser>> _rankUsers(
    String score,
    StatPeriod period, {
    required DateTime at,
    int? userGroupId,
    int? itemId,
  }) async {
    final window = statWindow(period, at: at);
    final where = _where(
      from: window.from,
      to: window.to,
      itemId: itemId,
      userGroupId: userGroupId,
    );
    final rows = await customSelect(
      '''
      WITH ranked AS (
        SELECT user_id, $score AS n
        FROM transactions ${where.sql}
        GROUP BY user_id
        ORDER BY n DESC, user_id
        LIMIT 5
      )
      SELECT ranked.n AS n, ${_columns(users, 'u')}
      FROM ranked JOIN users u ON u.id = ranked.user_id
      ORDER BY ranked.n DESC, ranked.user_id
      ''',
      variables: where.variables,
      readsFrom: {transactions, users},
    ).get();
    return [
      for (final row in rows)
        RankedUser(
          user: users.map(row.data, tablePrefix: 'u'),
          count: row.read<int>('n'),
        ),
    ];
  }

  // ---- Group management ----

  /// Every user in a group who took something in the past year, with their
  /// consumptions and active days. A user without a key scored zero on both.
  Future<Map<int, UserActivity>> readGroupActivity(
    int userGroupId, {
    required DateTime at,
  }) async {
    final window = statWindow(StatPeriod.year, at: at);
    final where = _where(
      from: window.from,
      to: window.to,
      userGroupId: userGroupId,
    );
    final rows = await customSelect(
      '''
      SELECT user_id, SUM(quantity) AS consumptions,
        COUNT(DISTINCT logical_date) AS days
      FROM transactions ${where.sql}
      GROUP BY user_id
      ''',
      variables: where.variables,
      readsFrom: {transactions, users},
    ).get();
    return {
      for (final row in rows)
        row.read<int>('user_id'): (
          consumptions: row.read<int>('consumptions'),
          days: row.read<int>('days'),
        ),
    };
  }

  // ---- Shared ----

  Selectable<QueryRow> _topItems(
    ({String sql, List<Variable<Object>> variables}) where,
  ) => customSelect(
    '''
    WITH ranked AS (
      SELECT item_id, SUM(quantity) AS n
      FROM transactions ${where.sql}
      GROUP BY item_id
      ORDER BY n DESC, item_id
      LIMIT 5
    )
    SELECT ranked.n AS n, ${_columns(items, 'i')}
    FROM ranked JOIN items i ON i.id = ranked.item_id
    ORDER BY ranked.n DESC, ranked.item_id
    ''',
    variables: where.variables,
    readsFrom: {transactions, items},
  );

  List<RankedItem> _rankedItems(List<QueryRow> rows) => [
    for (final row in rows)
      RankedItem(
        item: items.map(row.data, tablePrefix: 'i'),
        count: row.read<int>('n'),
      ),
  ];
}
