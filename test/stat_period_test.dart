import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/stat_buckets.dart';
import 'package:paats_dranklijst/data/stat_period.dart';

void main() {
  group('statWindow', () {
    test('a month is 30 logical days, today included', () {
      final window = statWindow(
        StatPeriod.month,
        at: DateTime(2026, 9, 14, 21),
      );
      expect(window, (from: '2026-08-16', to: '2026-09-14'));
    });

    test('before 07:00 the window still ends on yesterday', () {
      final window = statWindow(StatPeriod.month, at: DateTime(2026, 9, 14, 3));
      expect(window.to, '2026-09-13');
    });

    test('all time has no lower bound and nothing before it', () {
      final at = DateTime(2026, 9, 14, 21);
      expect(statWindow(StatPeriod.all, at: at).from, isNull);
      expect(previousStatWindow(StatPeriod.all, at: at), isNull);
    });

    test('the previous window ends the day before this one starts', () {
      final at = DateTime(2026, 9, 14, 21);
      expect(previousStatWindow(StatPeriod.month, at: at), (
        from: '2026-07-17',
        to: '2026-08-15',
      ));
      expect(previousStatWindow(StatPeriod.year, at: at)!.to, '2025-09-14');
    });
  });

  test('daysBetween survives a DST change', () {
    // Europe moves its clocks on the last Sunday of March.
    expect(daysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
  });

  group('percentChange', () {
    test(
      'is a fraction',
      () => expect(percentChange(12, 10), closeTo(0.2, 1e-9)),
    );
    test('is null from nothing', () => expect(percentChange(5, 0), isNull));
    test('a drop to zero is -100%', () => expect(percentChange(0, 4), -1));
  });

  group('buckets', () {
    test('days are zero-filled end to end', () {
      final days = dailyBuckets(
        {'2026-09-13': 4},
        from: '2026-09-12',
        to: '2026-09-14',
      );
      expect(days.map((d) => d.count), [0, 4, 0]);
    });

    test('weeks group by Monday across a year boundary', () {
      final weeks = weeklyBuckets(
        {'2025-12-31': 1, '2026-01-04': 2, '2026-01-05': 5},
        from: '2025-12-29',
        to: '2026-01-06',
      );
      expect(weeks, [
        StatBucket(DateTime(2025, 12, 29), 3),
        StatBucket(DateTime(2026, 1, 5), 5),
      ]);
    });

    test('months run from the first with data to now, capped', () {
      final months = monthlyBuckets({
        '2026-07': 3,
      }, today: DateTime(2026, 9, 14));
      expect(months.map((m) => m.count), [3, 0, 0]);

      final capped = monthlyBuckets({
        '2019-01': 1,
      }, today: DateTime(2026, 9, 14));
      expect(capped, hasLength(60));
      expect(capped.last.start, DateTime(2026, 9));
    });

    test('hours start at the day boundary and are trimmed', () {
      final hours = hourOfNightBuckets({2: 1, 20: 3, 23: 1});
      expect(hours.first, (hour: 20, count: 3));
      expect(hours.last, (hour: 2, count: 1));
      expect(hours, hasLength(7));
      expect(hourOfNightBuckets({}), isEmpty);
    });
  });
}
