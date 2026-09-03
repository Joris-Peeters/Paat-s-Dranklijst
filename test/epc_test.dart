import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/utils/banking.dart';

void main() {
  group('buildEpcPayload', () {
    test('builds the standard field order', () {
      final payload = buildEpcPayload(
        beneficiaryName: 'Chiro Paat',
        iban: 'BE71 0961 2345 6769',
        amountMinorUnits: 1250,
        unstructuredMessage: 'Dranklijst Joris',
      );

      expect(payload.split('\n'), <String>[
        'BCD',
        '002',
        '1',
        'SCT',
        '',
        'Chiro Paat',
        'BE71096123456769', // spaces stripped
        'EUR12.50',
        '',
        '',
        'Dranklijst Joris',
      ]);
    });

    test('pads and scales the amount without floating point', () {
      String amountOf(int minorUnits) => buildEpcPayload(
        beneficiaryName: 'Chiro Paat',
        iban: 'BE71096123456769',
        amountMinorUnits: minorUnits,
      ).split('\n')[7];

      expect(amountOf(1), 'EUR0.01');
      expect(amountOf(105), 'EUR1.05');
      expect(amountOf(100), 'EUR1.00');
      expect(amountOf(epcMaxAmountMinorUnits), 'EUR999999999.99');
    });

    test('leaves the amount empty when it is zero', () {
      final payload = buildEpcPayload(
        beneficiaryName: 'Chiro Paat',
        iban: 'BE71096123456769',
        amountMinorUnits: 0,
      );
      expect(payload.split('\n')[7], '');
    });

    test('omits the message field when there is none', () {
      final payload = buildEpcPayload(
        beneficiaryName: 'Chiro Paat',
        iban: 'BE71096123456769',
        amountMinorUnits: 1250,
      );
      // Trailing empties are dropped, so the message line is just blank.
      expect(payload.split('\n').last, '');
      expect(payload.split('\n').length, 11);
    });

    test('collapses whitespace so nothing forges a field separator', () {
      final payload = buildEpcPayload(
        beneficiaryName: '  Chiro\nPaat  ',
        iban: 'BE71096123456769',
        amountMinorUnits: 0,
        unstructuredMessage: 'line\none\tand two',
      );
      expect(payload.split('\n')[5], 'Chiro Paat');
      expect(payload.split('\n').last, 'line one and two');
    });

    test('rejects a missing or invalid IBAN', () {
      expect(
        () => buildEpcPayload(
          beneficiaryName: 'Chiro Paat',
          iban: '',
          amountMinorUnits: 1250,
        ),
        throwsArgumentError,
      );
      expect(
        () => buildEpcPayload(
          beneficiaryName: 'Chiro Paat',
          iban: 'BE72096123456769',
          amountMinorUnits: 1250,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an empty or over-long name', () {
      expect(
        () => buildEpcPayload(
          beneficiaryName: '   ',
          iban: 'BE71096123456769',
          amountMinorUnits: 1250,
        ),
        throwsArgumentError,
      );
      expect(
        () => buildEpcPayload(
          beneficiaryName: 'a' * (epcMaxNameLength + 1),
          iban: 'BE71096123456769',
          amountMinorUnits: 1250,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an out-of-range amount', () {
      expect(
        () => buildEpcPayload(
          beneficiaryName: 'Chiro Paat',
          iban: 'BE71096123456769',
          amountMinorUnits: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => buildEpcPayload(
          beneficiaryName: 'Chiro Paat',
          iban: 'BE71096123456769',
          amountMinorUnits: epcMaxAmountMinorUnits + 1,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an over-long message', () {
      expect(
        () => buildEpcPayload(
          beneficiaryName: 'Chiro Paat',
          iban: 'BE71096123456769',
          amountMinorUnits: 1250,
          unstructuredMessage: 'a' * (epcMaxMessageLength + 1),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a payload over the byte limit', () {
      // Each field is legal on its own; together they exceed 331 bytes, and
      // multi-byte characters count double towards that.
      expect(
        () => buildEpcPayload(
          beneficiaryName: 'é' * epcMaxNameLength,
          iban: 'BE71096123456769',
          amountMinorUnits: 1250,
          unstructuredMessage: 'é' * epcMaxMessageLength,
        ),
        throwsArgumentError,
      );
    });
  });
}
