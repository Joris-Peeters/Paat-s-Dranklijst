import 'dart:async';

import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import '../utils/banking.dart';
import 'epc_qr_code.dart';
import 'money_text.dart';

/// The round amounts offered as presets, in whole currency units. Scaled to
/// minor units through the currency's own decimal count, never a fixed 100.
const _presets = [5, 10, 20, 50, 100];

/// Putting money on a tab: pick an amount, optionally show a payment QR, and
/// write the row only once someone says they actually paid.
///
/// A bottom sheet rather than a route: it is a task, not a place, and it has to
/// come back to whatever screen started it.
Future<void> showTopUpSheet(BuildContext context, {required UserRow user}) =>
    showModalBottomSheet<void>(
      context: context,
      // The sheet is tall and the amount field raises a keyboard, so it must be
      // free to take the height it needs.
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TopUpSheet(user: user),
    );

class TopUpSheet extends StatefulWidget {
  const TopUpSheet({super.key, required this.user});

  final UserRow user;

  @override
  State<TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<TopUpSheet> {
  late final AppDatabase _db = Database.of(context);
  late final Stream<int> _balance = _db.usersDao.watchBalance(widget.user.id);

  final _amount = TextEditingController();

  /// False is the amount page, true the QR. One sheet with two pages rather
  /// than two routes: going back has to keep what was typed, and confirming has
  /// exactly one thing to pop.
  bool _showingQr = false;

  int? get _amountMinorUnits {
    final parsed = AppSettings.of(context).parseMoney(_amount.text);
    // Zero is incomplete rather than wrong, and a negative top-up is a
    // different transaction type entirely.
    return parsed != null && parsed > 0 ? parsed : null;
  }

  /// Both are needed to build a payment code, and neither has a sensible
  /// default. Without them this is the cash case: no QR page at all, rather
  /// than a page whose only content is a grey placeholder.
  ({String name, String iban})? _payee(AppSettingsData settings) {
    final name = settings.payeeName?.trim();
    final iban = settings.payeeIban?.trim();
    if (name == null || name.isEmpty || iban == null || iban.isEmpty) {
      return null;
    }
    return (name: name, iban: iban);
  }

  void _fill(int minorUnits) => setState(
    () => _amount.text = AppSettings.of(context).formatAmount(minorUnits),
  );

  /// Writes the top-up and leaves. No undo action on the snackbar: money has
  /// changed hands, and a correction after this is an admin adjustment.
  Future<void> _commit() async {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final amount = _amountMinorUnits!;

    await _db.transactionsDao.logTopUp(
      userId: widget.user.id,
      amountMinorUnits: amount,
    );
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.topUpLogged(settings.formatMoney(amount), widget.user.name),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final payee = _payee(settings);

    return Padding(
      // Lifts the whole sheet clear of the soft keyboard, so the preview and
      // the button stay visible while the amount is being typed.
      padding: MediaQuery.viewInsetsOf(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: _showingQr && payee != null
              ? _QrPage(
                  user: widget.user,
                  payee: payee,
                  amountMinorUnits: _amountMinorUnits ?? 0,
                  onBack: () => setState(() => _showingQr = false),
                  onPaid: () => unawaited(_commit()),
                )
              : _AmountPage(
                  controller: _amount,
                  balance: _balance,
                  amountMinorUnits: _amountMinorUnits,
                  onFill: _fill,
                  onChanged: () => setState(() {}),
                  hasQr: payee != null,
                  onContinue: _amountMinorUnits == null
                      ? null
                      : payee == null
                      ? () => unawaited(_commit())
                      : () => setState(() => _showingQr = true),
                ),
        ),
      ),
    );
  }
}

class _AmountPage extends StatelessWidget {
  const _AmountPage({
    required this.controller,
    required this.balance,
    required this.amountMinorUnits,
    required this.onFill,
    required this.onChanged,
    required this.hasQr,
    required this.onContinue,
  });

  final TextEditingController controller;
  final Stream<int> balance;

  /// Null while nothing valid above zero has been entered.
  final int? amountMinorUnits;

  final ValueChanged<int> onFill;

  /// The sheet above owns the amount, so a keystroke has to reach it.
  final VoidCallback onChanged;

  /// Whether there are bank details to build a code from, which decides what
  /// the primary button is.
  final bool hasQr;

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);
    final theme = Theme.of(context);
    final typed = controller.text.trim();

    return StreamBuilder<int>(
      stream: balance,
      builder: (context, snapshot) {
        // Null until the query lands, which is not the same as a zero balance.
        final current = snapshot.data;
        final amount = amountMinorUnits;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 20,
          children: [
            Center(child: Text(l10n.topUp, style: theme.textTheme.titleLarge)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Only while they owe: there is no debt to clear otherwise, and
                // an "exactly zero" chip is a button that does nothing.
                if (current != null && current < 0)
                  _PresetChip(
                    label:
                        '${l10n.topUpDebt} ${settings.formatMoney(-current)}',
                    selected: amount == -current,
                    onSelected: () => onFill(-current),
                  ),
                for (final value in [
                  for (final preset in _presets)
                    preset * settings.minorUnitsPerMajor,
                ])
                  _PresetChip(
                    label: settings.formatMoney(value),
                    selected: amount == value,
                    onSelected: () => onFill(value),
                  ),
              ],
            ),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.amountLabel,
                prefixText: '${settings.currencySymbol} ',
                border: const OutlineInputBorder(),
                // Only once something unreadable has been typed: an empty field
                // is incomplete, not wrong.
                errorText: typed.isNotEmpty && amount == null
                    ? l10n.priceInvalid
                    : null,
              ),
              // The chips read their selection back off this field, so every
              // keystroke has to be seen.
              onChanged: (_) => onChanged(),
            ),
            _Preview(current: current, amountMinorUnits: amount),
            FilledButton.icon(
              onPressed: onContinue,
              icon: Icon(hasQr ? Icons.qr_code_2_rounded : Icons.check),
              label: Text(hasQr ? l10n.showQr : l10n.paid),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A round amount. A chip rather than a button because tapping one is a
/// selection the field can contradict — type an odd amount and the chip lets
/// go, so the two can never disagree on screen.
class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
    // Cold, wet fingers on a fridge door: a default chip is well under the
    // 48px a touch target needs.
    labelStyle: Theme.of(context).textTheme.titleMedium,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

class _Preview extends StatelessWidget {
  const _Preview({required this.current, required this.amountMinorUnits});

  /// Null until the balance query comes back.
  final int? current;

  final int? amountMinorUnits;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final balance = current ?? 0;

    return Opacity(
      // Same reason the header hides its balance until the query lands: a zero
      // standing in for an unknown balance is a wrong number, not a blank one.
      // Hidden rather than absent, so the sheet does not resize under a finger.
      opacity: current == null ? 0 : 1,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 12,
        children: [
          MoneyText(
            amountMinorUnits: balance,
            style: theme.textTheme.titleMedium,
          ),
          Icon(Icons.arrow_forward, color: theme.colorScheme.onSurfaceVariant),
          Tooltip(
            message: l10n.newBalance,
            child: MoneyText(
              amountMinorUnits: balance + (amountMinorUnits ?? 0),
              style: theme.textTheme.titleLarge,
            ),
          ),
        ],
      ),
    );
  }
}

/// The payment code, plus the same details as text.
///
/// Only reached when both bank details are set, so the code here always
/// renders — the placeholder path in [EpcQrCode] is for callers that cannot
/// know.
class _QrPage extends StatelessWidget {
  const _QrPage({
    required this.user,
    required this.payee,
    required this.amountMinorUnits,
    required this.onBack,
    required this.onPaid,
  });

  final UserRow user;
  final ({String name, String iban}) payee;
  final int amountMinorUnits;
  final VoidCallback onBack;
  final VoidCallback onPaid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);
    final theme = Theme.of(context);

    // Ends up on the payer's bank statement, so it has to say what the transfer
    // was for and for whom. Built once: the code and the typed-by-hand details
    // below it must carry the same message.
    final message = l10n.topUpQrMessage(user.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Center(child: Text(l10n.scanToPay, style: theme.textTheme.titleLarge)),
        Center(
          child: EpcQrCode(
            beneficiaryName: payee.name,
            iban: payee.iban,
            amountMinorUnits: amountMinorUnits,
            message: message,
          ),
        ),
        // A scanner that will not focus must not be a dead end, so the same
        // details are here to type by hand.
        _Detail(label: l10n.payeeName, value: payee.name),
        _Detail(label: l10n.payeeIban, value: formatIban(payee.iban)),
        _Detail(
          label: l10n.amountLabel,
          value: settings.formatMoney(amountMinorUnits),
        ),
        _Detail(label: l10n.paymentMessage, value: message),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(l10n.setupBack),
              ),
            ),
            Expanded(
              child: FilledButton.icon(
                onPressed: onPaid,
                icon: const Icon(Icons.check),
                label: Text(l10n.paid),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
