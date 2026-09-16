import 'package:flutter/material.dart';

import '../data/backups.dart';
import '../data/database_provider.dart';
import '../data/errors.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import '../widgets/backup_actions.dart';
import '../widgets/confirm_dialog.dart';

/// Picks a backup from the backup folder and puts it in place of the database.
class RestoreBackupScreen extends StatelessWidget {
  const RestoreBackupScreen({super.key});

  Future<void> _restore(BuildContext context, BackupFile file) async {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final restore = Database.restoreOf(context);

    final confirmed = await confirmDestructive(
      context,
      title: l10n.restoreConfirmTitle,
      message:
          '${l10n.restoreConfirmMessage(file.name, settings.formatDateTime(file.modified))}'
          '\n\n${l10n.backupTakenFirst}',
      confirmLabel: l10n.restore,
    );
    if (!confirmed) return;

    try {
      // On success the app is rebuilt from scratch and lands on Start, so
      // nothing after this line runs against a live screen.
      await restore(file.file);
    } on InvalidBackupException catch (e) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.invalidBackupTitle),
          content: Text(switch (e.reason) {
            InvalidBackupReason.notADatabase => l10n.invalidBackupNotADatabase,
            InvalidBackupReason.corrupt => l10n.invalidBackupCorrupt,
            InvalidBackupReason.newerVersion => l10n.invalidBackupNewerVersion,
            InvalidBackupReason.notThisApp => l10n.invalidBackupNotThisApp,
          }),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
    } on Object {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.restoreFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BackupFileList(
      title: l10n.restoreBackup,
      extensions: backupExtensions,
      icon: Icons.inventory_2_outlined,
      emptyMessage: l10n.restoreNoBackups,
      onOpen: (file) => _restore(context, file),
    );
  }
}
