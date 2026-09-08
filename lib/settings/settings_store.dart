import 'package:shared_preferences/shared_preferences.dart';

import '../utils/time_of_day.dart';
import 'settings_data.dart';

const _themeMode = 'themeMode';
const _darkStart = 'darkStart';
const _darkEnd = 'darkEnd';
const _seedColorArgb = 'seedColorArgb';
const _languageCode = 'languageCode';
const _currencyCode = 'currencyCode';
const _allowSelfRegistration = 'allowSelfRegistration';
const _adminPin = 'adminPin';
const _payeeName = 'payeeName';
const _payeeIban = 'payeeIban';
const _setupCompletedAt = 'setupCompletedAt';

/// Every key this app stores. `SharedPreferencesWithCache` preloads exactly
/// these, so a new setting has to be added here as well as to
/// [AppSettingsData].
const _keys = <String>{
  _themeMode,
  _darkStart,
  _darkEnd,
  _seedColorArgb,
  _languageCode,
  _currencyCode,
  _allowSelfRegistration,
  _adminPin,
  _payeeName,
  _payeeIban,
  _setupCompletedAt,
};

/// Reads and writes [AppSettingsData]. The only place a preference key exists.
class SettingsStore {
  SettingsStore(this._prefs);

  final SharedPreferencesWithCache _prefs;

  /// Loads the whole store into memory, so [read] can be synchronous.
  static Future<SettingsStore> open() async => SettingsStore(
    await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(allowList: _keys),
    ),
  );

  /// Absent keys fall back to [AppSettingsData]'s own defaults, so a fresh
  /// install and a half-written store both read as a valid configuration.
  AppSettingsData read() {
    const defaults = AppSettingsData();

    final darkStart = _prefs.getInt(_darkStart);
    final darkEnd = _prefs.getInt(_darkEnd);
    final setupCompletedAt = _prefs.getInt(_setupCompletedAt);

    return AppSettingsData(
      themeMode: _readThemeMode() ?? defaults.themeMode,
      darkStart: darkStart == null
          ? defaults.darkStart
          : timeOfDayFromMinutes(darkStart),
      darkEnd: darkEnd == null
          ? defaults.darkEnd
          : timeOfDayFromMinutes(darkEnd),
      seedColorArgb: _prefs.getInt(_seedColorArgb) ?? defaults.seedColorArgb,
      languageCode: _prefs.getString(_languageCode) ?? defaults.languageCode,
      currencyCode: _prefs.getString(_currencyCode) ?? defaults.currencyCode,
      allowSelfRegistration:
          _prefs.getBool(_allowSelfRegistration) ??
          defaults.allowSelfRegistration,
      adminPin: _prefs.getString(_adminPin),
      payeeName: _prefs.getString(_payeeName),
      payeeIban: _prefs.getString(_payeeIban),
      setupCompletedAt: setupCompletedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(setupCompletedAt),
    );
  }

  Future<void> save(AppSettingsData settings) async {
    await Future.wait([
      // Stored by name, never by ordinal: reordering the Dart enum would
      // silently change what an existing install's stored value means.
      _prefs.setString(_themeMode, settings.themeMode.name),
      _prefs.setInt(_darkStart, settings.darkStart.minutesSinceMidnight),
      _prefs.setInt(_darkEnd, settings.darkEnd.minutesSinceMidnight),
      _prefs.setInt(_seedColorArgb, settings.seedColorArgb),
      _prefs.setString(_languageCode, settings.languageCode),
      _prefs.setString(_currencyCode, settings.currencyCode),
      _prefs.setBool(_allowSelfRegistration, settings.allowSelfRegistration),
      _setStringOrRemove(_adminPin, settings.adminPin),
      _setStringOrRemove(_payeeName, settings.payeeName),
      _setStringOrRemove(_payeeIban, settings.payeeIban),
      if (settings.setupCompletedAt case final at?)
        _prefs.setInt(_setupCompletedAt, at.millisecondsSinceEpoch)
      else
        _prefs.remove(_setupCompletedAt),
    ]);
  }

  /// An unrecognized name means the enum changed under a stored value; falling
  /// back beats throwing on every launch.
  AppThemeMode? _readThemeMode() {
    final name = _prefs.getString(_themeMode);
    for (final mode in AppThemeMode.values) {
      if (mode.name == name) return mode;
    }
    return null;
  }

  Future<void> _setStringOrRemove(String key, String? value) =>
      value == null ? _prefs.remove(key) : _prefs.setString(key, value);
}
