import 'dart:async';

import 'package:flutter/widgets.dart';

import 'database.dart';

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

  static AppDatabase of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_DatabaseScope>();
    assert(scope != null, 'No Database found in context');
    return scope!.database;
  }

  @override
  State<Database> createState() => _DatabaseState();
}

class _DatabaseState extends State<Database> {
  late final AppDatabase _database = widget.database ?? AppDatabase();

  @override
  void dispose() {
    if (widget.database == null) unawaited(_database.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _DatabaseScope(database: _database, child: widget.child);
}

class _DatabaseScope extends InheritedWidget {
  const _DatabaseScope({required this.database, required super.child});

  final AppDatabase database;

  @override
  bool updateShouldNotify(_DatabaseScope oldWidget) =>
      database != oldWidget.database;
}
