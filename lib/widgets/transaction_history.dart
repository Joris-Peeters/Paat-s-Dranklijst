import 'dart:async';

import 'package:flutter/material.dart';

import '../data/daos/transactions_dao.dart';
import '../data/database.dart';
import '../data/database_provider.dart';
import '../data/tables/transactions_table.dart';
import '../l10n/app_localizations.dart';
import '../screens/history_screen.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import 'money_text.dart';
import 'transaction_detail_dialog.dart';
import 'user_avatar.dart';

/// Diameter of whatever leads a history row, whichever form it is in. Shared so
/// a top-up and a drink line up down the left edge.
const _leadingSize = 44.0;

/// One ledger row, as a history line.
///
/// Two forms, because a feed that mixes users and a feed that is one user's own
/// page need different things on screen — not the same things rearranged. The
/// default names the person; [TransactionListTile.forUser] takes that as read
/// and names what was taken instead.
class TransactionListTile extends StatelessWidget {
  /// A row in a feed that mixes users: their avatar and name lead.
  const TransactionListTile({super.key, required this.entry, this.onTap})
    : _showUser = true;

  /// A row on one user's own page. The name is the page they are looking at, so
  /// the line drops it and leads with the item's emoji.
  const TransactionListTile.forUser({
    super.key,
    required this.entry,
    this.onTap,
  }) : _showUser = false;

  final TransactionEntry entry;
  final VoidCallback? onTap;

  final bool _showUser;

  String _description(AppLocalizations l10n) {
    final transaction = entry.transaction;

    return switch (transaction.type) {
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
  }

  /// The one line that says what happened.
  ///
  /// On a mixed feed the leading circle is the user's avatar, so the item's
  /// emoji has nowhere else to go and sits inline: "Jonas · 🥤 Cola ×2".
  String _titleLine(AppLocalizations l10n) {
    final description = _description(l10n);
    if (!_showUser) return description;

    final emoji = entry.item?.emoji;
    return emoji == null
        ? '${entry.user.name} · $description'
        : '${entry.user.name} · $emoji $description';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = AppSettings.of(context);
    final transaction = entry.transaction;

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
        leading: _showUser
            // A mixed feed runs on the app's theme, so each row's avatar has to
            // bring the user's own colour with it.
            ? UserAvatar(
                emoji: entry.user.avatarEmoji,
                seedColorArgb: entry.user.seedColorArgb,
                size: _leadingSize,
              )
            : _ItemLeading(entry: entry),
        title: Text(
          _titleLine(l10n),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: struck,
        ),
        // Under the name rather than beside the amount: it is the quieter of
        // the two and belongs with the words, which leaves the right-hand side
        // to the one number the row is about.
        subtitle: Text(
          settings.formatDateTime(transaction.createdAt),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
              .merge(struck),
        ),
        trailing: MoneyText(
          amountMinorUnits: transaction.amountMinorUnits,
          signed: true,
          style: theme.textTheme.titleMedium?.merge(struck),
        ),
      ),
    );
  }
}

/// What a row leads with once the user is already known: the item's emoji, or
/// an icon standing in for the types that reference no item.
///
/// The emoji is the item's current one — it is not snapshotted, unlike the name
/// and the price the row does carry.
class _ItemLeading extends StatelessWidget {
  const _ItemLeading({required this.entry});

  final TransactionEntry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.item case final item?) {
      return AvatarCircle(emoji: item.emoji, size: _leadingSize);
    }

    final colors = Theme.of(context).colorScheme;
    // Same circle, so a top-up does not change the row's height or its left
    // edge on the way past.
    return Container(
      width: _leadingSize,
      height: _leadingSize,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        switch (entry.transaction.type) {
          TransactionType.topUp => Icons.add_card,
          _ => Icons.tune,
        },
        size: _leadingSize * 0.5,
        color: colors.onPrimaryContainer,
      ),
    );
  }
}

/// The last few transactions, as a card for a page to drop in.
///
/// Self-contained: it owns its query, what a row tap opens, and where its
/// footer leads, all of which follow from [user] alone. Everything it shows is
/// one of the two forms [TransactionListTile] already has.
class RecentTransactionsCard extends StatefulWidget {
  const RecentTransactionsCard({super.key, this.user, this.limit = 10});

  /// Whose rows to show, or null for everyone's — which also decides the form
  /// the rows take and how the full history opens.
  final UserRow? user;

  final int limit;

  @override
  State<RecentTransactionsCard> createState() => _RecentTransactionsCardState();
}

class _RecentTransactionsCardState extends State<RecentTransactionsCard> {
  late final Stream<List<TransactionEntry>> _entries = Database.of(context)
      .transactionsDao
      .watchHistory(userId: widget.user?.id, limit: widget.limit);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              // Material's overline treatment: small, spaced and upper case, so
              // it labels the card without competing with the rows in it.
              child: Row(
                spacing: 8,
                children: [
                  Icon(
                    Icons.history,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  Text(
                    l10n.recentTransactions.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            StreamBuilder<List<TransactionEntry>>(
              stream: _entries,
              builder: (context, snapshot) {
                final entries = snapshot.data;
                // No spinner on the first frame: the query is local and a flash
                // of one reads worse than nothing.
                if (entries == null) return const SizedBox.shrink();
                if (entries.isEmpty) {
                  return Padding(
                    // A whole-screen EmptyState is far too tall for a card.
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text(
                      l10n.noTransactionsYet,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final entry in entries)
                      // Naming the user only when the card is not already
                      // about one.
                      if (widget.user == null)
                        TransactionListTile(
                          entry: entry,
                          onTap: () => unawaited(
                            showTransactionDetailDialog(context, entry: entry),
                          ),
                        )
                      else
                        TransactionListTile.forUser(
                          entry: entry,
                          onTap: () => unawaited(
                            showTransactionDetailDialog(context, entry: entry),
                          ),
                        ),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => unawaited(
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HistoryScreen(initialUser: widget.user),
                      ),
                    ),
                  ),
                  // Trailing, so it points the way on rather than back.
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  label: Text(l10n.allTransactions),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
