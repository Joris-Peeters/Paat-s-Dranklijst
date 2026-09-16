/// Merging a balances CSV into the database: new names become users, known
/// names have their balance corrected with an adjustment.
///
/// Archived users take no part. They are never matched and never counted as
/// duplicates, so a name shared with one simply creates a new active user.
library;

import 'balance_csv.dart';
import 'daos/users_dao.dart';
import 'database.dart';

/// Names and groups match trimmed and case-insensitive.
String importKey(String name) => name.trim().toLowerCase();

/// A name on more than one CSV row.
class DuplicateCsvName {
  const DuplicateCsvName({required this.name, required this.lines});

  final String name;
  final List<int> lines;
}

/// A CSV name that more than one active user already has.
class AmbiguousName {
  const AmbiguousName({
    required this.line,
    required this.name,
    required this.groups,
  });

  final int line;
  final String name;

  /// The groups the users sharing the name are in, to tell them apart.
  final List<String> groups;
}

class NewImportedUser {
  const NewImportedUser({
    required this.line,
    required this.name,
    required this.group,
    required this.existingGroupId,
    required this.balanceMinorUnits,
  });

  final int line;
  final String name;
  final String group;

  /// Null when the group is one of the plan's new groups.
  final int? existingGroupId;
  final int balanceMinorUnits;
}

class BalanceCorrection {
  const BalanceCorrection({
    required this.line,
    required this.user,
    required this.targetMinorUnits,
  });

  final int line;

  /// With the balance as it was when the plan was made.
  final UserWithBalance user;
  final int targetMinorUnits;

  int get differenceMinorUnits => targetMinorUnits - user.balanceMinorUnits;
}

class BalanceImportPlan {
  const BalanceImportPlan({
    required this.csvErrors,
    required this.duplicateNames,
    required this.ambiguousNames,
    required this.newGroups,
    required this.newUsers,
    required this.corrections,
    required this.unchangedCount,
  });

  final List<BalanceCsvError> csvErrors;
  final List<DuplicateCsvName> duplicateNames;
  final List<AmbiguousName> ambiguousNames;

  /// In order of first appearance, spelled as there.
  final List<String> newGroups;
  final List<NewImportedUser> newUsers;

  /// Only the balances that actually move.
  final List<BalanceCorrection> corrections;
  final int unchangedCount;

  bool get hasErrors =>
      csvErrors.isNotEmpty ||
      duplicateNames.isNotEmpty ||
      ambiguousNames.isNotEmpty;

  bool get changesNothing => newUsers.isEmpty && corrections.isEmpty;
}

/// The export: active users in group order, then their place in it.
Future<String> exportBalancesCsv(
  AppDatabase db, {
  required int decimalDigits,
}) async {
  final users = await db.usersDao.readUsersWithBalances();
  return encodeBalancesCsv([
    for (final u in users)
      (
        name: u.user.name,
        group: u.group.name,
        balanceMinorUnits: u.balanceMinorUnits,
      ),
  ], decimalDigits: decimalDigits);
}

/// Works out what importing [rows] would do, without writing anything.
///
/// [users] are the active users with their balances and [groups] the user
/// groups in their sort order, so the first of two same-named groups wins.
BalanceImportPlan planBalanceImport({
  required List<BalanceCsvRow> rows,
  List<BalanceCsvError> csvErrors = const [],
  required List<UserWithBalance> users,
  required List<UserGroupRow> groups,
}) {
  final rowsByName = <String, List<BalanceCsvRow>>{};
  for (final row in rows) {
    (rowsByName[importKey(row.name)] ??= []).add(row);
  }
  final usersByName = <String, List<UserWithBalance>>{};
  for (final user in users) {
    (usersByName[importKey(user.user.name)] ??= []).add(user);
  }
  final groupIds = <String, int>{};
  for (final group in groups) {
    groupIds.putIfAbsent(importKey(group.name), () => group.id);
  }

  final duplicateNames = <DuplicateCsvName>[];
  final ambiguousNames = <AmbiguousName>[];
  final newGroups = <String, String>{};
  final newUsers = <NewImportedUser>[];
  final corrections = <BalanceCorrection>[];
  var unchangedCount = 0;

  for (final row in rows) {
    final key = importKey(row.name);
    final sameName = rowsByName[key]!;
    if (sameName.length > 1) {
      // Reported once, at its first row.
      if (identical(sameName.first, row)) {
        duplicateNames.add(
          DuplicateCsvName(
            name: row.name,
            lines: [for (final r in sameName) r.line],
          ),
        );
      }
      continue;
    }

    final matches = usersByName[key] ?? const [];
    if (matches.length > 1) {
      ambiguousNames.add(
        AmbiguousName(
          line: row.line,
          name: row.name,
          groups: [for (final m in matches) m.group.name],
        ),
      );
    } else if (matches.length == 1) {
      final correction = BalanceCorrection(
        line: row.line,
        user: matches.single,
        targetMinorUnits: row.balanceMinorUnits,
      );
      if (correction.differenceMinorUnits == 0) {
        unchangedCount++;
      } else {
        corrections.add(correction);
      }
    } else {
      final groupKey = importKey(row.group);
      final existingGroupId = groupIds[groupKey];
      if (existingGroupId == null) {
        newGroups.putIfAbsent(groupKey, () => row.group);
      }
      newUsers.add(
        NewImportedUser(
          line: row.line,
          name: row.name,
          group: row.group,
          existingGroupId: existingGroupId,
          balanceMinorUnits: row.balanceMinorUnits,
        ),
      );
    }
  }

  return BalanceImportPlan(
    csvErrors: csvErrors,
    duplicateNames: duplicateNames,
    ambiguousNames: ambiguousNames,
    newGroups: newGroups.values.toList(),
    newUsers: newUsers,
    corrections: corrections,
    unchangedCount: unchangedCount,
  );
}

/// Carries out [plan] in one transaction, so a failure part-way leaves
/// nothing half imported.
///
/// [appearance] picks a new user's emoji and colour; this layer does not know
/// the palette. A correction re-reads the balance inside the transaction, so a
/// tap at the fridge after the preview cannot put it off by that drink.
Future<void> applyBalanceImport(
  AppDatabase db,
  BalanceImportPlan plan, {
  required ({String avatarEmoji, int seedColorArgb}) Function() appearance,
  required String note,
}) {
  assert(!plan.hasErrors, 'a plan with errors cannot be applied');

  return db.transaction(() async {
    final createdGroups = <String, int>{};
    for (final name in plan.newGroups) {
      createdGroups[importKey(name)] = await db.usersDao.createUserGroup(
        name: name,
      );
    }

    for (final user in plan.newUsers) {
      final look = appearance();
      final id = await db.usersDao.createUser(
        name: user.name,
        groupId: user.existingGroupId ?? createdGroups[importKey(user.group)]!,
        avatarEmoji: look.avatarEmoji,
        seedColorArgb: look.seedColorArgb,
      );
      if (user.balanceMinorUnits != 0) {
        await db.transactionsDao.logAdjustment(
          userId: id,
          amountMinorUnits: user.balanceMinorUnits,
          note: note,
        );
      }
    }

    for (final correction in plan.corrections) {
      final userId = correction.user.user.id;
      final current = await db.usersDao.readBalance(userId);
      final difference = correction.targetMinorUnits - current;
      if (difference == 0) continue;
      await db.transactionsDao.logAdjustment(
        userId: userId,
        amountMinorUnits: difference,
        note: note,
      );
    }
  });
}
