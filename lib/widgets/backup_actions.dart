import 'dart:io';

import 'package:flutter/material.dart';

import '../data/backups.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';

/// Saves a backup and says so in a snackbar. Returns the file, or null after
/// telling the user it failed.
///
/// [suffix] marks a backup taken automatically before something destructive,
/// and then the success snackbar is left to the caller, which has more to say.
Future<File?> saveBackup(BuildContext context, {String? suffix}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final db = Database.of(context);

  try {
    final file = await createBackup(
      db,
      await backupDirectory(),
      suffix: suffix,
    );
    if (suffix == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.backupSaved(fileName(file)))),
      );
    }
    return file;
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.backupFailed)));
    return null;
  }
}

String fileName(File file) => file.uri.pathSegments.last;

/// When a file was last changed and how big it is.
String fileDetails(BuildContext context, BackupFile file) =>
    AppLocalizations.of(context).fileDetails(
      AppSettings.of(context).formatDateTime(file.modified),
      (file.sizeBytes / 1024).ceil(),
    );

/// Where backups go, and how to get at them from a computer.
///
/// The path is left out on iOS: it is a sandbox path nobody can use, and
/// Finder shows the folder under the app's name instead.
class BackupFolderNote extends StatefulWidget {
  const BackupFolderNote({super.key});

  @override
  State<BackupFolderNote> createState() => _BackupFolderNoteState();
}

class _BackupFolderNoteState extends State<BackupFolderNote> {
  final Future<Directory> _directory = backupDirectory();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(l10n.backupFolder, style: theme.textTheme.titleSmall),
        Text(
          Platform.isIOS
              ? l10n.backupFolderHintIos
              : Platform.isAndroid
              ? l10n.backupFolderHintAndroid
              : l10n.backupFolderHintDesktop,
          style: muted,
        ),
        if (!Platform.isIOS)
          FutureBuilder<Directory>(
            future: _directory,
            builder: (context, snapshot) => SelectableText(
              snapshot.data?.path ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
      ],
    );
  }
}

/// The files of one kind in the backup folder, re-read on demand.
///
/// Shared by the restore and import screens, which differ only in what a tap
/// on a file does.
class BackupFileList extends StatefulWidget {
  const BackupFileList({
    super.key,
    required this.title,
    required this.extensions,
    required this.icon,
    required this.emptyMessage,
    required this.onOpen,
  });

  final String title;
  final Set<String> extensions;
  final IconData icon;
  final String emptyMessage;
  final Future<void> Function(BackupFile file) onOpen;

  @override
  State<BackupFileList> createState() => _BackupFileListState();
}

class _BackupFileListState extends State<BackupFileList> {
  late Future<List<BackupFile>> _files = _load();

  Future<List<BackupFile>> _load() async =>
      listFiles(await backupDirectory(), widget.extensions);

  void _reload() => setState(() => _files = _load());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.refresh,
            onPressed: _reload,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<BackupFile>>(
        future: _files,
        builder: (context, snapshot) {
          final files = snapshot.data;
          if (files == null) return const SizedBox.shrink();

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: BackupFolderNote(),
              ),
              if (files.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(widget.emptyMessage, textAlign: TextAlign.center),
                ),
              for (final file in files)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Icon(widget.icon, size: 32),
                  title: Text(file.name),
                  subtitle: Text(fileDetails(context, file)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await widget.onOpen(file);
                    if (mounted) _reload();
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
