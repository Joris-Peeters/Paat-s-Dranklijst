import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/logical_day.dart';

/// A local instant on 8 September 2026 — a Tuesday, mid-month, so a rollback
/// lands on an ordinary neighbouring date.
DateTime at(int hour, [int minute = 0]) => DateTime(2026, 9, 8, hour, minute);

DateTime day(int year, int month, int dayOfMonth) =>
    DateTime(year, month, dayOfMonth);

void main() {
  group('logicalDayOf', () {
    test('before the 07:00 boundary belongs to the previous date', () {
      expect(logicalDayOf(at(0)), day(2026, 9, 7));
      expect(logicalDayOf(at(1)), day(2026, 9, 7));
      expect(logicalDayOf(at(6, 59)), day(2026, 9, 7));
    });

    test('07:00 is the first minute of the new day', () {
      expect(logicalDayOf(at(7)), day(2026, 9, 8));
    });

    test('the rest of the day is its own date', () {
      expect(logicalDayOf(at(12)), day(2026, 9, 8));
      expect(logicalDayOf(at(20)), day(2026, 9, 8));
      expect(logicalDayOf(at(23, 59)), day(2026, 9, 8));
    });

    test('rolls back over a month boundary', () {
      expect(logicalDayOf(DateTime(2026, 9, 1, 3)), day(2026, 8, 31));
    });

    test('rolls back over a year boundary', () {
      expect(logicalDayOf(DateTime(2026, 1, 1, 3)), day(2025, 12, 31));
    });

    test('honours a different day start', () {
      const noon = TimeOfDay(hour: 12, minute: 0);
      expect(logicalDayOf(at(11, 59), dayStart: noon), day(2026, 9, 7));
      expect(logicalDayOf(at(12), dayStart: noon), day(2026, 9, 8));
    });

    // Catches a `subtract(Duration(days: 1))` regression wherever this runs: on
    // a host with DST that arithmetic lands on 23:00 or 01:00, not midnight.
    test('always lands exactly on local midnight, every hour of a year', () {
      var instant = DateTime(2026);
      while (instant.year == 2026) {
        final result = logicalDayOf(instant);
        expect(
          [result.hour, result.minute, result.second],
          [0, 0, 0],
          reason: 'not local midnight for $instant',
        );
        instant = instant.add(const Duration(hours: 1));
      }
    });
  });

  group('logicalDayKey', () {
    test('zero-pads to YYYY-MM-DD', () {
      expect(logicalDayKey(at(12)), '2026-09-08');
      expect(logicalDayKey(DateTime(2026, 12, 25, 12)), '2026-12-25');
    });

    test('an early-morning row keys to the day before', () {
      expect(logicalDayKey(at(1)), '2026-09-07');
    });

    test('keys sort lexicographically in chronological order', () {
      final keys = [
        logicalDayKey(DateTime(2026, 9, 9, 12)),
        logicalDayKey(DateTime(2026, 1, 2, 12)),
        logicalDayKey(DateTime(2026, 10, 1, 12)),
      ]..sort();
      expect(keys, ['2026-01-02', '2026-09-09', '2026-10-01']);
    });

    test('round-trips through logicalDayFromKey', () {
      expect(logicalDayFromKey(logicalDayKey(at(1))), day(2026, 9, 7));
      expect(logicalDayFromKey(logicalDayKey(at(12))), day(2026, 9, 8));
    });
  });

  group('logicalDayFromKey', () {
    test('rejects a malformed key', () {
      expect(() => logicalDayFromKey('2026-09'), throwsArgumentError);
      expect(() => logicalDayFromKey(''), throwsArgumentError);
    });
  });
}
