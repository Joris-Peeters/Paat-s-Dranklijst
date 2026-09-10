import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/time_of_day.dart';
import 'settings_data.dart';
import 'settings_store.dart';

/// Replaces the whole settings value. Callers build the new one with
/// `settings.copyWith(...)`.
typedef WriteSettings = void Function(AppSettingsData settings);

/// Whether [now] falls inside the dark window running from [start] to [end].
///
/// The window normally wraps midnight (20:00 -> 07:00), where the naive
/// `>= start && < end` is false at every instant of the day. A zero-length
/// window is treated as never dark, which is a choice rather than something
/// that falls out of the arithmetic.
bool isDarkAt({
  required TimeOfDay now,
  required TimeOfDay start,
  required TimeOfDay end,
}) {
  final (n, s, e) = (
    now.minutesSinceMidnight,
    start.minutesSinceMidnight,
    end.minutesSinceMidnight,
  );

  if (s == e) return false;
  return s < e ? n >= s && n < e : n >= s || n < e;
}

/// The theme mode to actually apply, with the schedule resolved against the
/// wall clock. Never [ThemeMode.system]: the schedule is not a mirror of the
/// device theme.
ThemeMode _themeModeFor(AppSettingsData settings) =>
    switch (settings.themeMode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.scheduled =>
        isDarkAt(
              now: TimeOfDay.now(),
              start: settings.darkStart,
              end: settings.darkEnd,
            )
            ? ThemeMode.dark
            : ThemeMode.light,
    };

/// Ambient app settings, published to the whole tree.
///
/// Sits above `MaterialApp` so it can feed `MaterialApp`'s own arguments —
/// `locale:`, `theme:` and `themeMode:`.
class AppSettings extends StatefulWidget {
  const AppSettings({super.key, required this.store, required this.child});

  final SettingsStore store;
  final Widget child;

  /// The current settings.
  static AppSettingsData of(BuildContext context) => _scopeOf(context).settings;

  /// The theme mode to actually apply, with the schedule already resolved.
  /// Never [ThemeMode.system].
  static ThemeMode themeModeOf(BuildContext context) =>
      _scopeOf(context).themeMode;

  /// Applies a new settings value: the UI updates on this frame, the store is
  /// written behind it.
  static WriteSettings writeOf(BuildContext context) => _scopeOf(context).write;

  static _AppSettingsScope _scopeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_AppSettingsScope>();
    assert(scope != null, 'No AppSettings found in context');
    return scope!;
  }

  @override
  State<AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<AppSettings> with WidgetsBindingObserver {
  late AppSettingsData _settings;
  late ThemeMode _themeMode;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _settings = widget.store.read();
    _themeMode = _themeModeFor(_settings);
    Intl.defaultLocale = _settings.languageCode;

    // Nothing tells the app that the clock has merely crossed a schedule
    // boundary. Polling once a minute deliberately beats a one-shot timer to
    // the next boundary: that would break on DST shifts, NTP corrections,
    // manual clock changes and device sleep, all of which happen on a tablet
    // left running for years. Comparing two ints self-corrects within 60s.
    _ticker = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _resolveThemeMode(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Dart timers are frozen while the device sleeps, so the app can wake on
    // the far side of a boundary having missed every tick.
    if (state == AppLifecycleState.resumed) _resolveThemeMode();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _resolveThemeMode() {
    final themeMode = _themeModeFor(_settings);
    if (themeMode == _themeMode) return;
    setState(() => _themeMode = themeMode);
  }

  void _write(AppSettingsData settings) {
    if (settings == _settings) return;

    // The one place the language is adopted, so this global cannot drift out of
    // sync. It lets bare `NumberFormat.simpleCurrency()` and `DateFormat`
    // calls anywhere use the stored language.
    Intl.defaultLocale = settings.languageCode;

    setState(() {
      _settings = settings;
      _themeMode = _themeModeFor(settings);
    });
    unawaited(widget.store.save(settings));
  }

  @override
  Widget build(BuildContext context) => _AppSettingsScope(
    settings: _settings,
    themeMode: _themeMode,
    write: _write,
    child: widget.child,
  );
}

class _AppSettingsScope extends InheritedWidget {
  const _AppSettingsScope({
    required this.settings,
    required this.themeMode,
    required this.write,
    required super.child,
  });

  final AppSettingsData settings;
  final ThemeMode themeMode;
  final WriteSettings write;

  @override
  bool updateShouldNotify(_AppSettingsScope oldWidget) =>
      settings != oldWidget.settings || themeMode != oldWidget.themeMode;
}
