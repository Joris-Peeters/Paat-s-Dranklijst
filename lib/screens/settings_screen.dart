import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../data/database.dart';
import '../data/database_provider.dart';
import '../data/tables/settings_table.dart';
import '../l10n/app_localizations.dart';
import '../utils/banking.dart';
import '../widgets/palette_picker.dart';
import '../widgets/pin_dialog.dart';
import '../widgets/settings_text_field.dart';
import 'management_screens.dart';

/// Opens the settings screen, asking for the admin PIN first when one is set.
Future<void> openSettings(BuildContext context) async {
  final pin = AppSettings.of(context).adminPin;

  if (pin != null) {
    final unlocked = await showDialog<bool>(
      context: context,
      builder: (_) => PinEnterDialog(expectedPin: pin),
    );
    if (unlocked != true) return;
  }

  if (!context.mounted) return;
  await Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => const SettingsScreen()),
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);
    final dao = Database.of(context).settingsDao;

    // Every control writes straight to the database; the settings stream
    // rebuilds the whole app, so there is no save button and no restart.
    // Fire-and-forget: the UI reacts to the stream, not to this future.
    void write(SettingsCompanion changes) =>
        unawaited(dao.updateSettings(changes));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _SectionHeader(title: l10n.sectionManagement),
          ..._managementCards(context, l10n),

          const Divider(height: 24, indent: 16, endIndent: 16),

          _SectionHeader(title: l10n.sectionAppearance),
          _AppearanceCard(settings: settings, write: write),

          _SectionHeader(title: l10n.sectionAdmin),
          _AdminCard(settings: settings, write: write),

          _SectionHeader(title: l10n.sectionSettlingUp),
          _PayeeCard(settings: settings, write: write),

          _SectionHeader(title: l10n.sectionAbout),
          const _AboutCard(),
        ],
      ),
    );
  }

  /// One record per management area — a fourth is one more entry here.
  List<Widget> _managementCards(BuildContext context, AppLocalizations l10n) {
    final areas =
        <({IconData icon, String title, String subtitle, String empty})>[
          (
            icon: Icons.people_rounded,
            title: l10n.manageMembers,
            subtitle: l10n.manageMembersSubtitle,
            empty: l10n.noMembersYet,
          ),
          (
            icon: Icons.groups_rounded,
            title: l10n.manageGroups,
            subtitle: l10n.manageGroupsSubtitle,
            empty: l10n.noGroupsYet,
          ),
          (
            icon: Icons.local_cafe,
            title: l10n.manageItems,
            subtitle: l10n.manageItemsSubtitle,
            empty: l10n.noItemsYet,
          ),
        ];

    return [
      for (final area in areas)
        Card(
          margin: _cardMargin,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            leading: Icon(area.icon, size: 32),
            title: Text(area.title),
            subtitle: Text(area.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => ManagementStubScreen(
                  title: area.title,
                  icon: area.icon,
                  emptyMessage: area.empty,
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

typedef _Write = void Function(SettingsCompanion changes);

const _cardMargin = EdgeInsets.symmetric(horizontal: 16, vertical: 4);

/// A section heading above a group of settings.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Explanatory text belonging to a whole group rather than to one control.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// The surface one group of settings sits on. Shared so the three groups keep
/// the same metrics as the management cards above them.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card.filled(
    margin: _cardMargin,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: children,
      ),
    ),
  );
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({required this.settings, required this.write});

  final SettingsRow settings;
  final _Write write;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _SettingsCard(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.themeColor),
          trailing: ColorPicker(
            selected: Color(settings.seedColorArgb),
            onSelected: (color) => write(
              SettingsCompanion(seedColorArgb: Value(color.toARGB32())),
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.themeMode),
          trailing: SegmentedButton<AppThemeMode>(
            selected: {settings.themeMode},
            onSelectionChanged: (selection) =>
                write(SettingsCompanion(themeMode: Value(selection.first))),
            segments: [
              ButtonSegment(
                value: AppThemeMode.light,
                icon: const Icon(Icons.light_mode),
                label: Text(l10n.themeModeLight),
              ),
              ButtonSegment(
                value: AppThemeMode.dark,
                icon: const Icon(Icons.dark_mode),
                label: Text(l10n.themeModeDark),
              ),
              ButtonSegment(
                value: AppThemeMode.scheduled,
                icon: const Icon(Icons.schedule),
                label: Text(l10n.themeModeScheduled),
              ),
            ],
          ),
        ),
        if (settings.themeMode == AppThemeMode.scheduled)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Row(
                spacing: 16,
                children: [
                  Expanded(
                    child: _TimeField(
                      label: l10n.darkStart,
                      icon: Icons.bedtime_outlined,
                      time: settings.darkStart,
                      onPicked: (time) =>
                          write(SettingsCompanion(darkStart: Value(time))),
                    ),
                  ),
                  Expanded(
                    child: _TimeField(
                      label: l10n.darkEnd,
                      icon: Icons.wb_sunny_outlined,
                      time: settings.darkEnd,
                      onPicked: (time) =>
                          write(SettingsCompanion(darkEnd: Value(time))),
                    ),
                  ),
                ],
              ),
              _Note(
                l10n.darkSchedulePreview(
                  settings.darkStart.format(context),
                  settings.darkEnd.format(context),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// A tappable outlined field showing one time, opening the time picker.
class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.icon,
    required this.time,
    required this.onPicked,
  });

  final String label;
  final IconData icon;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onPicked;

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(context: context, initialTime: time);
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) => _ReadOnlyField(
    value: time.format(context),
    onTap: () => unawaited(_pick(context)),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: const OutlineInputBorder(),
    ),
  );
}

/// A field that only ever *displays* a value — tapping it opens a picker.
///
/// A real `TextField` rather than a tapped `InputDecorator`, because only the
/// field itself gets the hover and focus states a field should have. `readOnly`
/// keeps the picker the only way in, and stops a soft keyboard appearing.
///
/// The controller is owned here and re-synced in `didUpdateWidget`, since every
/// settings write rebuilds this screen with a fresh value to display.
class _ReadOnlyField extends StatefulWidget {
  const _ReadOnlyField({
    required this.value,
    required this.decoration,
    required this.onTap,
  });

  final String value;
  final InputDecoration decoration;
  final VoidCallback onTap;

  @override
  State<_ReadOnlyField> createState() => _ReadOnlyFieldState();
}

class _ReadOnlyFieldState extends State<_ReadOnlyField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(_ReadOnlyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    readOnly: true,
    showCursor: false,
    enableInteractiveSelection: false,
    onTap: widget.onTap,
    decoration: widget.decoration,
  );
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.settings, required this.write});

  final SettingsRow settings;
  final _Write write;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selfRegistration = settings.allowSelfRegistration;

    return _SettingsCard(
      children: [
        Row(
          // Tops, not centres: the PIN field is taller by its helper text, and
          // it is the two outlined boxes that should line up.
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Expanded(
              child: _AdminPinField(settings: settings, write: write),
            ),
            Expanded(
              child: _LanguageField(settings: settings, write: write),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.allowSelfRegistration),
          subtitle: Text(
            selfRegistration
                ? l10n.allowSelfRegistrationOn
                : l10n.allowSelfRegistrationOff,
          ),
          value: selfRegistration,
          onChanged: (value) =>
              write(SettingsCompanion(allowSelfRegistration: Value(value))),
        ),
        // A three-letter code does not want the full card width.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: 200,
            child: SettingsTextField(
              label: l10n.currency,
              value: settings.currencyCode,
              uppercase: true,
              maxLength: 3,
              validator: (value) =>
                  isValidCurrencyCode(value) ? null : l10n.currencyInvalid,
              onCommit: (value) {
                if (value != null) {
                  write(SettingsCompanion(currencyCode: Value(value)));
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows whether a PIN is set, and offers the only two things that can be done
/// with one: edit and delete
class _AdminPinField extends StatelessWidget {
  const _AdminPinField({required this.settings, required this.write});

  final SettingsRow settings;
  final _Write write;

  Future<void> _edit(BuildContext context) async {
    final pin = await showPinSetDialog(context);
    if (pin != null) write(SettingsCompanion(adminPin: Value(pin)));
  }

  Future<void> _remove(BuildContext context) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pinRemove),
        content: Text(l10n.pinRemoveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      write(const SettingsCompanion(adminPin: Value(null)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSet = settings.adminPin != null;

    return _ReadOnlyField(
      value: isSet ? List.filled(pinLength, '●').join(' ') : '',
      onTap: () => unawaited(_edit(context)),
      decoration: InputDecoration(
        labelText: l10n.adminPin,
        helperText: isSet ? l10n.adminPinSet : l10n.adminPinNotSet,
        // Two sentences' worth of helper in half a card's width; one line
        // would ellipsize it away.
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: isSet ? l10n.pinChange : l10n.pinSet,
              onPressed: () => unawaited(_edit(context)),
            ),
            if (isSet)
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: l10n.pinRemove,
                onPressed: () => unawaited(_remove(context)),
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageField extends StatelessWidget {
  const _LanguageField({required this.settings, required this.write});

  final SettingsRow settings;
  final _Write write;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DropdownMenu<String>(
      initialSelection: settings.languageCode,
      label: Text(l10n.language),
      leadingIcon: const Icon(Icons.language),
      expandedInsets: EdgeInsets.zero,
      inputDecorationTheme: const InputDecorationThemeData(
        border: OutlineInputBorder(),
      ),
      onSelected: (code) {
        if (code != null) {
          write(SettingsCompanion(languageCode: Value(code)));
        }
      },
      // Straight from the ARB files via gen-l10n — no hand-kept list to fall
      // out of sync. Each language is named in its own language.
      dropdownMenuEntries: [
        for (final locale in AppLocalizations.supportedLocales)
          DropdownMenuEntry(
            value: locale.languageCode,
            label: lookupAppLocalizations(Locale(locale.languageCode))
                .languageName,
          ),
      ],
    );
  }
}

class _PayeeCard extends StatelessWidget {
  const _PayeeCard({required this.settings, required this.write});

  final SettingsRow settings;
  final _Write write;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _SettingsCard(
      children: [
        // The explanation covers both fields, so it is the card's note rather
        // than one field's helper text.
        _Note(l10n.payeeHelp),
        SettingsTextField(
          label: l10n.payeeName,
          value: settings.payeeName,
          maxLength: epcMaxNameLength,
          onCommit: (value) =>
              write(SettingsCompanion(payeeName: Value(value))),
        ),
        SettingsTextField(
          label: l10n.payeeIban,
          value: settings.payeeIban,
          uppercase: true,
          validator: (value) => isValidIban(value) ? null : l10n.ibanInvalid,
          onCommit: (value) =>
              write(SettingsCompanion(payeeIban: Value(value))),
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _SettingsCard(
      children: [
        _Note(l10n.aboutLicensesHelp),
        // Flutter's own page, localized by MaterialLocalizations. It lists
        // every package plus the emoji font registered in main().
        OutlinedButton.icon(
          icon: const Icon(Icons.description_outlined),
          label: Text(l10n.aboutLicenses),
          onPressed: () =>
              showLicensePage(context: context, applicationName: l10n.appTitle),
        ),
      ],
    );
  }
}
