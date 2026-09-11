import 'dart:math';

import 'package:flutter/material.dart' show TimeOfDay, immutable;
import 'package:intl/intl.dart';

/// How the app picks between the light and dark themes.
///
/// [scheduled] is dark between the configured wall-clock times. There is
/// deliberately no "follow system": a kiosk tablet's system theme is fixed.
enum AppThemeMode { light, dark, scheduled }

/// Distinguishes "leave this field alone" from "set this field to null" in
/// [AppSettingsData.copyWith]. Only the nullable fields need it.
const Object _unset = Object();

/// Every app setting, as one immutable value.
///
/// The constructor defaults are the settings a fresh install starts with.
@immutable
class AppSettingsData {
  const AppSettingsData({
    this.themeMode = AppThemeMode.scheduled,
    this.darkStart = const TimeOfDay(hour: 20, minute: 0),
    this.darkEnd = const TimeOfDay(hour: 7, minute: 0),
    this.seedColorArgb = 0xFF009688,
    this.languageCode = 'en',
    this.currencyCode = 'EUR',
    this.allowSelfRegistration = true,
    this.adminPin,
    this.payeeName,
    this.payeeIban,
    this.setupCompletedAt,
  });

  final AppThemeMode themeMode;
  final TimeOfDay darkStart;
  final TimeOfDay darkEnd;
  final int seedColorArgb;

  /// The UI language, always one of `AppLocalizations.supportedLocales`.
  final String languageCode;

  /// ISO 4217 currency code.
  final String currencyCode;

  final bool allowSelfRegistration;

  /// Plaintext. Doesn't have to be secure.
  final String? adminPin;

  /// Beneficiary details for the top-up payment QR code.
  final String? payeeName;
  final String? payeeIban;

  /// Null until the first-run wizard finishes.
  final DateTime? setupCompletedAt;

  /// Passing null to one of the nullable fields clears it; omitting the
  /// argument leaves it as it was.
  AppSettingsData copyWith({
    AppThemeMode? themeMode,
    TimeOfDay? darkStart,
    TimeOfDay? darkEnd,
    int? seedColorArgb,
    String? languageCode,
    String? currencyCode,
    bool? allowSelfRegistration,
    Object? adminPin = _unset,
    Object? payeeName = _unset,
    Object? payeeIban = _unset,
    Object? setupCompletedAt = _unset,
  }) => AppSettingsData(
    themeMode: themeMode ?? this.themeMode,
    darkStart: darkStart ?? this.darkStart,
    darkEnd: darkEnd ?? this.darkEnd,
    seedColorArgb: seedColorArgb ?? this.seedColorArgb,
    languageCode: languageCode ?? this.languageCode,
    currencyCode: currencyCode ?? this.currencyCode,
    allowSelfRegistration: allowSelfRegistration ?? this.allowSelfRegistration,
    adminPin: identical(adminPin, _unset) ? this.adminPin : adminPin as String?,
    payeeName: identical(payeeName, _unset)
        ? this.payeeName
        : payeeName as String?,
    payeeIban: identical(payeeIban, _unset)
        ? this.payeeIban
        : payeeIban as String?,
    setupCompletedAt: identical(setupCompletedAt, _unset)
        ? this.setupCompletedAt
        : setupCompletedAt as DateTime?,
  );

  // Equality is what stops the once-a-minute theme re-resolve from rebuilding
  // the whole tree when nothing has actually changed.
  @override
  bool operator ==(Object other) =>
      other is AppSettingsData &&
      other.themeMode == themeMode &&
      other.darkStart == darkStart &&
      other.darkEnd == darkEnd &&
      other.seedColorArgb == seedColorArgb &&
      other.languageCode == languageCode &&
      other.currencyCode == currencyCode &&
      other.allowSelfRegistration == allowSelfRegistration &&
      other.adminPin == adminPin &&
      other.payeeName == payeeName &&
      other.payeeIban == payeeIban &&
      other.setupCompletedAt == setupCompletedAt;

  @override
  int get hashCode => Object.hash(
    themeMode,
    darkStart,
    darkEnd,
    seedColorArgb,
    languageCode,
    currencyCode,
    allowSelfRegistration,
    adminPin,
    payeeName,
    payeeIban,
    setupCompletedAt,
  );
}

extension AppSettingsFormatting on AppSettingsData {
  /// `simpleCurrency` renders '€' where `currency` would render 'EUR'. Always
  /// naming the currency explicitly: without it the currency is derived from
  /// the locale, which ignores the setting when the two disagree.
  NumberFormat get _currencyFormat =>
      NumberFormat.simpleCurrency(locale: languageCode, name: currencyCode);

  /// Formats an integer amount of minor units, in the stored language and
  /// currency.
  ///
  /// [signed] puts an explicit plus on a positive amount, in whatever slot this
  /// locale gives the minus — ahead of the symbol in English, behind it in
  /// Dutch. It lands there by formatting the negative and swapping the sign
  /// character: pasting a '+' on the front was right in English and wrong in
  /// Dutch, where it disagreed with every negative row under it.
  String formatMoney(int minorUnits, {bool signed = false}) {
    final format = _currencyFormat;
    // Not every currency has 100 minor units.
    final divisor = pow(10, format.decimalDigits ?? 2);

    if (signed && minorUnits > 0) {
      return format
          .format(-minorUnits / divisor)
          .replaceFirst(format.symbols.MINUS_SIGN, format.symbols.PLUS_SIGN);
    }
    return format.format(minorUnits / divisor);
  }

  /// The bare number, for seeding an editable amount field.
  ///
  /// [formatMoney] is a display formatter and always writes the symbol, so a
  /// field that draws its own prefix would show it twice. Grouping is off as
  /// well: a price is a small number, and a thousands separator in an editable
  /// field is punctuation the admin has to type around, next to a decimal mark
  /// that may be the same glyph. The decimal mark itself still follows the
  /// chosen language, so it reads the way money does everywhere else, and
  /// [parseMoney] reads it back.
  String formatAmount(int minorUnits) {
    final digits = _currencyFormat.decimalDigits ?? 2;
    final format = NumberFormat.decimalPatternDigits(
      locale: languageCode,
      decimalDigits: digits,
    )..turnOffGrouping();
    return format.format(minorUnits / pow(10, digits));
  }

  /// The symbol alone, for a price field's prefix.
  String get currencySymbol => _currencyFormat.currencySymbol;

  /// How many minor units make one of the currency's whole units.
  ///
  /// For turning a preset written as "10" into an amount. Most currencies use
  /// 100, but JPY uses 1 and some Gulf-state dinars 1000, so the divisor is
  /// asked for rather than assumed here as everywhere else.
  int get minorUnitsPerMajor =>
      pow(10, _currencyFormat.decimalDigits ?? 2).toInt();

  /// Minor units from typed text, or null when it is not an amount.
  ///
  /// Takes either separator as the decimal mark rather than the one this
  /// language writes: a tablet's number pad usually offers only one of them,
  /// and which it is has nothing to do with the language the admin chose.
  /// Scales by the currency's own decimal count instead of assuming 100 minor
  /// units.
  int? parseMoney(String text) {
    final amount = double.tryParse(text.trim().replaceAll(',', '.'));
    // tryParse also reads "Infinity" and "NaN", and round() throws on those.
    if (amount == null || !amount.isFinite) return null;
    // Rounded, not truncated: 1.15 * 100 is 114.99999999999999 in binary
    // floating point, and a price a cent short would compound over a season.
    return (amount * pow(10, _currencyFormat.decimalDigits ?? 2)).round();
  }

  /// An absolute date and time in the stored language.
  ///
  /// Here rather than at the call site for the same reason as [formatMoney]:
  /// the language is a setting, not the device locale, and a widget that
  /// reached for `DateFormat` itself would quietly use the wrong one.
  String formatDateTime(DateTime at) =>
      DateFormat.yMMMd(languageCode).add_Hm().format(at);

  /// The date alone, with its weekday — for a day header over a list that
  /// already prints each row's time.
  String formatDate(DateTime at) => DateFormat.yMMMEd(languageCode).format(at);
}
