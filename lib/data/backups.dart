/// Backup files: where they live, how they are written, and how one is checked
/// and put in place of the live database.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'database.dart';
import 'errors.dart';

const backupExtensions = {'.sqlite', '.db'};
const csvExtensions = {'.csv'};

/// A folder the device exposes over USB, created on first use.
///
/// iOS shows the app's documents directory in Finder once file sharing is on in
/// Info.plist. Android's app-specific external directory is reachable over MTP
/// without a permission. On Linux the documents directory is the user's own, so
/// backups get a folder of their own inside it.
Future<Directory> backupDirectory() async {
  final Directory directory;
  if (Platform.isAndroid) {
    directory =
        await getExternalStorageDirectory() ??
        (throw const FileSystemException('External storage is unavailable'));
  } else if (Platform.isIOS) {
    directory = await getApplicationDocumentsDirectory();
  } else {
    final documents = await getApplicationDocumentsDirectory();
    directory = Directory('${documents.path}/Paats Dranklijst');
  }
  await directory.create(recursive: true);
  return directory;
}

/// A file in [directory] or the list of them, with what a list row shows.
class BackupFile {
  const BackupFile({
    required this.file,
    required this.name,
    required this.sizeBytes,
    required this.modified,
  });

  final File file;
  final String name;
  final int sizeBytes;
  final DateTime modified;
}

/// The files in [directory] with one of [extensions], newest first.
Future<List<BackupFile>> listFiles(
  Directory directory,
  Set<String> extensions,
) async {
  final files = <BackupFile>[];
  if (!await directory.exists()) return files;

  await for (final entity in directory.list()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    final lower = name.toLowerCase();
    if (!extensions.any(lower.endsWith)) continue;
    final stat = await entity.stat();
    files.add(
      BackupFile(
        file: entity,
        name: name,
        sizeBytes: stat.size,
        modified: stat.modified,
      ),
    );
  }
  files.sort((a, b) => b.modified.compareTo(a.modified));
  return files;
}

/// `2026-09-14_153012`: sorts by time, and has no colon for a file system to
/// refuse.
String fileTimestamp(DateTime at) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${at.year}-${two(at.month)}-${two(at.day)}_'
      '${two(at.hour)}${two(at.minute)}${two(at.second)}';
}

/// A file named [stem] in [directory], numbered when that name is taken.
Future<File> _freeFile(
  Directory directory,
  String stem,
  String extension,
) async {
  var file = File('${directory.path}/$stem$extension');
  for (var n = 2; await file.exists(); n++) {
    file = File('${directory.path}/$stem-$n$extension');
  }
  return file;
}

/// Copies the live database into [directory].
///
/// `VACUUM INTO` writes a consistent snapshot through the open connection, so
/// nothing has to be closed. It refuses to run inside a transaction.
Future<File> createBackup(
  AppDatabase db,
  Directory directory, {
  String? suffix,
  DateTime? at,
}) async {
  final stem = [
    'paats_dranklijst',
    fileTimestamp(at ?? DateTime.now()),
    ?suffix,
  ].join('_');
  final file = await _freeFile(directory, stem, '.sqlite');
  await db.customStatement('VACUUM INTO ?', [file.path]);
  return file;
}

/// Writes an exported CSV into [directory].
///
/// The byte-order mark is what makes Excel read it as UTF-8 rather than
/// mangling every accented name.
Future<File> writeCsvExport(
  Directory directory,
  String csv, {
  DateTime? at,
}) async {
  final stem = 'balances_${fileTimestamp(at ?? DateTime.now())}';
  final file = await _freeFile(directory, stem, '.csv');
  await file.writeAsString('\uFEFF$csv', flush: true);
  return file;
}

/// A CSV's text. Excel saves "CSV" in the Windows code page rather than UTF-8,
/// which Latin-1 reads close enough for names.
Future<String> readCsvText(File file) async {
  final bytes = await file.readAsBytes();
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

/// Throws [InvalidBackupException] unless [file] is a database this app can
/// open.
///
/// Attached to the live connection rather than opened on its own, which would
/// need `sqlite3` as a direct dependency. Only read, and always detached again.
Future<void> validateBackup(AppDatabase db, File file) async {
  // ATTACH creates a file that does not exist.
  if (!await file.exists()) {
    throw const InvalidBackupException(InvalidBackupReason.notADatabase);
  }

  try {
    await db.customStatement('ATTACH DATABASE ? AS backup_candidate', [
      file.path,
    ]);
  } on Object catch (e) {
    throw _unreadable(e);
  }
  try {
    final String integrity;
    try {
      final row = await db
          .customSelect('PRAGMA backup_candidate.integrity_check')
          .getSingle();
      integrity = row.data.values.first.toString();
    } on Object catch (e) {
      throw _unreadable(e);
    }
    if (integrity != 'ok') {
      throw const InvalidBackupException(InvalidBackupReason.corrupt);
    }

    // drift keeps its schema version here; an unrelated database has 0.
    final version = await db
        .customSelect('PRAGMA backup_candidate.user_version')
        .getSingle();
    final userVersion = version.read<int>('user_version');
    if (userVersion > db.schemaVersion) {
      throw const InvalidBackupException(InvalidBackupReason.newerVersion);
    }

    final tables = await db
        .customSelect(
          'SELECT name FROM backup_candidate.sqlite_master '
          "WHERE type = 'table' AND name IN ('users', 'transactions')",
        )
        .get();
    if (userVersion < 1 || tables.length != 2) {
      throw const InvalidBackupException(InvalidBackupReason.notThisApp);
    }
  } finally {
    await db.customStatement('DETACH DATABASE backup_candidate');
  }
}

/// SQLITE_NOTADB, or anything else that stops the file being read. In the app
/// the error arrives wrapped from the database isolate, so the message is all
/// there is to go on.
InvalidBackupException _unreadable(Object error) => InvalidBackupException(
  error.toString().contains('not a database')
      ? InvalidBackupReason.notADatabase
      : InvalidBackupReason.corrupt,
);

/// Puts [source] in place of the database file [target], which must be
/// closed.
///
/// Staged beside the target and renamed over it: a rename within one directory
/// is atomic, so a failure leaves the old file or the new one, never half of
/// each.
Future<void> installDatabaseFile({
  required File source,
  required File target,
}) async {
  final staged = File('${target.path}.restoring');
  await source.copy(staged.path);
  for (final suffix in const ['-journal', '-wal', '-shm']) {
    final leftover = File('${target.path}$suffix');
    if (await leftover.exists()) await leftover.delete();
  }
  await staged.rename(target.path);
}
