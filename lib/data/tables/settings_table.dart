import 'package:drift/drift.dart';

/// How the app picks between the light and dark themes.
///
/// [scheduled] is dark between the configured wall-clock times. There is
/// deliberately no "follow system"
enum AppThemeMode { light, dark, scheduled }

/// Which page the app opens on.
enum StartupPage { start, users }

/// The single settings row. See CLAUDE.md rule 3: the database is the only
/// source of truth for app state, so a restored database file restores it all.
@DataClassName('SettingsRow')
class Settings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  // Enums are stored by name, never by ordinal: reordering the Dart enum would
  // silently change what every existing install's stored number means.
  TextColumn get themeMode =>
      textEnum<AppThemeMode>().withDefault(const Constant('scheduled'))();

  // Minutes since midnight — comparable with integer arithmetic, never malformed.
  IntColumn get darkStartMinutes => integer().withDefault(const Constant(20 * 60))();
  IntColumn get darkEndMinutes => integer().withDefault(const Constant(7 * 60))();

  /// Resolved ARGB, not an index into the palette. See CLAUDE.md rule 4.
  IntColumn get seedColorArgb =>
      integer().withDefault(const Constant(0xFF009688))(); // Colors.teal

  /// The UI language, one of `supportedLanguageCodes`. Language only — no
  /// regional variants.
  TextColumn get languageCode => text().withDefault(const Constant('en'))();

  /// ISO 4217. Independent of [languageCode]: the language says how numbers
  /// look, this says what money is in the tin.
  TextColumn get currencyCode =>
      text().withLength(min: 3, max: 3).withDefault(const Constant('EUR'))();

  /// Plaintext. This is an honour-system app with no per-user login; the PIN
  /// only stops casual tampering. Recovery is reading the database off the
  /// tablet.
  TextColumn get adminPin => text().nullable()();

  BoolColumn get allowSelfRegistration =>
      boolean().withDefault(const Constant(true))();

  // Beneficiary details for the settle-up payment QR code.
  TextColumn get payeeName => text().nullable()();
  TextColumn get payeeIban => text().nullable()();

  TextColumn get startupPage =>
      textEnum<StartupPage>().withDefault(const Constant('start'))();

  DateTimeColumn get setupCompletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  // Single-row-ness enforced by the schema, not by convention.
  @override
  List<String> get customConstraints => const ['CHECK (id = 1)'];
}
