import 'package:drift/drift.dart';

/// A category of items (Drinks, snacks, ...).
@DataClassName('ItemGroupRow')
class ItemGroups extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get emoji => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
