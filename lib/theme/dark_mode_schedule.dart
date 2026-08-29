import '../data/tables/settings_table.dart';

int minutesSinceMidnight(DateTime time) => time.hour * 60 + time.minute;

/// Whether a dark window covering [start] until [end] is active at [nowMinutes].
/// All three are minutes since midnight.
///
/// The window normally wraps midnight (20:00 -> 07:00, i.e. `start > end`),
/// where the naive `now >= start && now < end` is false at every instant of the
/// day. Both orientations are handled.
///
/// `start == end` is treated as *never* dark. "Always dark" is an equally
/// defensible reading of a zero-length window, so the choice is made here
/// explicitly rather than falling out of the arithmetic.
bool isDarkAtMinute(int nowMinutes, {required int start, required int end}) {
  if (start == end) return false;
  if (start < end) return nowMinutes >= start && nowMinutes < end;
  return nowMinutes >= start || nowMinutes < end;
}

/// Resolves the stored mode to the one Flutter applies.
///
/// Never returns [ThemeMode.system]: the schedule is wall-clock, not a mirror
/// of the device theme. See CLAUDE.md rule 4.
AppBrightness resolveBrightness({
  required AppThemeMode mode,
  required DateTime now,
  required int darkStartMinutes,
  required int darkEndMinutes,
}) => switch (mode) {
  AppThemeMode.light => AppBrightness.light,
  AppThemeMode.dark => AppBrightness.dark,
  AppThemeMode.scheduled =>
    isDarkAtMinute(
          minutesSinceMidnight(now),
          start: darkStartMinutes,
          end: darkEndMinutes,
        )
        ? AppBrightness.dark
        : AppBrightness.light,
};

/// The resolved outcome. Its own enum so this file stays Flutter-free and
/// unit-testable without a widget harness.
enum AppBrightness { light, dark }
