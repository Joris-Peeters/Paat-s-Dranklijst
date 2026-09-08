import 'package:drift/drift.dart';

import '../database.dart';
import '../errors.dart';
import '../tables/item_groups_table.dart';
import '../tables/items_table.dart';
import 'users_dao.dart' show GroupUsage;

part 'items_dao.g.dart';

/// Queries against drinks and the categories they belong to.
///
/// Mirrors [UsersDao], minus the balance: an item holds no money, so archiving
/// one needs no guard.
@DriftAccessor(tables: [Items, ItemGroups])
class ItemsDao extends DatabaseAccessor<AppDatabase> with _$ItemsDaoMixin {
  ItemsDao(super.db);

  Stream<List<ItemGroupRow>> watchItemGroups() =>
      (select(itemGroups)
            ..orderBy([(g) => OrderingTerm(expression: g.sortOrder)]))
          .watch();

  Stream<List<ItemRow>> watchItems({bool includeArchived = false}) {
    final query = select(items)
      ..orderBy([(i) => OrderingTerm(expression: i.sortOrder)]);
    if (!includeArchived) {
      query.where((i) => i.archivedAt.isNull());
    }
    return query.watch();
  }

  Future<int> createItem({
    required String name,
    required int groupId,
    required int priceMinorUnits,
    required String emoji,
  }) => transaction(() async {
    final order = await _nextSortOrder();
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

  /// Soft delete: a discontinued drink stays referenced by the ledger.
  Future<void> archiveItem(int id) async {
    await (update(items)..where((i) => i.id.equals(id))).write(
      ItemsCompanion(archivedAt: Value(DateTime.now())),
    );
  }

  Future<void> restoreItem(int id) async {
    await (update(items)..where((i) => i.id.equals(id))).write(
      const ItemsCompanion(archivedAt: Value(null)),
    );
  }

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

  Future<void> updateItemGroup(int id, ItemGroupsCompanion changes) async {
    await (update(itemGroups)..where((g) => g.id.equals(id))).write(changes);
  }

  /// Hard delete, allowed only while unreferenced. The count and the delete
  /// share this transaction so the check cannot go stale. See rule 7.
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

  Future<void> reorderItems(List<int> idsInOrder) => transaction(() async {
    for (var i = 0; i < idsInOrder.length; i++) {
      await (update(items)..where((t) => t.id.equals(idsInOrder[i]))).write(
        ItemsCompanion(sortOrder: Value(i)),
      );
    }
  });

  Future<void> reorderItemGroups(List<int> idsInOrder) => transaction(() async {
    for (var i = 0; i < idsInOrder.length; i++) {
      await (update(itemGroups)..where((g) => g.id.equals(idsInOrder[i])))
          .write(ItemGroupsCompanion(sortOrder: Value(i)));
    }
  });

  Future<int> _nextSortOrder() async {
    final max = items.sortOrder.max();
    final row = await (selectOnly(items)..addColumns([max])).getSingle();
    return (row.read(max) ?? -1) + 1;
  }

  Future<int> _nextGroupSortOrder() async {
    final max = itemGroups.sortOrder.max();
    final row = await (selectOnly(itemGroups)..addColumns([max])).getSingle();
    return (row.read(max) ?? -1) + 1;
  }

}
