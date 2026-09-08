import 'package:flutter/material.dart' show TimeOfDay;

extension TimeOfDayMinutes on TimeOfDay {
  /// Minutes since midnight — the storage form, and the ordering [TimeOfDay]
  /// itself does not provide.
  int get minutesSinceMidnight => hour * 60 + minute;
}

TimeOfDay timeOfDayFromMinutes(int minutes) =>
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
