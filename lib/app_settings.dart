import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'data/converters.dart';
import 'data/database.dart';
import 'data/database_provider.dart';
import 'data/tables/settings_table.dart';

/// Whether [now] falls inside the dark window running from [start] to [end].
///
/// The window normally wraps midnight (20:00 -> 07:00), where the naive
/// `>= start && < end` is false at every instant of the day. A zero-length
/// window is treated as never dark — "always dark" is an equally defensible
/// reading, so the choice is made here rather than falling out of the
/// arithmetic.
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
/// device theme. See CLAUDE.md rule 4.
ThemeMode _themeModeFor(SettingsRow settings) => switch (settings.themeMode) {
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

/// Ambient app settings, read from the database and published to the whole tree.
///
/// Sits above `MaterialApp` so it can feed `MaterialApp`'s own arguments —
/// `locale:`, `theme:` and `themeMode:`. See CLAUDE.md rules 4 and 5.
class AppSettings extends StatefulWidget {
  const AppSettings({super.key, required this.child});

  final Widget child;

  /// The stored settings row.
  static SettingsRow of(BuildContext context) => _scopeOf(context).settings;

  /// The theme mode to actually apply, with the schedule already resolved.
  /// Never [ThemeMode.system].
  static ThemeMode themeModeOf(BuildContext context) =>
      _scopeOf(context).themeMode;

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
  StreamSubscription<SettingsRow>? _subscription;
  SettingsRow? _settings;
  ThemeMode _themeMode = ThemeMode.light;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Drift's stream fires when the admin edits the schedule, but nothing
    // fires when the clock merely crosses a boundary. Polling once a minute
    // deliberately beats a one-shot timer to the next boundary: that would
    // break on DST shifts, NTP corrections, manual clock changes and device
    // sleep, all of which happen on a tablet left running for years.
    // Comparing two ints once a minute self-corrects within 60 seconds.
    _ticker = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _applySettings(_settings),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribed here rather than in build so there is exactly one listener.
    // A direct subscription rather than a StreamBuilder because the resolved
    // theme depends on the clock as well as on the row; see rule 3.
    _subscription ??= Database.of(
      context,
    ).settingsDao.watchSettings().listen(_applySettings);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Dart timers are frozen while the device sleeps, so the app can wake on
    // the far side of a boundary having missed every tick.
    if (state == AppLifecycleState.resumed) _applySettings(_settings);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Adopts a settings row and the theme mode it resolves to right now.
  ///
  /// Both inputs land here: the database stream passes a new row, while the
  /// ticker and the resume hook pass back the row already held, so only the
  /// clock has moved. Null is the ticker firing before the first row arrives.
  void _applySettings(SettingsRow? settings) {
    if (settings == null) return;

    final themeMode = _themeModeFor(settings);
    if (settings == _settings && themeMode == _themeMode) return;

    // The one place the row is read, so this global cannot drift out of sync
    // with the database. It lets bare `NumberFormat.simpleCurrency()` and
    // `DateFormat.yMMMd()` calls anywhere use the stored language.
    Intl.defaultLocale = settings.languageCode;

    setState(() {
      _settings = settings;
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    // A frame or two before the first row arrives; the native launch screen is
    // still what covers everything up to here.
    if (settings == null) return const SizedBox.shrink();

    return _AppSettingsScope(
      settings: settings,
      themeMode: _themeMode,
      child: widget.child,
    );
  }
}

class _AppSettingsScope extends InheritedWidget {
  const _AppSettingsScope({
    required this.settings,
    required this.themeMode,
    required super.child,
  });

  final SettingsRow settings;
  final ThemeMode themeMode;

  @override
  bool updateShouldNotify(_AppSettingsScope oldWidget) =>
      settings != oldWidget.settings || themeMode != oldWidget.themeMode;
}

extension AppSettingsFormatting on SettingsRow {
  /// Formats an integer amount of minor units. See CLAUDE.md rule 2.
  ///
  /// `simpleCurrency` renders '€' where `currency` would render 'EUR'. The
  /// divisor is per-currency — not everything has 100 minor units.
  String formatMoney(int minorUnits) {
    final format = NumberFormat.simpleCurrency(
      locale: languageCode,
      // Always explicit: without it the currency comes from the locale, which
      // would ignore the setting whenever the two disagree.
      name: currencyCode,
    );
    final divisor = pow(10, format.decimalDigits ?? 2);
    return format.format(minorUnits / divisor);
  }
}
