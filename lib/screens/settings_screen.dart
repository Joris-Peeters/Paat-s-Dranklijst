import 'dart:async';

import 'package:flutter/material.dart';

import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/palette_picker.dart';
import '../widgets/pin_dialog.dart';
import '../widgets/settings_fields.dart';
import 'item_categories_screen.dart';
import 'user_groups_screen.dart';

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
    // Every control writes on the tap and the whole app re-themes, so there is
    // no save button and no restart.
    final write = AppSettings.writeOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _SectionHeader(title: l10n.sectionManagement),
          const _UserGroupsCard(),
          const _ItemCategoriesCard(),

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
}

const _cardMargin = EdgeInsets.symmetric(horizontal: 16, vertical: 4);

/// A management area, with live counts under its name.
///
/// Falls back to the static description until the query resolves, so the
/// subtitle never flashes empty.
class _ManagementCard extends StatelessWidget {
  const _ManagementCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.counts,
    required this.open,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Stream<String> counts;
  final Widget Function() open;

  @override
  Widget build(BuildContext context) => Card(
    margin: _cardMargin,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Icon(icon, size: 32),
      title: Text(title),
      subtitle: StreamBuilder<String>(
        stream: counts,
        builder: (context, snapshot) => Text(snapshot.data ?? subtitle),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => open()),
      ),
    ),
  );
}

class _UserGroupsCard extends StatefulWidget {
  const _UserGroupsCard();

  @override
  State<_UserGroupsCard> createState() => _UserGroupsCardState();
}

class _UserGroupsCardState extends State<_UserGroupsCard> {
  // Built once: `Database.of` depends on an inherited widget, so it cannot run
  // in initState, and rebuilding it in build would resubscribe every frame.
  late final Stream<({int groups, int members})> _counts = Database.of(context)
      .usersDao
      .watchUserGroupsWithUsage()
      .map(
        (rows) => (
          groups: rows.length,
          // Archived members included: the point of the number is how much the
          // group holds, and an archived row weighs the same here.
          members: rows.fold(0, (sum, row) => sum + row.usage.total),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _ManagementCard(
      icon: Icons.groups_rounded,
      title: l10n.userGroups,
      subtitle: l10n.userGroupsSubtitle,
      counts: _counts.map(
        (counts) => l10n.userGroupsSummary(counts.groups, counts.members),
      ),
      open: UserGroupsScreen.new,
    );
  }
}

class _ItemCategoriesCard extends StatefulWidget {
  const _ItemCategoriesCard();

  @override
  State<_ItemCategoriesCard> createState() => _ItemCategoriesCardState();
}

class _ItemCategoriesCardState extends State<_ItemCategoriesCard> {
  late final Stream<({int categories, int items})> _counts =
      Database.of(context).itemsDao.watchItemGroupsWithUsage().map(
        (rows) => (
          categories: rows.length,
          items: rows.fold(0, (sum, row) => sum + row.usage.total),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _ManagementCard(
      icon: Icons.category_rounded,
      title: l10n.itemCategories,
      subtitle: l10n.itemCategoriesSubtitle,
      counts: _counts.map(
        (counts) => l10n.itemCategoriesSummary(counts.categories, counts.items),
      ),
      open: ItemCategoriesScreen.new,
    );
  }
}

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

  final AppSettingsData settings;
  final WriteSettings write;

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
            onSelected: (color) =>
                write(settings.copyWith(seedColorArgb: color.toARGB32())),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.themeMode),
          trailing: SegmentedButton<AppThemeMode>(
            selected: {settings.themeMode},
            onSelectionChanged: (selection) =>
                write(settings.copyWith(themeMode: selection.first)),
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
                          write(settings.copyWith(darkStart: time)),
                    ),
                  ),
                  Expanded(
                    child: _TimeField(
                      label: l10n.darkEnd,
                      icon: Icons.wb_sunny_outlined,
                      time: settings.darkEnd,
                      onPicked: (time) =>
                          write(settings.copyWith(darkEnd: time)),
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

  final AppSettingsData settings;
  final WriteSettings write;

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
              write(settings.copyWith(allowSelfRegistration: value)),
        ),
        // A three-letter code does not want the full card width.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: 200,
            child: CurrencyField(settings: settings, write: write),
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

  final AppSettingsData settings;
  final WriteSettings write;

  Future<void> _remove(BuildContext context) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await confirmDestructive(
      context,
      title: l10n.pinRemove,
      message: l10n.pinRemoveConfirm,
      confirmLabel: l10n.remove,
    );

    if (confirmed) {
      write(settings.copyWith(adminPin: null));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSet = settings.adminPin != null;

    return _ReadOnlyField(
      value: isSet ? List.filled(pinLength, '●').join(' ') : '',
      onTap: () => unawaited(editAdminPin(context, settings, write)),
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
              onPressed: () =>
                  unawaited(editAdminPin(context, settings, write)),
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

  final AppSettingsData settings;
  final WriteSettings write;

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
          write(settings.copyWith(languageCode: code));
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

  final AppSettingsData settings;
  final WriteSettings write;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _SettingsCard(
      children: [
        // The explanation covers both fields, so it is the card's note rather
        // than one field's helper text.
        _Note(l10n.payeeHelp),
        PayeeNameField(settings: settings, write: write),
        PayeeIbanField(settings: settings, write: write),
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
        // the licence of every package we depend on.
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
