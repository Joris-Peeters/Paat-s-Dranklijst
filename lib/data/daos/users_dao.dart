import 'package:drift/drift.dart';

import '../database.dart';
import '../errors.dart';
import '../group_usage.dart';
import '../tables/user_groups_table.dart';
import '../tables/users_table.dart';
import '../views/user_balances_view.dart';

part 'users_dao.g.dart';

/// A member with everything the Members page needs to draw one row.
class MemberWithBalance {
  const MemberWithBalance({
    required this.user,
    required this.group,
    required this.balanceMinorUnits,
  });

  final UserRow user;
  final UserGroupRow group;

  /// Positive means the member has credit, negative means they owe.
  final int balanceMinorUnits;
}

/// A group with how many members it holds, both halves counted.
class UserGroupWithUsage {
  const UserGroupWithUsage({required this.group, required this.usage});

  final UserGroupRow group;
  final GroupUsage usage;
}

/// Queries against members and the groups they belong to.
@DriftAccessor(tables: [Users, UserGroups], views: [UserBalances])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(super.db);

  Stream<List<UserGroupRow>> watchUserGroups() => (select(
    userGroups,
  )..orderBy([(g) => OrderingTerm(expression: g.sortOrder)])).watch();

  /// Every member, in group order then their place inside it. The join is what
  /// makes the order meaningful: `sortOrder` is only unique within a group, so
  /// several members legitimately share a 0.
  Stream<List<UserRow>> watchUsers({bool includeArchived = false}) {
    final query = select(users)
        .join([innerJoin(userGroups, userGroups.id.equalsExp(users.groupId))]);
    if (!includeArchived) {
      query.where(users.archivedAt.isNull());
    }
    query.orderBy([
      OrderingTerm(expression: userGroups.sortOrder),
      OrderingTerm(expression: users.sortOrder),
    ]);
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(users)).toList(),
    );
  }

  /// One group's members. Needs no join: inside a single group the member's own
  /// [Users.sortOrder] is the whole order.
  Stream<List<UserRow>> watchUsersInGroup(
    int groupId, {
    bool includeArchived = false,
  }) {
    final query = select(users)
      ..where((u) => u.groupId.equals(groupId))
      ..orderBy([(u) => OrderingTerm(expression: u.sortOrder)]);
    if (!includeArchived) {
      query.where((u) => u.archivedAt.isNull());
    }
    return query.watch();
  }

  /// Groups with their member counts, in one query rather than a count per row.
  ///
  /// The join is a left one so an empty group still appears — an empty group is
  /// the only kind that can be deleted, so it is exactly the row the management
  /// screen must show.
  Stream<List<UserGroupWithUsage>> watchUserGroupsWithUsage() {
    final active = users.id.count(filter: users.archivedAt.isNull());
    final archived = users.id.count(filter: users.archivedAt.isNotNull());
    final query =
        select(
            userGroups,
          ).join([leftOuterJoin(users, users.groupId.equalsExp(userGroups.id))])
          ..addColumns([active, archived])
          ..groupBy([userGroups.id])
          ..orderBy([OrderingTerm(expression: userGroups.sortOrder)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => UserGroupWithUsage(
              group: row.readTable(userGroups),
              usage: GroupUsage(
                activeCount: row.read(active) ?? 0,
                archivedCount: row.read(archived) ?? 0,
              ),
            ),
          )
          .toList(),
    );
  }

  /// Members in group order, each with their group and running balance.
  ///
  /// [groupId] narrows it to one group, which is what the group contents screen
  /// wants: the balance decides whether a member can be archived at all.
  Stream<List<MemberWithBalance>> watchMembersWithBalances({
    int? groupId,
    bool includeArchived = false,
  }) {
    final query = select(users).join([
      innerJoin(userGroups, userGroups.id.equalsExp(users.groupId)),
      leftOuterJoin(userBalances, userBalances.userId.equalsExp(users.id)),
    ]);
    if (groupId != null) {
      query.where(users.groupId.equals(groupId));
    }
    if (!includeArchived) {
      query.where(users.archivedAt.isNull());
    }
    query.orderBy([
      OrderingTerm(expression: userGroups.sortOrder),
      OrderingTerm(expression: users.sortOrder),
    ]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => MemberWithBalance(
              user: row.readTable(users),
              group: row.readTable(userGroups),
              balanceMinorUnits: _balanceOf(row),
            ),
          )
          .toList(),
    );
  }

  // Two independent routes to zero: a member with no live transactions has no
  // view row at all, and the view's SUM is itself nullable. Collapsed here so
  // `?? 0` is written once rather than at every call site.
  int _balanceOf(TypedResult row) =>
      row.readTableOrNull(userBalances)?.balanceMinorUnits ?? 0;

  Stream<int> watchBalance(int userId) =>
      (select(userBalances)..where((b) => b.userId.equals(userId)))
          .watchSingleOrNull()
          .map((row) => row?.balanceMinorUnits ?? 0);

  Future<int> readBalance(int userId) async {
    final row = await (select(
      userBalances,
    )..where((b) => b.userId.equals(userId))).getSingleOrNull();
    return row?.balanceMinorUnits ?? 0;
  }

  /// [avatarEmoji] and [seedColorArgb] are required rather than defaulted here:
  /// the caller picks them at random from the curated palette, which this
  /// layer has no business knowing about.
  Future<int> createUser({
    required String name,
    required int groupId,
    required String avatarEmoji,
    required int seedColorArgb,
  }) => transaction(() async {
    final order = await _nextSortOrder(groupId);
    return into(users).insert(
      UsersCompanion.insert(
        name: name,
        groupId: groupId,
        avatarEmoji: avatarEmoji,
        seedColorArgb: seedColorArgb,
        sortOrder: Value(order),
      ),
    );
  });

  Future<void> updateUser(int id, UsersCompanion changes) async {
    await (update(users)..where((u) => u.id.equals(id))).write(changes);
  }

  /// Everything the edit dialog can change, in one transaction.
  ///
  /// A group move has to land the member last in the destination and close the
  /// gap they left behind, and a half-applied move would put two members of the
  /// same group on the same number.
  Future<UserRow?> readUser(int id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();

  Future<void> updateUserDetails({
    required int id,
    required String name,
    required String avatarEmoji,
    required int seedColorArgb,
    required int groupId,
  }) => transaction(() async {
    final current = await (select(
      users,
    )..where((u) => u.id.equals(id))).getSingleOrNull();
    if (current == null) return;

    final moved = current.groupId != groupId;
    await (update(users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(
        name: Value(name),
        avatarEmoji: Value(avatarEmoji),
        seedColorArgb: Value(seedColorArgb),
        groupId: Value(groupId),
        // Untouched unless the group changed: a rename must not reshuffle the
        // list the admin is looking at.
        sortOrder: moved
            ? Value(await _nextSortOrder(groupId))
            : const Value.absent(),
      ),
    );
    if (moved) await _renumberGroup(current.groupId);
  });

  /// Closes the gaps a departure left, so one group's numbers stay 0..n-1.
  Future<void> _renumberGroup(int groupId) async {
    final rows =
        await (select(users)
              ..where((u) => u.groupId.equals(groupId))
              ..orderBy([(u) => OrderingTerm(expression: u.sortOrder)]))
            .get();
    for (var i = 0; i < rows.length; i++) {
      await (update(users)..where((u) => u.id.equals(rows[i].id))).write(
        UsersCompanion(sortOrder: Value(i)),
      );
    }
  }

  /// Soft delete. Refuses a member who still owes or holds money — archiving is
  /// not a way to make a debt disappear quietly.
  Future<void> archiveUser(int id) => transaction(() async {
    final balance = await readBalance(id);
    if (balance != 0) {
      throw MemberHasBalanceException(userId: id, balanceMinorUnits: balance);
    }
    await (update(users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(archivedAt: Value(DateTime.now())),
    );
  });

  /// Lands the member last in their group rather than back on their old
  /// number: a reorder while they were archived renumbered everyone else, so
  /// the position they left with is very likely taken.
  Future<void> restoreUser(int id) => transaction(() async {
    final user = await (select(
      users,
    )..where((u) => u.id.equals(id))).getSingleOrNull();
    if (user == null) return;
    await (update(users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(
        archivedAt: const Value(null),
        sortOrder: Value(await _nextSortOrder(user.groupId)),
      ),
    );
  });

  Future<int> createUserGroup({required String name, String? emoji}) =>
      transaction(() async {
        final order = await _nextGroupSortOrder();
        return into(userGroups).insert(
          UserGroupsCompanion.insert(
            name: name,
            emoji: Value(emoji),
            sortOrder: Value(order),
          ),
        );
      });

  Future<UserGroupRow?> readUserGroup(int id) =>
      (select(userGroups)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<void> updateUserGroup(int id, UserGroupsCompanion changes) async {
    await (update(userGroups)..where((g) => g.id.equals(id))).write(changes);
  }

  /// Hard delete, allowed only while the group is genuinely unreferenced. The
  /// count and the delete share this transaction so the check cannot go stale
  /// between them.
  Future<void> deleteUserGroup(int id) => transaction(() async {
    final usage = await userGroupUsage(id);
    if (usage.total > 0) {
      throw GroupInUseException(
        groupId: id,
        activeCount: usage.activeCount,
        archivedCount: usage.archivedCount,
      );
    }
    await (delete(userGroups)..where((g) => g.id.equals(id))).go();
  });

  /// Counts both halves separately so the UI can say "3 members, including 1
  /// archived" instead of letting the delete fail after the tap.
  Future<GroupUsage> userGroupUsage(int groupId) async {
    Future<int> countWhere(Expression<bool> predicate) async {
      final count = countAll();
      final row =
          await (selectOnly(users)
                ..addColumns([count])
                ..where(users.groupId.equals(groupId) & predicate))
              .getSingle();
      return row.read(count)!;
    }

    return GroupUsage(
      activeCount: await countWhere(users.archivedAt.isNull()),
      archivedCount: await countWhere(users.archivedAt.isNotNull()),
    );
  }

  // Both reorders renumber 0..n-1 in one transaction. Under a hundred rows
  // makes gap-based or fractional ordering pointless complexity.

  /// Renumbers one group's members. [groupId] is required and constrains every
  /// UPDATE: order is only meaningful within a group, so an id from another one
  /// must not be renumbered into this sequence.
  Future<void> reorderUsers({
    required int groupId,
    required List<int> idsInOrder,
  }) => transaction(() async {
    for (var i = 0; i < idsInOrder.length; i++) {
      await (update(users)..where(
            (u) => u.id.equals(idsInOrder[i]) & u.groupId.equals(groupId),
          ))
          .write(UsersCompanion(sortOrder: Value(i)));
    }
  });

  Future<void> reorderUserGroups(List<int> idsInOrder) => transaction(() async {
    for (var i = 0; i < idsInOrder.length; i++) {
      await (update(userGroups)..where((g) => g.id.equals(idsInOrder[i])))
          .write(UserGroupsCompanion(sortOrder: Value(i)));
    }
  });

  Future<int> _nextSortOrder(int groupId) async {
    final max = users.sortOrder.max();
    final row =
        await (selectOnly(users)
              ..addColumns([max])
              ..where(users.groupId.equals(groupId)))
            .getSingle();
    return (row.read(max) ?? -1) + 1;
  }

  Future<int> _nextGroupSortOrder() async {
    final max = userGroups.sortOrder.max();
    final row = await (selectOnly(userGroups)..addColumns([max])).getSingle();
    return (row.read(max) ?? -1) + 1;
  }
}
