import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'data/database.dart';
import 'data/database_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/dark_mode_schedule.dart';

/// Ambient app settings, read from the database and published to the whole tree.
///
/// Sits above `MaterialApp` so it can feed `MaterialApp`'s own arguments —
/// `locale:`, `theme:` and `themeMode:`. See CLAUDE.md rules 4 and 5.
class AppSettings extends StatefulWidget {
  const AppSettings({super.key, required this.child});

  final Widget child;

  static AppSettingsAccessor of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_AppSettingsScope>();
    assert(scope != null, 'No AppSettings found in context');
    return AppSettingsAccessor._(scope!);
  }

  @override
  State<AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<AppSettings> {
  Stream<SettingsRow>? _settingsStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resolved here rather than in build so the stream is subscribed once
    // instead of on every rebuild.
    _settingsStream ??= Database.of(context).settingsDao.watchSettings();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SettingsRow>(
      stream: _settingsStream,
      builder: (context, snapshot) {
        final settings = snapshot.data;
        if (settings == null) return const SplashScreen();

        // The one place the row is read, so this global cannot drift out of
        // sync with the database. It lets bare `NumberFormat.simpleCurrency()`
        // and `DateFormat.yMMMd()` calls anywhere use the stored language.
        Intl.defaultLocale = settings.languageCode;

        return _ScheduledTheme(settings: settings, child: widget.child);
      },
    );
  }
}

/// Re-evaluates the dark-mode schedule as the clock moves and publishes the
/// result together with the settings row.
class _ScheduledTheme extends StatefulWidget {
  const _ScheduledTheme({required this.settings, required this.child});

  final SettingsRow settings;
  final Widget child;

  @override
  State<_ScheduledTheme> createState() => _ScheduledThemeState();
}

class _ScheduledThemeState extends State<_ScheduledTheme>
    with WidgetsBindingObserver {
  late AppBrightness _brightness = _resolve();
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
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void didUpdateWidget(_ScheduledTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings != oldWidget.settings) _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Dart timers are frozen while the device sleeps, so the app can wake on
    // the far side of a boundary having missed every tick.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  AppBrightness _resolve() => resolveBrightness(
    mode: widget.settings.themeMode,
    now: DateTime.now(),
    darkStartMinutes: widget.settings.darkStartMinutes,
    darkEndMinutes: widget.settings.darkEndMinutes,
  );

  void _refresh() {
    final resolved = _resolve();
    if (resolved != _brightness) setState(() => _brightness = resolved);
  }

  @override
  Widget build(BuildContext context) => _AppSettingsScope(
    settings: widget.settings,
    themeMode: _brightness == AppBrightness.dark
        ? ThemeMode.dark
        : ThemeMode.light,
    child: widget.child,
  );
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

/// Returned by [AppSettings.of]. Public only to appear in that signature.
class AppSettingsAccessor {
  const AppSettingsAccessor._(this._scope);

  final _AppSettingsScope _scope;

  /// The stored row, for settings without a convenience getter here.
  SettingsRow get settings => _scope.settings;

  /// For `MaterialApp.locale`. Always one of `supportedLanguageCodes`, so
  /// Flutter resolves it to itself.
  Locale get locale => Locale(_scope.settings.languageCode);

  String get currencyCode => _scope.settings.currencyCode;

  /// Already resolved to light or dark; never [ThemeMode.system].
  ThemeMode get themeMode => _scope.themeMode;

  /// Formats an integer amount of minor units. See CLAUDE.md rule 2.
  ///
  /// `simpleCurrency` renders '€' where `currency` would render 'EUR'. The
  /// divisor is per-currency — not everything has 100 minor units.
  String formatMoney(int minorUnits) {
    final format = NumberFormat.simpleCurrency(
      locale: _scope.settings.languageCode,
      // Always explicit: without it the currency comes from the locale, which
      // would ignore the setting whenever the two disagree.
      name: _scope.settings.currencyCode,
    );
    final divisor = pow(10, format.decimalDigits ?? 2);
    return format.format(minorUnits / divisor);
  }
}
