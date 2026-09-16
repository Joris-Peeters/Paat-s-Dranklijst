import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/balance_csv.dart';
import '../data/balance_import.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import 'card_heading.dart';

/// The balances CSV as a bzip2-compressed binary QR code, for a phone to keep.
///
/// Built once each time the card appears, from the data as it is then; nothing
/// is written to disk.
class BalancesQrCard extends StatefulWidget {
  const BalancesQrCard({super.key});

  @override
  State<BalancesQrCard> createState() => _BalancesQrCardState();
}

/// [qr] is null when the compressed CSV is past what one QR code holds.
typedef _BalancesQr = ({QrCode? qr, int userCount, DateTime at});

class _BalancesQrCardState extends State<BalancesQrCard> {
  static const _maxSize = 480.0;

  // Built on first use: `Database.of` depends on an inherited widget, so it
  // cannot run in initState.
  late final Future<_BalancesQr> _data = _load();

  Future<_BalancesQr> _load() async {
    final db = Database.of(context);
    final settings = AppSettings.of(context);
    final at = DateTime.now();

    final userCount = (await db.usersDao.readUsersWithBalances()).length;
    final csv = await exportBalancesCsv(
      db,
      decimalDigits: settings.currencyDecimalDigits,
    );
    return (qr: _qrFor(compressBalancesCsv(csv)), userCount: userCount, at: at);
  }

  /// Level L leaves the most room, and a screen does not get scratched the way
  /// print does. The size check only happens when the modules are laid out, so
  /// that is done here rather than letting `QrImageView` fail while painting.
  static QrCode? _qrFor(Uint8List bytes) {
    try {
      final qr = QrCode.fromUint8List(
        data: bytes,
        errorCorrectLevel: QrErrorCorrectLevel.L,
      );
      QrImage(qr);
      return qr;
    } on InputTooLongException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardHeading(icon: Icons.qr_code_2_rounded, label: l10n.balancesQr),
            LayoutBuilder(
              builder: (context, constraints) {
                final size = min(constraints.maxWidth - 32, _maxSize);

                return FutureBuilder<_BalancesQr>(
                  future: _data,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    final qr = data?.qr;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        spacing: 12,
                        children: [
                          if (snapshot.hasError)
                            _Placeholder(size: size, message: l10n.exportFailed)
                          else if (data == null)
                            SizedBox.square(dimension: size)
                          else if (qr == null)
                            _Placeholder(
                              size: size,
                              message: l10n.balancesQrTooLarge,
                            )
                          else
                            DecoratedBox(
                              decoration: BoxDecoration(
                                // Scanners expect dark modules on light, so
                                // not the colour scheme.
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: QrImageView.withQr(
                                qr: qr,
                                size: size,
                                backgroundColor: Colors.white,
                                // The quiet zone the QR standard requires.
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          if (data != null)
                            Text(
                              l10n.balancesQrCaption(
                                data.userCount,
                                settings.formatDateTime(data.at),
                              ),
                              style: theme.textTheme.titleSmall,
                            ),
                          Text(
                            l10n.balancesQrHelp,
                            style: muted,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Stands in for the code at its size, with why there is none.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size, required this.message});

  final double size;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.outline;

    return SizedBox.square(
      dimension: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 16,
        children: [
          Icon(Icons.qr_code_2_rounded, size: size / 3, color: color),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
