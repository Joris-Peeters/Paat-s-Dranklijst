import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/tables/settings_table.dart';
import 'package:paats_dranklijst/theme/dark_mode_schedule.dart';

int at(int hour, [int minute = 0]) => hour * 60 + minute;

void main() {
  group('isDarkAtMinute', () {
    group('window wrapping midnight (20:00 - 07:00)', () {
      const start = 20 * 60;
      const end = 7 * 60;

      bool dark(int minute) => isDarkAtMinute(minute, start: start, end: end);

      test('is light in the middle of the day', () {
        expect(dark(at(12)), isFalse);
        expect(dark(at(7)), isFalse); // end is exclusive
        expect(dark(at(19, 59)), isFalse);
      });

      test('is dark in the evening, from the start minute on', () {
        expect(dark(at(20)), isTrue); // start is inclusive
        expect(dark(at(21, 30)), isTrue);
        expect(dark(at(23, 59)), isTrue);
      });

      test('is dark in the early morning, up to the end minute', () {
        expect(dark(at(0)), isTrue);
        expect(dark(at(3)), isTrue);
        expect(dark(at(6, 59)), isTrue);
      });
    });

    group('window within one day (07:00 - 20:00)', () {
      const start = 7 * 60;
      const end = 20 * 60;

      bool dark(int minute) => isDarkAtMinute(minute, start: start, end: end);

      test('is dark inside the window', () {
        expect(dark(at(7)), isTrue);
        expect(dark(at(12)), isTrue);
        expect(dark(at(19, 59)), isTrue);
      });

      test('is light outside the window', () {
        expect(dark(at(6, 59)), isFalse);
        expect(dark(at(20)), isFalse);
        expect(dark(at(23, 59)), isFalse);
        expect(dark(at(0)), isFalse);
      });
    });

    test('a zero-length window is never dark', () {
      const noon = 12 * 60;
      expect(isDarkAtMinute(at(0), start: noon, end: noon), isFalse);
      expect(isDarkAtMinute(noon, start: noon, end: noon), isFalse);
      expect(isDarkAtMinute(at(23, 59), start: noon, end: noon), isFalse);
    });
  });

  group('resolveBrightness', () {
    AppBrightness resolve(AppThemeMode mode, DateTime now) => resolveBrightness(
      mode: mode,
      now: now,
      darkStartMinutes: 20 * 60,
      darkEndMinutes: 7 * 60,
    );

    final noon = DateTime(2026, 8, 29, 12);
    final night = DateTime(2026, 8, 29, 22, 30);

    test('fixed modes ignore the clock', () {
      expect(resolve(AppThemeMode.light, night), AppBrightness.light);
      expect(resolve(AppThemeMode.dark, noon), AppBrightness.dark);
    });

    test('scheduled follows the wall clock', () {
      expect(resolve(AppThemeMode.scheduled, noon), AppBrightness.light);
      expect(resolve(AppThemeMode.scheduled, night), AppBrightness.dark);
    });
  });

  test('minutesSinceMidnight ignores seconds and the date', () {
    expect(minutesSinceMidnight(DateTime(2026, 8, 29, 20, 30, 59)), at(20, 30));
  });
}
