import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/data/user_sort.dart';

UserRow user(int id, String name) => UserRow(
  id: id,
  name: name,
  avatarEmoji: '🦊',
  seedColorArgb: 0xFF009688,
  groupId: 1,
  sortOrder: 0,
  createdAt: DateTime(2026),
);

void main() {
  test('by name ignores case', () {
    final users = [user(1, 'bob'), user(2, 'Cas'), user(3, 'Ann')];
    expect(sortedUserIds(users, UserSortOrder.name), [3, 1, 2]);
  });

  test('a score order puts the highest first and ties alphabetically', () {
    final users = [
      user(1, 'Dirk'),
      user(2, 'Cas'),
      user(3, 'Bob'),
      user(4, 'Ann'),
    ];
    final activity = {
      1: (consumptions: 2, days: 9),
      2: (consumptions: 7, days: 1),
      3: (consumptions: 2, days: 1),
    };

    expect(
      sortedUserIds(users, UserSortOrder.consumptions, activity: activity),
      [2, 3, 1, 4],
    );
    expect(sortedUserIds(users, UserSortOrder.activeDays, activity: activity), [
      1,
      3,
      2,
      4,
    ]);
  });

  test('users with the same name keep their current order', () {
    final users = [user(7, 'Jonas'), user(2, 'Jonas'), user(5, 'Jonas')];
    expect(sortedUserIds(users, UserSortOrder.name), [7, 2, 5]);
  });
}
