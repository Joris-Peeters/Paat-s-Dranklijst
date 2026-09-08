import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import '../utils/banking.dart';
import '../widgets/palette_picker.dart';
import '../widgets/pin_dialog.dart';
import '../widgets/settings_text_field.dart';

/// The first-run wizard, shown while `setupCompletedAt` is null.
///
/// Every step is optional: the schema defaults are already a working
/// configuration. Each control writes straight to the database, exactly as the
/// settings screen does — so the app re-themes and re-localizes as the choices
/// are made.
///
/// Only `setupCompletedAt` waits for the last step. An interrupted wizard
/// therefore reappears, with whatever was already chosen still in place.
class SetupWizard extends StatefulWidget {
  const SetupWizard({super.key});

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}


class _SetupWizardState extends State<SetupWizard> {
  final _pageController = PageController();
  int _step = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// The fields commit on blur, so leaving a page has to take focus with it.
  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  void _goTo(int step) {
    _unfocus();
    setState(() => _step = step);
    unawaited(
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      ),
    );
  }

  /// Marking setup complete swaps `MainApp`'s home over to the shell, so this
  /// screen is gone right after.
  ///
  /// The yield is what makes that safe: unfocusing schedules the last field's
  /// commit on a microtask, and this widget must still be alive when it runs.
  Future<void> _finish(AppSettingsData settings, WriteSettings write) async {
    _unfocus();
    await Future<void>.delayed(Duration.zero);
    write(settings.copyWith(setupCompletedAt: DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);
    final write = AppSettings.writeOf(context);

    // One list, so the step count is never hand-kept.
    final steps = <Widget>[
      _WelcomeStep(settings: settings, write: write),
      _CurrencyStep(settings: settings, write: write),
      _ColorStep(settings: settings, write: write),
      _PinStep(settings: settings, write: write),
      _PayeeStep(settings: settings, write: write),
    ];
    final isLast = _step == steps.length - 1;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) {
                  _unfocus();
                  setState(() => _step = i);
                },
                children: steps,
              ),
            ),
            _StepIndicator(step: _step, count: steps.length),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: () => _goTo(_step - 1),
                      child: Text(l10n.setupBack),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: isLast
                        ? () => unawaited(_finish(settings, write))
                        : () => _goTo(_step + 1),
                    child: Text(isLast ? l10n.setupFinish : l10n.setupNext),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == step ? colors.primary : colors.outlineVariant,
            ),
          ),
      ],
    );
  }
}

/// Shared frame for a wizard page: title, explanation, then the control.
class _Step extends StatelessWidget {
  const _Step({required this.title, required this.body, required this.child});

  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(body, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.settings, required this.write});

  final AppSettingsData settings;
  final WriteSettings write;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _Step(
      title: l10n.setupWelcomeTitle,
      body: l10n.setupWelcomeBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.language, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: settings.languageCode,
            onChanged: (code) {
              if (code != null) {
                write(settings.copyWith(languageCode: code));
              }
            },
            child: Column(
              children: [
                for (final locale in AppLocalizations.supportedLocales)
                  RadioListTile<String>(
                    value: locale.languageCode,
                    title: Text(
                      lookupAppLocalizations(Locale(locale.languageCode))
                          .languageName,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyStep extends StatelessWidget {
  const _CurrencyStep({required this.settings, required this.write});

  final AppSettingsData settings;
  final WriteSettings write;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _Step(
      title: l10n.setupCurrencyTitle,
      body: l10n.setupCurrencyBody,
      child: SettingsTextField(
        label: l10n.currency,
        value: settings.currencyCode,
        uppercase: true,
        maxLength: 3,
        validator: (value) =>
            isValidCurrencyCode(value) ? null : l10n.currencyInvalid,
        onCommit: (value) {
          if (value != null) {
            write(settings.copyWith(currencyCode: value));
          }
        },
      ),
    );
  }
}

class _ColorStep extends StatelessWidget {
  const _ColorStep({required this.settings, required this.write});

  final AppSettingsData settings;
  final WriteSettings write;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _Step(
      title: l10n.setupColorTitle,
      body: l10n.setupColorBody,
      child: Center(
        child: ColorPicker(
          selected: Color(settings.seedColorArgb),
          onSelected: (color) =>
              write(settings.copyWith(seedColorArgb: color.toARGB32())),
        ),
      ),
    );
  }
}

class _PinStep extends StatelessWidget {
  const _PinStep({required this.settings, required this.write});

  final AppSettingsData settings;
  final WriteSettings write;

  Future<void> _edit(BuildContext context) async {
    final pin = await showPinSetDialog(context);
    if (pin != null) write(settings.copyWith(adminPin: pin));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSet = settings.adminPin != null;

    return _Step(
      title: l10n.setupPinTitle,
      body: l10n.setupPinBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSet ? l10n.adminPinSet : l10n.adminPinNotSet,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => unawaited(_edit(context)),
            child: Text(isSet ? l10n.pinChange : l10n.pinSet),
          ),
        ],
      ),
    );
  }
}

class _PayeeStep extends StatelessWidget {
  const _PayeeStep({required this.settings, required this.write});

  final AppSettingsData settings;
  final WriteSettings write;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _Step(
      title: l10n.setupPayeeTitle,
      body: l10n.setupPayeeBody,
      child: Column(
        spacing: 16,
        children: [
          SettingsTextField(
            label: l10n.payeeName,
            value: settings.payeeName,
            maxLength: epcMaxNameLength,
            onCommit: (value) =>
                write(settings.copyWith(payeeName: value)),
          ),
          SettingsTextField(
            label: l10n.payeeIban,
            value: settings.payeeIban,
            uppercase: true,
            validator: (value) => isValidIban(value) ? null : l10n.ibanInvalid,
            onCommit: (value) =>
                write(settings.copyWith(payeeIban: value)),
          ),
        ],
      ),
    );
  }
}
