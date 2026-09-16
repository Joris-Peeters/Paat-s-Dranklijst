/// Wiping parts of the database from admin settings.
///
/// The one place rows the ledger references are hard-deleted. The admin PIN
/// guards the way in and the caller saves a backup first, which is what makes
/// it safe; the data layer does not refuse.
library;

import 'database.dart';

enum ResetScope {
  /// Every transaction. Users and items stay, every balance becomes 0.
  transactions,

  /// Every transaction, user and user group.
  users,

  /// Every transaction, item and item category. Top-ups and adjustments go
  /// too: keeping them alone would leave balances nothing adds up to.
  items,

  /// All of the above.
  everything,
}

/// What a reset would remove, for the confirmation dialog. Tables the scope
/// leaves alone count 0.
class ResetCounts {
  const ResetCounts({
    required this.transactions,
    required this.users,
    required this.userGroups,
    required this.items,
    required this.itemGroups,
    required this.debtorCount,
    required this.owedMinorUnits,
    required this.creditorCount,
    required this.heldMinorUnits,
  });

  final int transactions;
  final int users;
  final int userGroups;
  final int items;
  final int itemGroups;

  /// Users who owe, and their debt in total, as a negative amount. Every scope
  /// deletes the transactions, so every scope clears these.
  final int debtorCount;
  final int owedMinorUnits;

  /// Users holding credit, and that credit in total.
  final int creditorCount;
  final int heldMinorUnits;
}

Future<ResetCounts> readResetCounts(AppDatabase db, ResetScope scope) async {
  final row = await db.customSelect('''
    SELECT
      (SELECT COUNT(*) FROM transactions) AS transactions,
      (SELECT COUNT(*) FROM users) AS users,
      (SELECT COUNT(*) FROM user_groups) AS user_groups,
      (SELECT COUNT(*) FROM items) AS items,
      (SELECT COUNT(*) FROM item_groups) AS item_groups,
      (SELECT COUNT(*) FROM user_balances WHERE balance_minor_units < 0)
        AS debtors,
      (SELECT COALESCE(SUM(balance_minor_units), 0) FROM user_balances
        WHERE balance_minor_units < 0) AS owed,
      (SELECT COUNT(*) FROM user_balances WHERE balance_minor_units > 0)
        AS creditors,
      (SELECT COALESCE(SUM(balance_minor_units), 0) FROM user_balances
        WHERE balance_minor_units > 0) AS held
  ''').getSingle();

  final users = scope == ResetScope.users || scope == ResetScope.everything;
  final items = scope == ResetScope.items || scope == ResetScope.everything;
  int read(String column, {bool when = true}) =>
      when ? row.read<int>(column) : 0;

  return ResetCounts(
    transactions: read('transactions'),
    users: read('users', when: users),
    userGroups: read('user_groups', when: users),
    items: read('items', when: items),
    itemGroups: read('item_groups', when: items),
    debtorCount: read('debtors'),
    owedMinorUnits: read('owed'),
    creditorCount: read('creditors'),
    heldMinorUnits: read('held'),
  );
}

/// Deletes what [scope] names, in one transaction and children first, so the
/// foreign keys hold at every step. Nothing is reseeded.
Future<void> resetDatabase(AppDatabase db, ResetScope scope) =>
    db.transaction(() async {
      await db.transactionsDao.deleteAllTransactions();
      if (scope == ResetScope.users || scope == ResetScope.everything) {
        await db.usersDao.deleteAllUsersAndGroups();
      }
      if (scope == ResetScope.items || scope == ResetScope.everything) {
        await db.itemsDao.deleteAllItemsAndGroups();
      }
    });
