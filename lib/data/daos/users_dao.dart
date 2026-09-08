import 'package:drift/drift.dart';

import '../database.dart';
import '../errors.dart';
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

  /// Positive means the member has credit, negative means they owe. See rule 1.
  final int balanceMinorUnits;
}

/// How many rows a group holds. Archived rows count: they still carry a
/// `groupId`, so they pin the group just as hard. See rule 7.
class GroupUsage {
  const GroupUsage({required this.activeCount, required this.archivedCount});

  final int activeCount;
  final int archivedCount;

  int get total => activeCount + archivedCount;
}

/// Queries against members and the groups they belong to.
@DriftAccessor(tables: [Users, UserGroups], views: [UserBalances])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(super.db);

  Stream<List<UserGroupRow>> watchUserGroups() =>
      (select(userGroups)..orderBy([(g) => OrderingTerm(expression: g.sortOrder)]))
          .watch();

  Stream<List<UserRow>> watchUsers({bool includeArchived = false}) {
    final query = select(users)
      ..orderBy([(u) => OrderingTerm(expression: u.sortOrder)]);
    if (!includeArchived) {
      query.where((u) => u.archivedAt.isNull());
    }
    return query.watch();
  }

  /// Members in group order, each with their group and running balance.
  Stream<List<MemberWithBalance>> watchMembersWithBalances({
    bool includeArchived = false,
  }) {
    final query = select(users).join([
      innerJoin(userGroups, userGroups.id.equalsExp(users.groupId)),
      leftOuterJoin(userBalances, userBalances.userId.equalsExp(users.id)),
    ]);
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
  /// the caller picks them at random from the curated palette (rule 4), which
  /// this layer has no business knowing about.
  Future<int> createUser({
    required String name,
    required int groupId,
    required String avatarEmoji,
    required int seedColorArgb,
  }) => transaction(() async {
    final order = await _nextSortOrder();
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

  /// Soft delete. Refuses a member who still owes or holds money — archiving is
  /// not a way to make a debt disappear quietly. See rule 7.
  Future<void> archiveUser(int id) => transaction(() async {
    final balance = await readBalance(id);
    if (balance != 0) {
      throw MemberHasBalanceException(userId: id, balanceMinorUnits: balance);
    }
    await (update(users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(archivedAt: Value(DateTime.now())),
    );
  });

  Future<void> restoreUser(int id) async {
    await (update(users)..where((u) => u.id.equals(id))).write(
      const UsersCompanion(archivedAt: Value(null)),
    );
  }

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

  Future<void> updateUserGroup(int id, UserGroupsCompanion changes) async {
    await (update(userGroups)..where((g) => g.id.equals(id))).write(changes);
  }

  /// Hard delete, allowed only while the group is genuinely unreferenced. The
  /// count and the delete share this transaction so the check cannot go stale
  /// between them. See rule 7.
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
  Future<void> reorderUsers(List<int> idsInOrder) => transaction(() async {
    for (var i = 0; i < idsInOrder.length; i++) {
      await (update(users)..where((u) => u.id.equals(idsInOrder[i]))).write(
        UsersCompanion(sortOrder: Value(i)),
      );
    }
  });

  Future<void> reorderUserGroups(List<int> idsInOrder) => transaction(() async {
    for (var i = 0; i < idsInOrder.length; i++) {
      await (update(userGroups)..where((g) => g.id.equals(idsInOrder[i])))
          .write(UserGroupsCompanion(sortOrder: Value(i)));
    }
  });

  Future<int> _nextSortOrder() async {
    final max = users.sortOrder.max();
    final row = await (selectOnly(users)..addColumns([max])).getSingle();
    return (row.read(max) ?? -1) + 1;
  }

  Future<int> _nextGroupSortOrder() async {
    final max = userGroups.sortOrder.max();
    final row = await (selectOnly(userGroups)..addColumns([max])).getSingle();
    return (row.read(max) ?? -1) + 1;
  }

}
