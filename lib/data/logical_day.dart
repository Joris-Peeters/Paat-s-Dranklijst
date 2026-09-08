import 'package:flutter/material.dart' show TimeOfDay;

import 'converters.dart';

/// A day runs 07:00 -> 07:00. People stay up past midnight, so a drink at 01:00
/// belongs to the evening before rather than to the new calendar date.
const logicalDayStart = TimeOfDay(hour: 7, minute: 0);

/// The logical day [instant] falls in, as local midnight of that date.
///
/// [dayStart] is inclusive: 07:00 is the first minute of the new day, matching
/// `isDarkAt`'s start-inclusive convention.
DateTime logicalDayOf(DateTime instant, {TimeOfDay dayStart = logicalDayStart}) {
  final local = instant.toLocal();
  final minutes = TimeOfDay.fromDateTime(local).minutesSinceMidnight;
  // `day - 1` through the constructor rather than subtract(Duration(days: 1)):
  // across a DST change a day is not 24 hours, and the constructor normalises
  // an out-of-range day while still landing on local midnight.
  return DateTime(
    local.year,
    local.month,
    minutes < dayStart.minutesSinceMidnight ? local.day - 1 : local.day,
  );
}

/// The stored form of a logical day: `YYYY-MM-DD`.
///
/// Padded by hand rather than with `DateFormat`, which follows
/// `Intl.defaultLocale` — a storage key must not move when the admin switches
/// language.
String logicalDayKey(DateTime instant, {TimeOfDay dayStart = logicalDayStart}) {
  final day = logicalDayOf(instant, dayStart: dayStart);
  final year = day.year.toString().padLeft(4, '0');
  final month = day.month.toString().padLeft(2, '0');
  final dayOfMonth = day.day.toString().padLeft(2, '0');
  return '$year-$month-$dayOfMonth';
}

/// Back to local midnight, for formatting day headers.
DateTime logicalDayFromKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) {
    throw ArgumentError.value(key, 'key', 'Expected YYYY-MM-DD');
  }
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
