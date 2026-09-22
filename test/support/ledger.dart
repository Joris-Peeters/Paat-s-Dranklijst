import 'package:paats_dranklijst/data/database.dart';

/// Test shorthands over the app's own queries. Writes go through the DAO the
/// app uses; reads are plain selects for checking what landed.
extension TestLedger on AppDatabase {
  /// One consumption line for one user; returns the row id.
  Future<int> logConsumption({
    required int userId,
    required ItemRow item,
    int quantity = 1,
  }) async => (await logConsumptions(
    userId: userId,
    lines: [(item: item, quantity: quantity)],
  )).single;

  /// One order of several lines for one user.
  Future<List<int>> logConsumptions({
    required int userId,
    required List<({ItemRow item, int quantity})> lines,
  }) =>
      transactionsDao.logConsumptionsForUsers(userIds: [userId], lines: lines);

  /// A user's rows, newest first, voided ones included.
  Future<List<TransactionRow>> userHistory(int userId) async =>
      (await transactionsDao.watchHistory(userId: userId).first)
          .map((entry) => entry.transaction)
          .toList();

  Future<TransactionRow?> readTransaction(int id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<UserRow?> readUser(int id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();
}
