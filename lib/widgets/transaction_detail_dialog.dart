import 'package:flutter/material.dart';

import '../data/daos/transactions_dao.dart';
import '../data/database_provider.dart';
import '../data/tables/transactions_table.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import 'money_text.dart';
import 'pin_dialog.dart';
import 'user_avatar.dart';

/// One ledger row in full, and the only way to correct it after the snackbar
/// has gone.
Future<void> showTransactionDetailDialog(
  BuildContext context, {
  required TransactionEntry entry,
}) => showDialog<void>(
  context: context,
  builder: (_) => TransactionDetailDialog(entry: entry),
);

class TransactionDetailDialog extends StatelessWidget {
  const TransactionDetailDialog({super.key, required this.entry});

  final TransactionEntry entry;

  String _typeLabel(AppLocalizations l10n) => switch (entry.transaction.type) {
    TransactionType.consumption => l10n.transactionConsumption,
    TransactionType.topUp => l10n.transactionTopUp,
    TransactionType.adjustment => l10n.transactionAdjustment,
  };

  /// Asks, then writes. The row is left alone entirely if either step is
  /// declined — there is no partial state to undo.
  Future<void> _undo(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final dao = Database.of(context).transactionsDao;

    if (!await requireAdminPin(context)) return;
    if (!context.mounted) return;

    final outcome = await showDialog<({String? note})>(
      context: context,
      builder: (_) => const _UndoReasonDialog(),
    );
    if (outcome == null) return;

    await dao.voidTransaction(entry.transaction.id, note: outcome.note);
    navigator.pop();
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
    final transaction = entry.transaction;
    final voidedAt = transaction.voidedAt;

    return AlertDialog(
      title: Text(l10n.transactionDetail),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            _Field(
              label: l10n.userLabel,
              child: Row(
                spacing: 8,
                children: [
                  UserAvatar(
                    emoji: entry.user.avatarEmoji,
                    seedColorArgb: entry.user.seedColorArgb,
                    size: 32,
                  ),
                  Flexible(child: Text(entry.user.name)),
                ],
              ),
            ),
            _Field(label: l10n.typeLabel, child: Text(_typeLabel(l10n))),
            // The frozen name and price, not the item's current ones: what was
            // paid is the record, and renaming a drink must not rewrite it.
            if (transaction.itemNameSnapshot case final name?)
              _Field(label: l10n.manageItems, child: Text(name)),
            if (transaction.itemUnitPriceSnapshot case final price?)
              _Field(
                label: l10n.unitPriceLabel,
                child: MoneyText(amountMinorUnits: price, colored: false),
              ),
            if (transaction.quantity > 1)
              _Field(
                label: l10n.quantityLabel,
                child: Text('${transaction.quantity}'),
              ),
            _Field(
              label: l10n.totalLabel,
              child: MoneyText(
                amountMinorUnits: transaction.amountMinorUnits,
                signed: true,
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (transaction.note case final note?)
              _Field(label: l10n.noteLabel, child: Text(note)),
            _Field(
              label: l10n.dateLabel,
              child: Text(settings.formatDateTime(transaction.createdAt)),
            ),
            if (voidedAt != null) ...[
              const Divider(),
              // Replaces the action rather than sitting beside it: the
              // transition is one-way, so there is nothing left to offer.
              Text(
                l10n.undoneOn(settings.formatDateTime(voidedAt)),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              if (transaction.voidedNote case final note?) Text(note),
            ],
          ],
        ),
      ),
      actions: [
        if (voidedAt == null)
          TextButton(
            onPressed: () => _undo(context),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: Text(l10n.undo),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        child,
      ],
    );
  }
}

/// Confirms the undo and collects an optional reason.
///
/// Pops a record rather than the string itself, so "dismissed" and "confirmed
/// with nothing typed" stay distinguishable — the second is a real answer.
class _UndoReasonDialog extends StatefulWidget {
  const _UndoReasonDialog();

  @override
  State<_UndoReasonDialog> createState() => _UndoReasonDialogState();
}

class _UndoReasonDialogState extends State<_UndoReasonDialog> {
  final _controller = TextEditingController();

  void _confirm() {
    final note = _controller.text.trim();
    Navigator.pop(context, (note: note.isEmpty ? null : note));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.undoReasonTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Text(l10n.undoReasonBody),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.undoReasonLabel,
              helperText: l10n.undoReasonOptional,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        // Never disabled: the reason is optional, so there is no incomplete
        // state to refuse.
        FilledButton(onPressed: _confirm, child: Text(l10n.undo)),
      ],
    );
  }
}
