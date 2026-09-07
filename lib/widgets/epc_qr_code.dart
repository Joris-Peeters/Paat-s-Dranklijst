import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../utils/banking.dart';

/// A SEPA Credit Transfer QR code, ready for a banking app to scan.
///
/// Renders a greyed-out placeholder of the same size whenever the details do
/// not make a valid payload — most often because no IBAN has been set yet.
class EpcQrCode extends StatelessWidget {
  const EpcQrCode({
    super.key,
    required this.beneficiaryName,
    required this.iban,
    this.amountMinorUnits = 0,
    this.message,
    this.size = 240,
  });

  /// Both are nullable so the settings columns can be passed straight through.
  final String? beneficiaryName;
  final String? iban;

  /// In cents (see rule 2). 0 leaves the amount for the payer to fill in.
  final int amountMinorUnits;

  final String? message;
  final double size;

  /// Null when the details cannot make a payload the standard accepts.
  QrCode? _buildQrCode() {
    final name = beneficiaryName;
    final account = iban;
    if (name == null || account == null) return null;

    try {
      return QrCode.fromUint8List(
        data: buildEpcPayload(
          beneficiaryName: name,
          iban: account,
          amountMinorUnits: amountMinorUnits,
          unstructuredMessage: message,
        ),
        // EPC069-12 requires level M. Encoding the bytes rather than a string
        // keeps the payload in one byte-mode segment, which is what a bank's
        // scanner expects; a string would be split into mixed modes.
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
    } on ArgumentError {
      // buildEpcPayload validates rather than truncates, and a kiosk must never
      // show a red error box. epcMaxPayloadBytes keeps this inside version 13,
      // so InputTooLongException cannot fire.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final qr = _buildQrCode();

    if (qr == null) {
      return SizedBox.square(
        dimension: size,
        child: Icon(
          Icons.qr_code_2_rounded,
          size: size / 2,
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        // Deliberately not the colour scheme, unlike everything else (rule 4):
        // scanners expect dark modules on light, and dark mode would invert it.
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: QrImageView.withQr(
        qr: qr,
        size: size,
        backgroundColor: Colors.white,
        // The quiet zone the QR standard requires; not decorative.
        padding: const EdgeInsets.all(16),
      ),
    );
  }
}
