import 'logical_day.dart';

/// A rolling window of logical days ending today, or everything.
enum StatPeriod {
  month(30),
  year(365),
  all(null);

  const StatPeriod(this.days);

  /// Null for [all], which has no lower bound.
  final int? days;
}

/// Logical-day keys, both ends inclusive. [from] is null for no lower bound.
typedef DayWindow = ({String? from, String to});

/// [day] moved by [days], through the constructor rather than `add`: across a
/// DST change a day is not 24 hours, and the constructor still lands on
/// midnight.
DateTime addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// The Monday of the Mon–Sun week holding [day].
DateTime mondayOf(DateTime day) => addDays(day, -(day.weekday - 1));

/// Whole days from [from] to [to], both local midnights. Measured in UTC so a
/// DST change in between cannot shave an hour off and round a day away.
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// The window [period] covers on the logical day containing [at].
DayWindow statWindow(StatPeriod period, {required DateTime at}) {
  final today = logicalDayOf(at);
  final days = period.days;
  return (
    from: days == null ? null : logicalDayToKey(addDays(today, 1 - days)),
    to: logicalDayToKey(today),
  );
}

/// The window of the same length directly before [statWindow], or null for
/// [StatPeriod.all], which has nothing before it.
({String from, String to})? previousStatWindow(
  StatPeriod period, {
  required DateTime at,
}) {
  final days = period.days;
  if (days == null) return null;
  final today = logicalDayOf(at);
  return (
    from: logicalDayToKey(addDays(today, 1 - 2 * days)),
    to: logicalDayToKey(addDays(today, -days)),
  );
}

/// The relative change from [previous] to [current], as a fraction: 0.12 is
/// +12%. Null when there was nothing before — growth from zero is not +100%.
double? percentChange(int current, int previous) =>
    previous == 0 ? null : (current - previous) / previous;
