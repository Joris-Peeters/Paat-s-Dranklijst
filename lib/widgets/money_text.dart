import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import '../theme/app_theme.dart';

/// An amount of money, formatted and coloured by what it means.
///
/// Credit reads green, debt reads as an error, and zero takes the surrounding
/// text colour — a balance of nothing is not news. Zero still renders in full
/// rather than as a blank: an empty cell where an amount belongs reads as a
/// bug.
class MoneyText extends StatelessWidget {
  const MoneyText({
    super.key,
    required this.amountMinorUnits,
    this.signed = false,
    this.colored = true,
    this.style,
    this.textAlign,
  });

  final int amountMinorUnits;

  /// Puts an explicit `+` on a positive amount. For a list of ledger lines,
  /// where the direction of each row is the point; a standalone balance reads
  /// better without it.
  final bool signed;

  /// Whether the amount is coloured by what it means.
  ///
  /// False for a price tag: nobody holds a price, so painting one green would
  /// dilute the colour where it does mean something.
  final bool colored;

  /// The base style. The meaning is painted over it, so a caller can pass a
  /// themed style — or a strikethrough — without losing the colour.
  final TextStyle? style;

  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The formatter carries the stored language and currency, so the minus and
    // the symbol are already placed the way this locale places them.
    final amount = AppSettings.of(context).formatMoney(amountMinorUnits);

    final color = switch (amountMinorUnits.sign) {
      > 0 => creditColor(theme.brightness),
      < 0 => theme.colorScheme.error,
      _ => null,
    };

    return Text(
      signed && amountMinorUnits > 0
          ? AppLocalizations.of(context).amountPositive(amount)
          : amount,
      textAlign: textAlign,
      // The caller's style is the base and the meaning goes on top. Merging the
      // other way round let a themed style win on colour — `titleLarge` carries
      // one — which is the single thing this widget exists to decide. A null
      // colour (a zero balance) still leaves the caller's own.
      style: (style ?? const TextStyle()).merge(
        TextStyle(
          color: colored ? color : null,
          // Digits of equal width, so a column of amounts lines up.
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
