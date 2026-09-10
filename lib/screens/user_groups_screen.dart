// Only Value: drift also exports a `Column`, which would shadow the widget.
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../data/daos/users_dao.dart';
import '../data/database.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/group_management_view.dart';
import 'user_group_contents_screen.dart';

/// The groups members are organised into.
class UserGroupsScreen extends StatefulWidget {
  const UserGroupsScreen({super.key});

  @override
  State<UserGroupsScreen> createState() => _UserGroupsScreenState();
}

class _UserGroupsScreenState extends State<UserGroupsScreen> {
  // Built once. `Database.of` depends on an inherited widget, so it cannot run
  // in initState; a `late final` first touched in build resolves at the right
  // moment and still only subscribes once.
  late final UsersDao _dao = Database.of(context).usersDao;
  late final Stream<List<GroupEntry>> _groups = _dao
      .watchUserGroupsWithUsage()
      .map(
        (rows) => [
          for (final row in rows)
            (
              id: row.group.id,
              name: row.group.name,
              emoji: row.group.emoji,
              usage: row.usage,
            ),
        ],
      );

  /// The view deals in flattened records, so the row itself is re-read here —
  /// the contents screen wants the group's own name and emoji for its title.
  Future<void> _open(int groupId) async {
    final group = await _dao.readUserGroup(groupId);
    if (group == null || !mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => UserGroupContentsScreen(group: group)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return GroupManagementView(
      title: l10n.userGroups,
      groups: _groups,
      emptyMessage: l10n.noGroupsYet,
      createLabel: l10n.newGroup,
      editLabel: l10n.editGroup,
      deleteLabel: l10n.deleteGroup,
      countLabel: l10n.groupMemberCount,
      onCreate: (edit) async =>
          _dao.createUserGroup(name: edit.name, emoji: edit.emoji),
      onEdit: (id, edit) => _dao.updateUserGroup(
        id,
        UserGroupsCompanion(name: Value(edit.name), emoji: Value(edit.emoji)),
      ),
      onDelete: _dao.deleteUserGroup,
      onReorder: _dao.reorderUserGroups,
      onOpen: (group) => unawaited(_open(group.id)),
    );
  }
}
