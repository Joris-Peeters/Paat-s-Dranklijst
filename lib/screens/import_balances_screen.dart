import 'package:flutter/material.dart';

import '../data/backups.dart';
import '../data/balance_csv.dart';
import '../data/balance_import.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import '../utils/random_emoji.dart';
import '../widgets/backup_actions.dart';
import '../widgets/palette_picker.dart';

/// Picks a balances CSV from the backup folder, previews what it would change,
/// and merges it in.
class ImportBalancesScreen extends StatelessWidget {
  const ImportBalancesScreen({super.key});

  Future<void> _import(BuildContext context, BackupFile file) async {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final db = Database.of(context);

    final BalanceImportPlan plan;
    try {
      final parsed = parseBalancesCsv(
        await readCsvText(file.file),
        decimalDigits: settings.currencyDecimalDigits,
      );
      plan = planBalanceImport(
        rows: parsed.rows,
        csvErrors: parsed.errors,
        users: await db.usersDao.readUsersWithBalances(),
        groups: await db.usersDao.readUserGroups(),
      );
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.importReadFailed)));
      return;
    }
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ImportPreviewDialog(fileName: file.name, plan: plan),
    );
    if (confirmed != true || !context.mounted) return;

    final backup = await saveBackup(context, suffix: 'before-import');
    if (backup == null) return;

    await applyBalanceImport(
      db,
      plan,
      appearance: () => (
        avatarEmoji: randomAvatarEmoji(),
        seedColorArgb: randomPaletteColor().toARGB32(),
      ),
      note: l10n.importAdjustmentNote(file.name),
    );
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.importDone(importSummary(l10n, plan)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BackupFileList(
      title: l10n.importBalances,
      extensions: csvExtensions,
      icon: Icons.table_chart_outlined,
      emptyMessage: l10n.importNoFiles,
      onOpen: (file) => _import(context, file),
    );
  }
}

/// "3 new users · 7 balances corrected · 1 new group · 28 unchanged", leaving
/// out what is zero.
String importSummary(AppLocalizations l10n, BalanceImportPlan plan) => [
  if (plan.newUsers.isNotEmpty) l10n.importNewUsersCount(plan.newUsers.length),
  if (plan.corrections.isNotEmpty)
    l10n.importCorrectionsCount(plan.corrections.length),
  if (plan.newGroups.isNotEmpty)
    l10n.importNewGroupsCount(plan.newGroups.length),
  if (plan.unchangedCount > 0) l10n.importUnchangedCount(plan.unchangedCount),
].join(' · ');

/// Every problem that blocks [plan], one line each.
List<String> importErrors(AppLocalizations l10n, BalanceImportPlan plan) => [
  for (final error in plan.csvErrors)
    switch (error.kind) {
      BalanceCsvErrorKind.empty => l10n.csvErrorEmpty,
      BalanceCsvErrorKind.missingColumn => l10n.csvErrorMissingColumn(
        error.detail ?? '',
      ),
      BalanceCsvErrorKind.unterminatedQuote => l10n.importErrorLine(
        error.line,
        l10n.csvErrorUnterminatedQuote,
      ),
      BalanceCsvErrorKind.missingField => l10n.importErrorLine(
        error.line,
        l10n.csvErrorMissingField,
      ),
      BalanceCsvErrorKind.emptyName => l10n.importErrorLine(
        error.line,
        l10n.csvErrorEmptyName,
      ),
      BalanceCsvErrorKind.emptyGroup => l10n.importErrorLine(
        error.line,
        l10n.csvErrorEmptyGroup,
      ),
      BalanceCsvErrorKind.invalidBalance => l10n.importErrorLine(
        error.line,
        l10n.csvErrorInvalidBalance(error.detail ?? ''),
      ),
    },
  for (final duplicate in plan.duplicateNames)
    l10n.importErrorDuplicateName(duplicate.name, duplicate.lines.join(', ')),
  for (final ambiguous in plan.ambiguousNames)
    l10n.importErrorAmbiguousName(
      ambiguous.line,
      ambiguous.name,
      ambiguous.groups.join(', '),
    ),
];

/// What importing a file would do. Resolves true when the admin confirms.
class ImportPreviewDialog extends StatelessWidget {
  const ImportPreviewDialog({
    super.key,
    required this.fileName,
    required this.plan,
  });

  final String fileName;
  final BalanceImportPlan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);
    final theme = Theme.of(context);
    final canImport = !plan.hasErrors && !plan.changesNothing;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return AlertDialog(
      title: Text(l10n.importPreviewTitle(fileName)),
      scrollable: true,
      content: SizedBox(
        width: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (plan.hasErrors) ...[
              Text(
                l10n.importHasErrors,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              for (final error in importErrors(l10n, plan))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $error'),
                ),
            ] else if (plan.changesNothing)
              Text(l10n.importNothingToChange)
            else ...[
              Text(importSummary(l10n, plan), style: theme.textTheme.bodyLarge),
              if (plan.newGroups.isNotEmpty) ...[
                heading(l10n.importNewGroups),
                Text(plan.newGroups.join(', ')),
              ],
              if (plan.newUsers.isNotEmpty) ...[
                heading(l10n.importNewUsers),
                for (final user in plan.newUsers)
                  _PreviewRow(
                    label: '${user.name} · ${user.group}',
                    value: settings.formatMoney(user.balanceMinorUnits),
                  ),
              ],
              if (plan.corrections.isNotEmpty) ...[
                heading(l10n.importCorrections),
                for (final correction in plan.corrections)
                  _PreviewRow(
                    label: correction.user.user.name,
                    value: l10n.importBalanceChange(
                      settings.formatMoney(correction.user.balanceMinorUnits),
                      settings.formatMoney(correction.targetMinorUnits),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Text(
                l10n.backupTakenFirst,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: canImport ? () => Navigator.pop(context, true) : null,
          child: Text(l10n.import),
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      spacing: 16,
      children: [
        Expanded(child: Text(label)),
        Text(value),
      ],
    ),
  );
}
