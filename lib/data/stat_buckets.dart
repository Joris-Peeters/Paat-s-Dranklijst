import 'logical_day.dart';
import 'stat_period.dart';

/// How wide one bar of a volume chart is.
enum BucketSize { day, week, month }

/// One bar: the local midnight it starts on, and how many consumptions it
/// holds.
class StatBucket {
  const StatBucket(this.start, this.count);

  final DateTime start;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is StatBucket && other.start == start && other.count == count;

  @override
  int get hashCode => Object.hash(start, count);

  @override
  String toString() => 'StatBucket($start, $count)';
}

/// One bar per day from [from] to [to], both logical-day keys, zeros included.
List<StatBucket> dailyBuckets(
  Map<String, int> perDay, {
  required String from,
  required String to,
}) {
  final last = logicalDayFromKey(to);
  return [
    for (
      var day = logicalDayFromKey(from);
      !day.isAfter(last);
      day = addDays(day, 1)
    )
      StatBucket(day, perDay[logicalDayToKey(day)] ?? 0),
  ];
}

/// One bar per Mon–Sun week overlapping [from]..[to], zeros included. The
/// first and last week can be partial.
List<StatBucket> weeklyBuckets(
  Map<String, int> perDay, {
  required String from,
  required String to,
}) {
  final perWeek = <DateTime, int>{};
  for (final MapEntry(:key, :value) in perDay.entries) {
    final monday = mondayOf(logicalDayFromKey(key));
    perWeek[monday] = (perWeek[monday] ?? 0) + value;
  }

  final last = mondayOf(logicalDayFromKey(to));
  return [
    for (
      var week = mondayOf(logicalDayFromKey(from));
      !week.isAfter(last);
      week = addDays(week, 7)
    )
      StatBucket(week, perWeek[week] ?? 0),
  ];
}

/// One bar per calendar month from the first month in [perMonth] through the
/// month of [today], zeros included, keeping only the last [max].
///
/// [perMonth] is keyed `YYYY-MM`, the first seven characters of a logical day.
List<StatBucket> monthlyBuckets(
  Map<String, int> perMonth, {
  required DateTime today,
  int max = 60,
}) {
  if (perMonth.isEmpty) return const [];

  final first = logicalDayFromKey(
    '${(perMonth.keys.toList()..sort()).first}-01',
  );
  final last = DateTime(today.year, today.month);
  final buckets = [
    for (
      var month = first;
      !month.isAfter(last);
      month = DateTime(month.year, month.month + 1)
    )
      StatBucket(month, perMonth[logicalDayToKey(month).substring(0, 7)] ?? 0),
  ];
  return buckets.length > max ? buckets.sublist(buckets.length - max) : buckets;
}

/// Consumptions per hour of the clock, ordered from the start of the logical
/// day so the night reads continuously, and trimmed to the first and last
/// hour that has any.
List<({int hour, int count})> hourOfNightBuckets(Map<int, int> perHour) {
  final ordered = [
    for (var i = 0; i < 24; i++)
      (
        hour: (logicalDayStart.hour + i) % 24,
        count: perHour[(logicalDayStart.hour + i) % 24] ?? 0,
      ),
  ];
  final first = ordered.indexWhere((h) => h.count > 0);
  if (first == -1) return const [];
  final last = ordered.lastIndexWhere((h) => h.count > 0);
  return ordered.sublist(first, last + 1);
}
