import 'daos/stats_dao.dart';
import 'database.dart';

/// The automatic orders an admin can put a group's users in.
enum UserSortOrder {
  name,
  activeDays,
  consumptions;

  /// Whether sorting needs the group's activity read first.
  bool get needsActivity => this != name;
}

/// [users] in [order], as ids ready for a reorder.
///
/// The score orders put the highest first and fall back to the name, so a
/// group where nobody drank still comes out alphabetical. The last tie-break
/// is the current position: `List.sort` is not stable, and two users both
/// called Jonas must not swap on every sort.
List<int> sortedUserIds(
  List<UserRow> users,
  UserSortOrder order, {
  Map<int, UserActivity> activity = const {},
}) {
  final position = {for (var i = 0; i < users.length; i++) users[i].id: i};

  int score(UserRow user) => switch (order) {
    UserSortOrder.name => 0,
    UserSortOrder.activeDays => activity[user.id]?.days ?? 0,
    UserSortOrder.consumptions => activity[user.id]?.consumptions ?? 0,
  };

  final sorted = List<UserRow>.of(users)
    ..sort((a, b) {
      final byScore = score(b).compareTo(score(a));
      if (byScore != 0) return byScore;
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (byName != 0) return byName;
      return position[a.id]!.compareTo(position[b.id]!);
    });
  return [for (final user in sorted) user.id];
}
