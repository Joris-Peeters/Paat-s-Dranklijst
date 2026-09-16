import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'backups.dart';
import 'database.dart';

/// Replaces the live database with a backup file.
typedef RestoreDatabase = Future<void> Function(File backup);

/// Owns the [AppDatabase] and publishes it to the tree.
///
/// Stateful because the connection must be opened once and closed once: a
/// StatelessWidget would open a new one on every rebuild. Mirrors the
/// `AppSettings` shape — a plain widget wrapping a private InheritedWidget.
class Database extends StatefulWidget {
  const Database({super.key, required this.child, this.database});

  final Widget child;

  /// Supplied only by tests, which hand in an in-memory database. A provided
  /// one is not closed here: whoever opened it owns its lifetime.
  final AppDatabase? database;

  static AppDatabase of(BuildContext context) => _scope(context).database;

  /// Validates a backup file, backs up the current database, and swaps the
  /// file in. Throws `InvalidBackupException` before touching
  /// anything when the file is refused.
  ///
  /// On success the whole app below this widget is rebuilt from scratch, so
  /// the caller's own context is gone by the time the future completes.
  static RestoreDatabase restoreOf(BuildContext context) =>
      _scope(context).restore;

  static _DatabaseScope _scope(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_DatabaseScope>();
    assert(scope != null, 'No Database found in context');
    return scope!;
  }

  @override
  State<Database> createState() => _DatabaseState();
}

class _DatabaseState extends State<Database> {
  late AppDatabase _database = widget.database ?? AppDatabase();

  /// Bumped on every restore. Keying the child on it makes Flutter throw the
  /// old subtree away and build a new one, so no screen keeps a stream or a
  /// reference to the closed database.
  int _generation = 0;

  /// While true the app is unmounted, so nothing queries a closing database.
  bool _swapping = false;

  Future<void> _restore(File backup) async {
    assert(widget.database == null, 'A provided database is not ours to swap');

    await validateBackup(_database, backup);
    await createBackup(
      _database,
      await backupDirectory(),
      suffix: 'before-restore',
    );
    final target = await appDatabaseFile();

    setState(() => _swapping = true);
    await WidgetsBinding.instance.endOfFrame;

    try {
      await _database.close();
      await installDatabaseFile(source: backup, target: target);
    } finally {
      // Reopened whatever happened: if the rename never ran, that is simply the
      // old file again.
      setState(() {
        _database = AppDatabase();
        _generation++;
        _swapping = false;
      });
    }
  }

  @override
  void dispose() {
    if (widget.database == null) unawaited(_database.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_swapping) {
      return const ColoredBox(color: Color(0xFF000000));
    }
    return _DatabaseScope(
      database: _database,
      restore: _restore,
      child: KeyedSubtree(key: ValueKey(_generation), child: widget.child),
    );
  }
}

class _DatabaseScope extends InheritedWidget {
  const _DatabaseScope({
    required this.database,
    required this.restore,
    required super.child,
  });

  final AppDatabase database;
  final RestoreDatabase restore;

  @override
  bool updateShouldNotify(_DatabaseScope oldWidget) =>
      database != oldWidget.database;
}
