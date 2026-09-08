import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/settings/settings_data.dart';

void main() {
  group('AppSettingsData equality', () {
    test('two defaults are equal and hash alike', () {
      expect(const AppSettingsData(), const AppSettingsData());
      expect(
        const AppSettingsData().hashCode,
        const AppSettingsData().hashCode,
      );
    });

    test('every field participates', () {
      const base = AppSettingsData();
      final variants = <AppSettingsData>[
        base.copyWith(themeMode: AppThemeMode.dark),
        base.copyWith(darkStart: const TimeOfDay(hour: 21, minute: 30)),
        base.copyWith(darkEnd: const TimeOfDay(hour: 6, minute: 15)),
        base.copyWith(seedColorArgb: 0xFF123456),
        base.copyWith(languageCode: 'nl'),
        base.copyWith(currencyCode: 'USD'),
        base.copyWith(allowSelfRegistration: false),
        base.copyWith(adminPin: '1234'),
        base.copyWith(payeeName: 'Chiro'),
        base.copyWith(payeeIban: 'BE68539007547034'),
        base.copyWith(setupCompletedAt: DateTime(2026)),
      ];

      for (final variant in variants) {
        expect(variant, isNot(base));
      }
    });
  });

  group('AppSettingsData.copyWith', () {
    test('leaves untouched fields alone', () {
      final original = const AppSettingsData().copyWith(
        adminPin: '1234',
        payeeName: 'Chiro',
      );
      final changed = original.copyWith(languageCode: 'nl');

      expect(changed.languageCode, 'nl');
      expect(changed.adminPin, '1234');
      expect(changed.payeeName, 'Chiro');
    });

    test('an explicit null clears a nullable field', () {
      final withPin = const AppSettingsData().copyWith(adminPin: '1234');

      expect(withPin.copyWith(adminPin: null).adminPin, isNull);
      expect(withPin.copyWith(payeeIban: null).adminPin, '1234');
    });

    test('clears each nullable field independently', () {
      final full = const AppSettingsData().copyWith(
        adminPin: '1234',
        payeeName: 'Chiro',
        payeeIban: 'BE68539007547034',
        setupCompletedAt: DateTime(2026),
      );

      expect(full.copyWith(payeeName: null).payeeName, isNull);
      expect(full.copyWith(payeeName: null).payeeIban, 'BE68539007547034');
      expect(full.copyWith(setupCompletedAt: null).setupCompletedAt, isNull);
      expect(full.copyWith(setupCompletedAt: null).adminPin, '1234');
    });
  });

  group('formatMoney', () {
    test('follows the stored language and currency', () {
      const en = AppSettingsData();
      expect(en.formatMoney(1250), '€12.50');

      const nl = AppSettingsData(languageCode: 'nl');
      // Non-breaking space between symbol and amount in nl.
      expect(nl.formatMoney(1250).replaceAll(' ', ' '), '€ 12,50');
    });

    test('renders the symbol, not the code', () {
      const usd = AppSettingsData(currencyCode: 'USD');
      expect(usd.formatMoney(1250), contains(r'$'));
      expect(usd.formatMoney(1250), isNot(contains('USD')));
    });

    test('handles negatives, zero and a 0-digit currency', () {
      const en = AppSettingsData();
      expect(en.formatMoney(0), '€0.00');
      expect(en.formatMoney(-300), contains('3.00'));

      // JPY has no minor units, so the divisor must not be a hardcoded 100.
      const jpy = AppSettingsData(currencyCode: 'JPY');
      expect(jpy.formatMoney(1250), contains('1,250'));
    });
  });
}
