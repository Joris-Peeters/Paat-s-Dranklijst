import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/settings/settings_data.dart';

void main() {
  _parseMoneyTests();
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

void _parseMoneyTests() {
  const eur = AppSettingsData();
  const jpy = AppSettingsData(currencyCode: 'JPY');

  group('formatAmount', () {
    const nl = AppSettingsData(languageCode: 'nl');

    test('writes no symbol, so a prefixed field shows it once', () {
      expect(eur.formatAmount(150), '1.50');
      expect(nl.formatAmount(150), '1,50');
      expect(eur.formatAmount(150), isNot(contains('\u20ac')));
    });

    test('does not group thousands', () {
      expect(eur.formatAmount(123450), '1234.50');
      expect(nl.formatAmount(123450), '1234,50');
    });

    test('respects a currency with no minor units', () {
      expect(jpy.formatAmount(500), '500');
    });

    test('round-trips through parseMoney', () {
      for (final settings in [eur, nl, jpy]) {
        for (final minor in [0, 5, 150, 123450]) {
          expect(
            settings.parseMoney(settings.formatAmount(minor)),
            minor,
            reason: '${settings.languageCode} $minor',
          );
        }
      }
    });
  });

  group('parseMoney', () {
    test('takes either separator as the decimal mark', () {
      expect(eur.parseMoney('1,50'), 150);
      expect(eur.parseMoney('1.50'), 150);
      expect(eur.parseMoney('-3.50'), -350);
      expect(eur.parseMoney('5,70'), 570);
    });

    test('fills in a short or missing fraction', () {
      expect(eur.parseMoney('1,5'), 150);
      expect(eur.parseMoney('2'), 200);
      expect(eur.parseMoney('0,05'), 5);
    });

    test('a lone separator is the decimal mark, not a thousands group', () {
      // Reading it the other way round would price a drink at a thousand
      // times its value.
      expect(eur.parseMoney('1.500'), 150);
      expect(eur.parseMoney('1,500'), 150);
    });

    test('a grouped amount is not an amount', () {
      // formatAmount writes no grouping, so nothing this reads back can carry
      // it, and guessing which separator grouped is how a price gets misread.
      expect(eur.parseMoney('1.234,50'), isNull);
      expect(eur.parseMoney('1,234.50'), isNull);
    });

    test('rejects anything that is not an amount', () {
      for (final junk in [
        '',
        '   ',
        'abc',
        '1,2,3',
        '1..5',
        '--1',
        '1a',
        // The field draws the symbol itself, so one in the text is a typo.
        '€1,50',
        // double.tryParse reads these, and round() throws on them.
        'Infinity',
        'NaN',
      ]) {
        expect(eur.parseMoney(junk), isNull, reason: junk);
      }
    });

    test('rounds to the currency precision rather than refusing', () {
      expect(eur.parseMoney('1,505'), 151);
      expect(jpy.parseMoney('500,5'), 501);
    });

    test('respects a currency with no minor units', () {
      expect(jpy.parseMoney('500'), 500);
    });

    test('is exact where binary floating point is not', () {
      // 1.15 * 100 is 114.99999999999999, and a cent short every time would
      // compound over a season.
      expect(eur.parseMoney('1.15'), 115);
      expect(eur.parseMoney('0.07'), 7);
      expect(eur.parseMoney('8.35'), 835);
    });
  });
}
