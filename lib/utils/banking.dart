import 'dart:convert';
import 'dart:typed_data';

/// Whether [input] passes the IBAN mod-97 checksum (ISO 13616).
/// Empty is **valid**: no IBAN simply means no settle-up QR code.
bool isValidIban(String input) {
  final iban = input.replaceAll(' ', '').toUpperCase();
  if (iban.isEmpty) return true;
  if (iban.length < 15 || iban.length > 34) return false;
  if (!RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]+$').hasMatch(iban)) return false;

  // Move the country code and check digits to the end, then read the result as
  // one long number with letters as 10..35. Accumulating the remainder digit by
  // digit keeps it in int range; the whole number would need BigInt.
  final rearranged = iban.substring(4) + iban.substring(0, 4);
  var remainder = 0;
  for (final unit in rearranged.codeUnits) {
    final value = unit >= 0x41 ? unit - 0x41 + 10 : unit - 0x30; // 'A' : '0'
    // Letters contribute two digits, so they need two steps.
    remainder = value > 9
        ? (remainder * 100 + value) % 97
        : (remainder * 10 + value) % 97;
  }
  return remainder == 1;
}

/// Whether [input] is shaped like an ISO 4217 currency code.
///
/// Only the shape is checked — there is no list of live codes to check against,
/// and inventing one would date badly.
bool isValidCurrencyCode(String input) => RegExp(r'^[A-Z]{3}$').hasMatch(input);

/// Longest name the EPC standard allows for the beneficiary.
const epcMaxNameLength = 70;

/// Longest unstructured remittance message the EPC standard allows.
const epcMaxMessageLength = 140;

/// Largest transfer an EPC QR code can carry: EUR 999 999 999.99.
const epcMaxAmountMinorUnits = 99999999999;

/// The whole payload must stay within this many UTF-8 bytes.
const epcMaxPayloadBytes = 331;

/// Builds the text encoded in a SEPA Credit Transfer QR code, per the EPC's
/// "Quick Response Code Guidelines" (EPC069-12, version 002).
///
/// The result is a plain string of newline-separated fields; feeding it to
/// `QrImageView` is all the settle-up screen has to do. Banking apps scan it to
/// prefill a transfer, so a malformed payload is worse than none — every
/// constraint below is validated rather than silently truncated.
///
/// [amountMinorUnits] is in cents, like all money in this app (see rule 2), and
/// may be 0 to leave the amount for the payer to fill in. The scheme is
/// euro-only, so cents are the right unit by definition here.
///
/// Throws [ArgumentError] if any field breaks the standard.
Uint8List buildEpcPayload({
  required String beneficiaryName,
  required String iban,
  required int amountMinorUnits,
  String? unstructuredMessage,
}) {
  // Newlines separate the fields, so they can never appear inside one.
  final name = _collapseWhitespace(beneficiaryName);
  if (name.isEmpty) {
    throw ArgumentError.value(beneficiaryName, 'beneficiaryName', 'is empty');
  }
  if (name.length > epcMaxNameLength) {
    throw ArgumentError.value(
      beneficiaryName,
      'beneficiaryName',
      'is longer than $epcMaxNameLength characters',
    );
  }

  final account = iban.replaceAll(' ', '').toUpperCase();
  // isValidIban accepts empty — a QR code without an account does not.
  if (account.isEmpty || !isValidIban(account)) {
    throw ArgumentError.value(iban, 'iban', 'is not a valid IBAN');
  }

  if (amountMinorUnits < 0 || amountMinorUnits > epcMaxAmountMinorUnits) {
    throw ArgumentError.value(
      amountMinorUnits,
      'amountMinorUnits',
      'is outside the range an EPC QR code can carry',
    );
  }

  final message = _collapseWhitespace(unstructuredMessage ?? '');
  if (message.length > epcMaxMessageLength) {
    throw ArgumentError.value(
      unstructuredMessage,
      'unstructuredMessage',
      'is longer than $epcMaxMessageLength characters',
    );
  }

  final fields = <String>[
    'BCD', // service tag
    '002', // version; 002 is the one that makes the BIC optional
    '1', // character set, 1 = UTF-8
    'SCT', // SEPA Credit Transfer
    '', // BIC — not needed for SEPA transfers
    name,
    account,
    // Integer arithmetic, never a double: the scheme is EUR-only and EUR has
    // exactly two decimals, so the divisor is fixed here (unlike formatMoney).
    if (amountMinorUnits > 0)
      'EUR${amountMinorUnits ~/ 100}.'
          '${(amountMinorUnits % 100).toString().padLeft(2, '0')}'
    else
      '',
    '', // purpose code
    '', // structured creditor reference — mutually exclusive with the message
    message,
    // Beneficiary-to-originator information is always empty, and trailing empty
    // fields may be dropped, so the payload simply ends here.
  ];

  final payload = utf8.encode(fields.join('\n'));
  final byteLength = payload.length;
  if (byteLength > epcMaxPayloadBytes) {
    throw ArgumentError(
      'EPC payload is $byteLength bytes, over the $epcMaxPayloadBytes limit',
    );
  }
  return payload;
}

String _collapseWhitespace(String input) =>
    input.trim().replaceAll(RegExp(r'\s+'), ' ');
