/// Domain failures the DAOs raise instead of letting a constraint blow up.
///
/// The UI should prevent each one before the tap by disabling the action with
/// an explanation; these are what it costs when that slips through.
library;

/// A group still holds users or items, so it cannot be deleted.
///
/// [archivedCount] is the subtle half: an archived user still carries a
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

/// A user cannot be archived while their balance is not zero: settle up or
/// post an adjustment first.
class UserHasBalanceException implements Exception {
  const UserHasBalanceException({
    required this.userId,
    required this.balanceMinorUnits,
  });

  final int userId;
  final int balanceMinorUnits;

  @override
  String toString() =>
      'UserHasBalanceException: user $userId still has a balance of '
      '$balanceMinorUnits';
}
