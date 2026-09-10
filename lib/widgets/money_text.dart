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
    this.style,
    this.textAlign,
  });

  final int amountMinorUnits;

  /// Puts an explicit `+` on a positive amount. For a list of ledger lines,
  /// where the direction of each row is the point; a standalone balance reads
  /// better without it.
  final bool signed;

  /// Merged over the resolved colour, so a caller can strike the amount
  /// through without losing it.
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
      style: TextStyle(
        color: color,
        // Digits of equal width, so a column of amounts lines up.
        fontFeatures: const [FontFeature.tabularFigures()],
      ).merge(style),
    );
  }
}
