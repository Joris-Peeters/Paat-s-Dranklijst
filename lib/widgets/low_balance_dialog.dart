import 'package:flutter/material.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';

/// Tells a user they are in the red, on the way in to taking something.
///
/// Warns, never blocks. The fridge cannot take payment, so refusing entry would
/// only mean the drink leaves unlogged — a recorded debt is the better of the
/// two outcomes. Resolves true when they asked to top up first.
Future<bool> showLowBalanceDialog(
  BuildContext context, {
  required UserRow user,
  required int balanceMinorUnits,
}) async {
  final l10n = AppLocalizations.of(context);
  final settings = AppSettings.of(context);
  final theme = Theme.of(context);

  final topUp = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
      title: Text(l10n.lowBalanceTitle),
      content: Text(
        l10n.lowBalanceBody(user.name, settings.formatMoney(balanceMinorUnits)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.continueAnyway),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.add_card),
          label: Text(l10n.topUp),
        ),
      ],
    ),
  );

  // Dismissed by tapping outside: they did not ask to top up, and nothing is
  // held against them for it.
  return topUp ?? false;
}
