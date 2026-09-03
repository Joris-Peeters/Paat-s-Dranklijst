import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/utils/banking.dart';

void main() {
  group('isValidIban', () {
    test('accepts real IBANs from several countries', () {
      expect(isValidIban('BE71096123456769'), isTrue); // Belgium
      expect(isValidIban('NL91ABNA0417164300'), isTrue); // Netherlands
      expect(isValidIban('DE89370400440532013000'), isTrue); // Germany
      expect(isValidIban('GB33BUKB20201555555555'), isTrue); // United Kingdom
      expect(isValidIban('FR7630006000011234567890189'), isTrue); // France
    });

    test('accepts spaced and lower-case input', () {
      expect(isValidIban('BE71 0961 2345 6769'), isTrue);
      expect(isValidIban('be71 0961 2345 6769'), isTrue);
    });

    test('empty means no QR code, not a mistake', () {
      expect(isValidIban(''), isTrue);
      expect(isValidIban('   '), isTrue);
    });

    test('rejects a transposed digit', () {
      // The digits 67 and 76 swapped in the last block of a valid IBAN.
      expect(isValidIban('BE71096123456769'), isTrue);
      expect(isValidIban('BE71096123457669'), isFalse);
    });

    test('rejects wrong check digits', () {
      expect(isValidIban('BE72096123456769'), isFalse);
    });

    test('rejects malformed input', () {
      expect(isValidIban('1E71096123456769'), isFalse); // digits for country
      expect(isValidIban('BEX1096123456769'), isFalse); // letters for check
      expect(isValidIban('BE71-0961-2345-6769'), isFalse); // punctuation
      expect(isValidIban('BE7109'), isFalse); // too short
      expect(isValidIban('BE71${'0' * 40}'), isFalse); // too long
    });
  });
}
