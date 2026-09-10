import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/tables/transactions_table.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import 'money_text.dart';
import 'user_avatar.dart';

/// One ledger row, as a history line.
///
/// Takes the user alongside the row because a transaction stores only a
/// `userId` — history is never snapshotted, so that a corrected name is
/// corrected everywhere.
class TransactionListTile extends StatelessWidget {
  const TransactionListTile({
    super.key,
    required this.transaction,
    required this.user,
    this.onTap,
  });

  final TransactionRow transaction;
  final UserRow user;
  final VoidCallback? onTap;

  String _description(AppLocalizations l10n) => switch (transaction.type) {
    // The snapshot is nullable only because top-ups share the table; a
    // consumption always froze one.
    TransactionType.consumption => switch (transaction.itemNameSnapshot) {
      final name? when transaction.quantity > 1 => l10n.itemWithQuantity(
        name,
        transaction.quantity,
      ),
      final name? => name,
      _ => transaction.note ?? '',
    },
    TransactionType.topUp => transaction.note ?? l10n.transactionTopUp,
    TransactionType.adjustment =>
      transaction.note ?? l10n.transactionAdjustment,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = AppSettings.of(context);

    // A voided row stays in the record, struck through and dimmed: hidden from
    // balances, not from history. The decoration is merged into each text
    // rather than set on an ancestor, because ListTile puts its own styles on
    // the title and subtitle and would drop an inherited one.
    final voided = transaction.voidedAt != null;
    final struck = voided
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;

    return Opacity(
      opacity: voided ? 0.5 : 1,
      child: ListTile(
        onTap: onTap,
        // A mixed feed runs on the app's theme, so each row's avatar has to
        // bring the user's own colour with it.
        leading: UserAvatar(
          emoji: user.avatarEmoji,
          seedColorArgb: user.seedColorArgb,
          size: 44,
        ),
        title: Text(
          user.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: struck,
        ),
        subtitle: Text(
          _description(l10n),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: struck,
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            MoneyText(
              amountMinorUnits: transaction.amountMinorUnits,
              signed: true,
              style: struck,
            ),
            Text(
              settings.formatDateTime(transaction.createdAt),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
                  .merge(struck),
            ),
          ],
        ),
      ),
    );
  }
}
