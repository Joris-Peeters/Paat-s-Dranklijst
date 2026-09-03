import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show TimeOfDay;

extension TimeOfDayMinutes on TimeOfDay {
  /// Minutes since midnight — the storage form, and the ordering `TimeOfDay`
  /// itself does not provide.
  int get minutesSinceMidnight => hour * 60 + minute;
}

/// Stores a wall-clock time as minutes since midnight. See rule 4.
///
/// The mixin keeps the generated `toJson`/`fromJson` on the int; without it the
/// data class would try to serialize a raw [TimeOfDay].
class TimeOfDayConverter extends TypeConverter<TimeOfDay, int>
    with JsonTypeConverter<TimeOfDay, int> {
  const TimeOfDayConverter();

  @override
  TimeOfDay fromSql(int fromDb) =>
      TimeOfDay(hour: fromDb ~/ 60, minute: fromDb % 60);

  @override
  int toSql(TimeOfDay value) => value.minutesSinceMidnight;
}
