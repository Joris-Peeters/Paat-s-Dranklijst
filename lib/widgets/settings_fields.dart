import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import '../utils/banking.dart';
import 'pin_dialog.dart';
import 'settings_text_field.dart';

/// The settings controls the settings screen and the first-run wizard both
/// show, so their validation and limits are decided once.

/// Asks for a new PIN and stores it. A dismissed dialog changes nothing.
Future<void> editAdminPin(
  BuildContext context,
  AppSettingsData settings,
  WriteSettings write,
) async {
  final pin = await showPinSetDialog(context);
  if (pin != null) write(settings.copyWith(adminPin: pin));
}

class CurrencyField extends StatelessWidget {
  const CurrencyField({super.key, required this.settings, required this.write});

  final AppSettingsData settings;
  final WriteSettings write;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SettingsTextField(
      label: l10n.currency,
      value: settings.currencyCode,
      uppercase: true,
      maxLength: 3,
      validator: (value) =>
          isValidCurrencyCode(value) ? null : l10n.currencyInvalid,
      // Unlike the payee fields, this one has no empty state: clearing it
      // leaves the currency as it was.
      onCommit: (value) {
        if (value != null) write(settings.copyWith(currencyCode: value));
      },
    );
  }
}

class PayeeNameField extends StatelessWidget {
  const PayeeNameField({
    super.key,
    required this.settings,
    required this.write,
  });

  final AppSettingsData settings;
  final WriteSettings write;

  @override
  Widget build(BuildContext context) => SettingsTextField(
    label: AppLocalizations.of(context).payeeName,
    value: settings.payeeName,
    textCapitalization: TextCapitalization.words,
    maxLength: epcMaxNameLength,
    onCommit: (value) => write(settings.copyWith(payeeName: value)),
  );
}

class PayeeIbanField extends StatelessWidget {
  const PayeeIbanField({
    super.key,
    required this.settings,
    required this.write,
  });

  final AppSettingsData settings;
  final WriteSettings write;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SettingsTextField(
      label: l10n.payeeIban,
      value: settings.payeeIban,
      uppercase: true,
      validator: (value) => isValidIban(value) ? null : l10n.ibanInvalid,
      onCommit: (value) => write(settings.copyWith(payeeIban: value)),
    );
  }
}
