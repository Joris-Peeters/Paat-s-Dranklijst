import 'dart:async';

import 'package:flutter/material.dart';

import '../data/daos/transactions_dao.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/money_text.dart';
import '../widgets/transaction_detail_dialog.dart';
import '../widgets/user_avatar.dart';

/// Top-ups whose money nobody has checked yet, oldest first, for an admin to
/// tick off against the bank statement or the cash box.
class PendingTopUpsScreen extends StatefulWidget {
  const PendingTopUpsScreen({super.key});

  @override
  State<PendingTopUpsScreen> createState() => _PendingTopUpsScreenState();
}

class _PendingTopUpsScreenState extends State<PendingTopUpsScreen> {
  late final Stream<List<TransactionEntry>> _pending = Database.of(context)
      .transactionsDao
      .watchPendingTopUps();

  /// Confirms exactly the rows on screen, after asking once for all of them.
  Future<void> _confirmAll(List<TransactionEntry> entries) async {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final dao = Database.of(context).transactionsDao;
    final ids = [for (final e in entries) e.transaction.id];
    final total = entries.fold(
      0,
      (sum, e) => sum + e.transaction.amountMinorUnits,
    );

    final confirmed = await confirmDestructive(
      context,
      title: l10n.confirmAllTopUps,
      message: l10n.confirmAllTopUpsMessage(
        ids.length,
        settings.formatMoney(total),
      ),
      confirmLabel: l10n.confirmAllTopUps,
    );
    if (!confirmed) return;

    await dao.confirmTopUps(ids);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.topUpsConfirmed(ids.length)),
        // A SnackBar with an action otherwise stays until it is tapped.
        persist: false,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => unawaited(dao.undoTopUpConfirmations(ids)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Around the whole Scaffold, so the app bar's action sees the same rows the
    // list shows.
    return StreamBuilder<List<TransactionEntry>>(
      stream: _pending,
      builder: (context, snapshot) {
        final entries = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.pendingTopUps),
            actions: [
              if (entries != null && entries.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.done_all_rounded),
                  tooltip: l10n.confirmAllTopUps,
                  onPressed: () => unawaited(_confirmAll(entries)),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: switch (entries) {
            null => const SizedBox.shrink(),
            [] => EmptyState(
              icon: Icons.task_alt_rounded,
              message: l10n.noPendingTopUps,
            ),
            _ => ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              itemBuilder: (context, index) => _PendingRow(
                key: ValueKey(entries[index].transaction.id),
                entry: entries[index],
              ),
            ),
          },
        );
      },
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({super.key, required this.entry});

  final TransactionEntry entry;

  Future<void> _confirm(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final dao = Database.of(context).transactionsDao;
    final id = entry.transaction.id;

    await dao.confirmTopUp(id);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.topUpConfirmed(
            settings.formatMoney(entry.transaction.amountMinorUnits),
            entry.user.name,
          ),
        ),
        // A SnackBar with an action otherwise stays until it is tapped.
        persist: false,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => unawaited(dao.undoTopUpConfirmation(id)),
        ),
      ),
    );
  }

  /// The money never came, so the credit goes: an ordinary void, with the
  /// same optional reason the detail dialog asks for.
  Future<void> _void(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final dao = Database.of(context).transactionsDao;

    final outcome = await showUndoReasonDialog(context);
    if (outcome == null) return;

    await dao.voidTransaction(entry.transaction.id, note: outcome.note);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.transactionUndone),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = AppSettings.of(context);
    final user = entry.user;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        leading: UserAvatar(
          emoji: user.avatarEmoji,
          seedColorArgb: user.seedColorArgb,
          size: 40,
        ),
        title: Text(user.name),
        subtitle: Text(settings.formatDateTime(entry.transaction.createdAt)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            MoneyText(
              amountMinorUnits: entry.transaction.amountMinorUnits,
              style: theme.textTheme.titleMedium,
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              color: theme.colorScheme.error,
              tooltip: l10n.voidTopUp,
              onPressed: () => unawaited(_void(context)),
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.check_rounded),
              tooltip: l10n.confirmTopUp,
              onPressed: () => unawaited(_confirm(context)),
            ),
          ],
        ),
      ),
    );
  }
}
