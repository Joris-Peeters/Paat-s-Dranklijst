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

  /// Beneficiary details for the settle-up payment QR code.
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
  /// Formats an integer amount of minor units, in the stored language and
  /// currency.
  String formatMoney(int minorUnits) {
    final format = NumberFormat.simpleCurrency(
      locale: languageCode,
      // `simpleCurrency` renders '€' where `currency` would render 'EUR'.
      // Always naming the currency explicitly: without it the currency is
      // derived from the locale, which ignores the setting when they disagree.
      name: currencyCode,
    );
    // Not every currency has 100 minor units.
    final divisor = pow(10, format.decimalDigits ?? 2);
    return format.format(minorUnits / divisor);
  }
}
