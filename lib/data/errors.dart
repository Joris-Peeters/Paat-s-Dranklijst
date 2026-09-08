/// Domain failures the DAOs raise instead of letting a constraint blow up.
///
/// Each one is a condition the UI should prevent before the tap, by disabling
/// the action with an explanation. They exist so that when it slips through
/// anyway the failure is a clear message rather than a foreign-key violation.
library;

/// A group still holds users or items, so it cannot be deleted.
///
/// [archivedCount] is the subtle half: an archived member still carries a
/// `groupId`, so a group can look empty on screen while archived rows pin it.
class GroupInUseException implements Exception {
  const GroupInUseException({
    required this.groupId,
    required this.activeCount,
    required this.archivedCount,
  });

  final int groupId;
  final int activeCount;
  final int archivedCount;

  @override
  String toString() =>
      'GroupInUseException: group $groupId still holds $activeCount active and '
      '$archivedCount archived rows';
}

/// A member cannot be archived while their balance is not zero.
///
/// Settle up or post an adjustment first — archiving is not a way to make a
/// debt disappear quietly.
class MemberHasBalanceException implements Exception {
  const MemberHasBalanceException({
    required this.userId,
    required this.balanceMinorUnits,
  });

  final int userId;
  final int balanceMinorUnits;

  @override
  String toString() =>
      'MemberHasBalanceException: member $userId still has a balance of '
      '$balanceMinorUnits';
}
