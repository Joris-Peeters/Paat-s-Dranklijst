import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import 'money_text.dart';

/// Posts a correction to a user's balance.
///
/// An adjustment records rather than erases: the row stays, carrying its own
/// reason, and the balance moves by it. Use this for something that genuinely
/// happened off the books ("Jonas paid 10 euro cash"); use the undo in the
/// transaction dialog for a row that should never have existed.
///
/// Reads the balance once before opening, so the figure the admin does their
/// arithmetic against cannot shift under them mid-edit.
Future<void> showAdjustmentDialog(
  BuildContext context, {
  required UserRow user,
}) async {
  final balance = await Database.of(context).usersDao.readBalance(user.id);
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (_) => AdjustmentDialog(user: user, balanceMinorUnits: balance),
  );
}

class AdjustmentDialog extends StatefulWidget {
  const AdjustmentDialog({
    super.key,
    required this.user,
    required this.balanceMinorUnits,
  });

  final UserRow user;

  /// Where the balance stood when the dialog opened. Fixed for its lifetime.
  final int balanceMinorUnits;

  @override
  State<AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends State<AdjustmentDialog> {
  final _amount = TextEditingController();
  final _target = TextEditingController();
  final _note = TextEditingController();

  /// Which field the admin typed in last, so only the other one is rewritten.
  /// Setting a controller's text does not fire its own `onChanged`, so the two
  /// cannot chase each other, but the *invalid* case still has to know which
  /// of them to blame.
  bool _editingTarget = false;

  int? get _delta => AppSettings.of(context).parseMoney(_amount.text);

  /// An adjustment of nothing is a row that says nothing, so it is refused
  /// alongside an unreadable one. The note carries the whole point of the row
  /// and is required for that reason.
  bool get _canSave {
    final delta = _delta;
    return delta != null && delta != 0 && _note.text.trim().isNotEmpty;
  }

  void _syncFromAmount() {
    _editingTarget = false;
    final settings = AppSettings.of(context);
    final delta = _delta;
    _target.text = delta == null
        ? ''
        : settings.formatAmount(widget.balanceMinorUnits + delta);
    setState(() {});
  }

  void _syncFromTarget() {
    _editingTarget = true;
    final settings = AppSettings.of(context);
    final target = settings.parseMoney(_target.text);
    _amount.text = target == null
        ? ''
        : settings.formatAmount(target - widget.balanceMinorUnits);
    setState(() {});
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await Database.of(context).transactionsDao.logAdjustment(
      userId: widget.user.id,
      amountMinorUnits: _delta!,
      note: _note.text.trim(),
    );

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.adjustmentLogged(widget.user.name)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _target.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = AppSettings.of(context);

    // An error only on the field being typed in: the other one is this widget's
    // own arithmetic and is never wrong, and blanking it while a half-typed
    // amount is unreadable must not look like a mistake the admin made.
    String? errorFor({required bool target}) =>
        (target ? _target.text : _amount.text).trim().isNotEmpty &&
            _delta == null &&
            _editingTarget == target
        ? l10n.priceInvalid
        : null;

    return AlertDialog(
      title: Text(l10n.adjustment),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 20,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.currentBalance,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                MoneyText(
                  amountMinorUnits: widget.balanceMinorUnits,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            // Two ways at the same row: type what to move, or type where it
            // should land. Each rewrites the other, so whichever the admin has
            // in their head is the one they can enter.
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.amountLabel,
                prefixText: '${settings.currencySymbol} ',
                border: const OutlineInputBorder(),
                errorText: errorFor(target: false),
              ),
              onChanged: (_) => _syncFromAmount(),
            ),
            TextField(
              controller: _target,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.newBalance,
                prefixText: '${settings.currencySymbol} ',
                border: const OutlineInputBorder(),
                errorText: errorFor(target: true),
              ),
              onChanged: (_) => _syncFromTarget(),
            ),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.noteLabel,
                // Required, unlike the undo's reason: an adjustment exists to
                // record why the balance moved, and without that it is an
                // unexplained figure in the ledger forever.
                helperText: l10n.fieldRequired,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _canSave ? () => _save() : null,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
