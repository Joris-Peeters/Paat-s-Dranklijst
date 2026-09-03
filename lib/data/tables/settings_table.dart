import 'package:drift/drift.dart';

import '../converters.dart';

/// How the app picks between the light and dark themes.
///
/// [scheduled] is dark between the configured wall-clock times. There is
/// deliberately no "follow system"
enum AppThemeMode { light, dark, scheduled }

/// The single settings row.
@DataClassName('SettingsRow')
class Settings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  // Enums are stored by name, never by ordinal: reordering the Dart enum would
  // silently change what every existing install's stored number means.
  TextColumn get themeMode =>
      textEnum<AppThemeMode>().withDefault(const Constant('scheduled'))();

  // Stored as minutes since midnight — comparable with integer arithmetic and
  // never malformed — but surfaced as TimeOfDay by the converter.
  IntColumn get darkStart => integer()
      .withDefault(const Constant(20 * 60))
      .map(const TimeOfDayConverter())();
  IntColumn get darkEnd => integer()
      .withDefault(const Constant(7 * 60))
      .map(const TimeOfDayConverter())();

  IntColumn get seedColorArgb =>
      integer().withDefault(const Constant(0xFF009688))(); // Colors.teal

  /// The UI language, one of `supportedLanguageCodes`.
  TextColumn get languageCode => text().withDefault(const Constant('en'))();

  /// ISO 4217 Currency code.
  TextColumn get currencyCode =>
      text().withLength(min: 3, max: 3).withDefault(const Constant('EUR'))();

  /// Plaintext. Doesn't have to be secure.
  TextColumn get adminPin => text().nullable()();

  BoolColumn get allowSelfRegistration =>
      boolean().withDefault(const Constant(true))();

  // Beneficiary details for the settle-up payment QR code.
  TextColumn get payeeName => text().nullable()();
  TextColumn get payeeIban => text().nullable()();

  DateTimeColumn get setupCompletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  // Single-row-ness enforced by the schema, not by convention.
  @override
  List<String> get customConstraints => const ['CHECK (id = 1)'];
}
