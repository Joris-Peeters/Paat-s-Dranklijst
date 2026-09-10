import 'package:drift/drift.dart';

import '../database.dart';
import '../errors.dart';
import '../group_usage.dart';
import '../tables/item_groups_table.dart';
import '../tables/items_table.dart';

part 'items_dao.g.dart';

/// A category with how many items it holds, both halves counted.
class ItemGroupWithUsage {
  const ItemGroupWithUsage({required this.group, required this.usage});

  final ItemGroupRow group;
  final GroupUsage usage;
}

/// Queries against drinks and the categories they belong to.
///
/// Mirrors [UsersDao], minus the balance: an item holds no money, so archiving
/// one needs no guard.
@DriftAccessor(tables: [Items, ItemGroups])
class ItemsDao extends DatabaseAccessor<AppDatabase> with _$ItemsDaoMixin {
  ItemsDao(super.db);

  Stream<List<ItemGroupRow>> watchItemGroups() => (select(
    itemGroups,
  )..orderBy([(g) => OrderingTerm(expression: g.sortOrder)])).watch();

  /// Every item, in category order then its place inside it. The join is what
  /// makes the order meaningful: `sortOrder` is only unique within a category,
  /// so several items legitimately share a 0.
  Stream<List<ItemRow>> watchItems({bool includeArchived = false}) {
    final query = select(items)
        .join([innerJoin(itemGroups, itemGroups.id.equalsExp(items.groupId))]);
    if (!includeArchived) {
      query.where(items.archivedAt.isNull());
    }
    query.orderBy([
      OrderingTerm(expression: itemGroups.sortOrder),
      OrderingTerm(expression: items.sortOrder),
    ]);
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(items)).toList(),
    );
  }

  /// One category's items. Needs no join: inside a single category the item's
  /// own [Items.sortOrder] is the whole order.
  Stream<List<ItemRow>> watchItemsInGroup(
    int groupId, {
    bool includeArchived = false,
  }) {
    final query = select(items)
      ..where((i) => i.groupId.equals(groupId))
      ..orderBy([(i) => OrderingTerm(expression: i.sortOrder)]);
    if (!includeArchived) {
      query.where((i) => i.archivedAt.isNull());
    }
    return query.watch();
  }

  /// Categories with their item counts, in one query rather than a count per
  /// row. Left-joined so an empty category still appears — an empty one is the
  /// only kind that can be deleted.
  Stream<List<ItemGroupWithUsage>> watchItemGroupsWithUsage() {
    final active = items.id.count(filter: items.archivedAt.isNull());
    final archived = items.id.count(filter: items.archivedAt.isNotNull());
    final query =
        select(
            itemGroups,
          ).join([leftOuterJoin(items, items.groupId.equalsExp(itemGroups.id))])
          ..addColumns([active, archived])
          ..groupBy([itemGroups.id])
          ..orderBy([OrderingTerm(expression: itemGroups.sortOrder)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ItemGroupWithUsage(
              group: row.readTable(itemGroups),
              usage: GroupUsage(
                activeCount: row.read(active) ?? 0,
                archivedCount: row.read(archived) ?? 0,
              ),
            ),
          )
          .toList(),
    );
  }

  Future<int> createItem({
    required String name,
    required int groupId,
    required int priceMinorUnits,
    required String emoji,
  }) => transaction(() async {
    final order = await _nextSortOrder(groupId);
    return into(items).insert(
      ItemsCompanion.insert(
        name: name,
        groupId: groupId,
        priceMinorUnits: priceMinorUnits,
        emoji: emoji,
        sortOrder: Value(order),
      ),
    );
  });

  Future<void> updateItem(int id, ItemsCompanion changes) async {
    await (update(items)..where((i) => i.id.equals(id))).write(changes);
  }

  /// Everything the edit dialog can change, in one transaction. Mirrors
  /// [UsersDao.updateUserDetails], minus the balance guard.
  Future<void> updateItemDetails({
    required int id,
    required String name,
    required String emoji,
    required int priceMinorUnits,
    required int groupId,
  }) => transaction(() async {
    final current = await (select(
      items,
    )..where((i) => i.id.equals(id))).getSingleOrNull();
    if (current == null) return;

    final moved = current.groupId != groupId;
    await (update(items)..where((i) => i.id.equals(id))).write(
      ItemsCompanion(
        name: Value(name),
        emoji: Value(emoji),
        priceMinorUnits: Value(priceMinorUnits),
        groupId: Value(groupId),
        // Untouched unless the category changed: repricing must not reshuffle
        // the list the admin is looking at.
        sortOrder: moved
            ? Value(await _nextSortOrder(groupId))
            : const Value.absent(),
      ),
    );
    if (moved) await _renumberGroup(current.groupId);
  });

  /// Closes the gaps a departure left, so one category's numbers stay 0..n-1.
  Future<void> _renumberGroup(int groupId) async {
    final rows =
        await (select(items)
              ..where((i) => i.groupId.equals(groupId))
              ..orderBy([(i) => OrderingTerm(expression: i.sortOrder)]))
            .get();
    for (var i = 0; i < rows.length; i++) {
      await (update(items)..where((t) => t.id.equals(rows[i].id))).write(
        ItemsCompanion(sortOrder: Value(i)),
      );
    }
  }

  /// Soft delete: a discontinued drink stays referenced by the ledger.
  Future<void> archiveItem(int id) async {
    await (update(items)..where((i) => i.id.equals(id))).write(
      ItemsCompanion(archivedAt: Value(DateTime.now())),
    );
  }

  /// Lands the item last in its category rather than back on its old number: a
  /// reorder while it was archived renumbered everything else, so the position
  /// it left with is very likely taken.
  Future<void> restoreItem(int id) => transaction(() async {
    final item = await (select(
      items,
    )..where((i) => i.id.equals(id))).getSingleOrNull();
    if (item == null) return;
    await (update(items)..where((i) => i.id.equals(id))).write(
      ItemsCompanion(
        archivedAt: const Value(null),
        sortOrder: Value(await _nextSortOrder(item.groupId)),
      ),
    );
  });

  Future<int> createItemGroup({required String name, String? emoji}) =>
      transaction(() async {
        final order = await _nextGroupSortOrder();
        return into(itemGroups).insert(
          ItemGroupsCompanion.insert(
            name: name,
            emoji: Value(emoji),
            sortOrder: Value(order),
          ),
        );
      });

  Future<ItemGroupRow?> readItemGroup(int id) =>
      (select(itemGroups)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<void> updateItemGroup(int id, ItemGroupsCompanion changes) async {
    await (update(itemGroups)..where((g) => g.id.equals(id))).write(changes);
  }

  /// Hard delete, allowed only while unreferenced. The count and the delete
  /// share this transaction so the check cannot go stale.
  Future<void> deleteItemGroup(int id) => transaction(() async {
    final usage = await itemGroupUsage(id);
    if (usage.total > 0) {
      throw GroupInUseException(
        groupId: id,
        activeCount: usage.activeCount,
        archivedCount: usage.archivedCount,
      );
    }
    await (delete(itemGroups)..where((g) => g.id.equals(id))).go();
  });

  Future<GroupUsage> itemGroupUsage(int groupId) async {
    Future<int> countWhere(Expression<bool> predicate) async {
      final count = countAll();
      final row =
          await (selectOnly(items)
                ..addColumns([count])
                ..where(items.groupId.equals(groupId) & predicate))
              .getSingle();
      return row.read(count)!;
    }

    return GroupUsage(
      activeCount: await countWhere(items.archivedAt.isNull()),
      archivedCount: await countWhere(items.archivedAt.isNotNull()),
    );
  }

  /// Renumbers one category's items. [groupId] is required and constrains every
  /// UPDATE: order is only meaningful within a category, so an id from another
  /// one must not be renumbered into this sequence.
  Future<void> reorderItems({
    required int groupId,
    required List<int> idsInOrder,
  }) => transaction(() async {
    for (var i = 0; i < idsInOrder.length; i++) {
      await (update(items)..where(
            (t) => t.id.equals(idsInOrder[i]) & t.groupId.equals(groupId),
          ))
          .write(ItemsCompanion(sortOrder: Value(i)));
    }
  });

  Future<void> reorderItemGroups(List<int> idsInOrder) => transaction(() async {
    for (var i = 0; i < idsInOrder.length; i++) {
      await (update(itemGroups)..where((g) => g.id.equals(idsInOrder[i])))
          .write(ItemGroupsCompanion(sortOrder: Value(i)));
    }
  });

  Future<int> _nextSortOrder(int groupId) async {
    final max = items.sortOrder.max();
    final row =
        await (selectOnly(items)
              ..addColumns([max])
              ..where(items.groupId.equals(groupId)))
            .getSingle();
    return (row.read(max) ?? -1) + 1;
  }

  Future<int> _nextGroupSortOrder() async {
    final max = itemGroups.sortOrder.max();
    final row = await (selectOnly(itemGroups)..addColumns([max])).getSingle();
    return (row.read(max) ?? -1) + 1;
  }
}
