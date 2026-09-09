/// How many rows a group holds. Archived rows count: they still carry a
/// `groupId`, so they pin the group just as hard.
class GroupUsage {
  const GroupUsage({required this.activeCount, required this.archivedCount});

  final int activeCount;
  final int archivedCount;

  int get total => activeCount + archivedCount;
}
