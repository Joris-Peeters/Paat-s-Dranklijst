import 'dart:async';

import 'package:flutter/material.dart';

import '../data/daos/users_dao.dart';
import '../data/database.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import '../widgets/adjustment_dialog.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/reorderable_sliver_section.dart';
import '../widgets/user_edit_dialog.dart';

const _cardMargin = EdgeInsets.symmetric(horizontal: 16, vertical: 4);

/// The users of one group, in the order they appear on the fridge.
class UserGroupContentsScreen extends StatefulWidget {
  const UserGroupContentsScreen({super.key, required this.group});

  final UserGroupRow group;

  @override
  State<UserGroupContentsScreen> createState() =>
      _UserGroupContentsScreenState();
}

class _UserGroupContentsScreenState extends State<UserGroupContentsScreen> {
  late final UsersDao _dao = Database.of(context).usersDao;

  // Subscribed once, archived rows included, and partitioned below: the toggle
  // then shows and hides a section instead of resubscribing, which a
  // `late final` stream could not do anyway.
  late final Stream<List<UserWithBalance>> _users = _dao.watchUsersWithBalances(
    groupId: widget.group.id,
    includeArchived: true,
  );

  Future<void> _archive(UserWithBalance entry) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.archive,
      message: l10n.archiveUserConfirm(entry.user.name),
      confirmLabel: l10n.archive,
    );
    if (confirmed) await _dao.archiveUser(entry.user.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final emoji = widget.group.emoji;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          emoji == null ? widget.group.name : '$emoji  ${widget.group.name}',
        ),
      ),
      body: StreamBuilder<List<UserWithBalance>>(
        stream: _users,
        builder: (context, snapshot) {
          final users = snapshot.data;
          // No spinner on the first frame: the query is local and a flash of
          // one reads worse than nothing.
          if (users == null) return const SizedBox.shrink();

          final active = [
            for (final m in users)
              if (m.user.archivedAt == null) m,
          ];
          final archived = [
            for (final m in users)
              if (m.user.archivedAt != null) m,
          ];

          if (active.isEmpty && archived.isEmpty) {
            return EmptyState(
              icon: Icons.people_rounded,
              message: l10n.noUsersInGroup,
            );
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(top: 8),
                sliver: ReorderableSliverSection<UserWithBalance>(
                  items: active,
                  keyOf: (m) => ValueKey(m.user.id),
                  onReorder: (ordered) => unawaited(
                    _dao.reorderUsers(
                      groupId: widget.group.id,
                      idsInOrder: [for (final m in ordered) m.user.id],
                    ),
                  ),
                  itemBuilder: (context, entry, index) => _UserTile(
                    entry: entry,
                    index: index,
                    onArchive: () => unawaited(_archive(entry)),
                  ),
                ),
              ),
              if (archived.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(title: l10n.archivedSection),
                ),
                SliverList.builder(
                  itemCount: archived.length,
                  itemBuilder: (context, index) => _UserTile(
                    entry: archived[index],
                    onRestore: () =>
                        unawaited(_dao.restoreUser(archived[index].user.id)),
                  ),
                ),
              ],
              // Room for the FAB to not cover the last row.
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(
          showUserEditDialog(context, presetGroupId: widget.group.id),
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.newUser),
      ),
    );
  }
}

/// One entry. Archived when [onRestore] is given instead of [onArchive]: the
/// row then has no drag handle and is dimmed, since order among retired users
/// means nothing.
class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.entry,
    this.index,
    this.onArchive,
    this.onRestore,
  });

  final UserWithBalance entry;
  final int? index;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;

  bool get _archived => onRestore != null;

  /// Archiving is not a way to make a debt disappear quietly, so a entry who
  /// still owes or holds money cannot be retired at all.
  String? _blockedReason(BuildContext context) {
    if (_archived || entry.balanceMinorUnits == 0) return null;
    return AppLocalizations.of(context).archiveBlockedBalance(
      entry.user.name,
      AppSettings.of(context).formatMoney(entry.balanceMinorUnits),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final blocked = _blockedReason(context);
    final index = this.index;

    final tile = Card(
      margin: _cardMargin,
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 8, right: 4),
        leading: SizedBox(
          width: 48,
          child: index == null ? null : DragHandle(index: index),
        ),
        title: Text(
          entry.user.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: l10n.adjustment,
              // Archived entries keep it disabled: their balance is already
              // zero, which is what archiving them required.
              //
              // Only from here, never from a user's own page. This screen sits
              // behind the settings PIN; an adjustment on the open kiosk would
              // let anyone write their own balance to whatever they liked.
              onPressed: _archived
                  ? null
                  : () => unawaited(
                      showAdjustmentDialog(context, user: entry.user),
                    ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.edit,
              onPressed: () =>
                  unawaited(showUserEditDialog(context, user: entry.user)),
            ),
            if (_archived)
              IconButton(
                icon: const Icon(Icons.unarchive_outlined),
                tooltip: l10n.unarchive,
                onPressed: onRestore,
              )
            else
              IconButton(
                icon: const Icon(Icons.archive_outlined),
                tooltip: blocked ?? l10n.archive,
                // A disabled IconButton swallows the tap, so it stays live and
                // only looks disabled — the reason would have nowhere to go.
                color: blocked == null ? null : theme.disabledColor,
                onPressed: blocked == null
                    ? onArchive
                    : () =>
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(blocked))),
              ),
          ],
        ),
      ),
    );

    return _archived ? Opacity(opacity: 0.5, child: tile) : tile;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
