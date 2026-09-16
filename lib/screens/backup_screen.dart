import 'dart:async';

import 'package:flutter/material.dart';

import '../data/backups.dart';
import '../l10n/app_localizations.dart';
import '../widgets/backup_actions.dart';
import '../widgets/card_heading.dart';

/// Making a backup from the Start page, with no PIN: a copy harms nothing, and
/// whoever is at the fridge before the tablet goes home should be able to take
/// one.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  static const _recentCount = 5;

  late Future<List<BackupFile>> _recent = _loadRecent();
  bool _saving = false;

  Future<List<BackupFile>> _loadRecent() async =>
      listFiles(await backupDirectory(), backupExtensions);

  Future<void> _save() async {
    setState(() => _saving = true);
    await saveBackup(context);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _recent = _loadRecent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backups)),
      // A list of cards, so the balances QR code can join as another one.
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  FilledButton.icon(
                    onPressed: _saving ? null : () => unawaited(_save()),
                    icon: const Icon(Icons.save_rounded, size: 32),
                    label: Text(
                      l10n.makeBackup,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: _saving ? null : theme.colorScheme.onPrimary,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(96),
                    ),
                  ),
                  const BackupFolderNote(),
                ],
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CardHeading(
                    icon: Icons.history_rounded,
                    label: l10n.recentBackups,
                  ),
                  FutureBuilder<List<BackupFile>>(
                    future: _recent,
                    builder: (context, snapshot) {
                      final files = snapshot.data;
                      if (files == null) return const SizedBox(height: 48);
                      if (files.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(l10n.noBackups),
                        );
                      }
                      return Column(
                        children: [
                          for (final file in files.take(_recentCount))
                            ListTile(
                              leading: const Icon(Icons.inventory_2_outlined),
                              title: Text(file.name),
                              subtitle: Text(fileDetails(context, file)),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
