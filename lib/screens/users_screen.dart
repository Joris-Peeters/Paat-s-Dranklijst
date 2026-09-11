import 'dart:async';

import 'package:flutter/material.dart';

import '../data/daos/users_dao.dart';
import '../data/database.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../widgets/empty_state.dart';
import '../widgets/money_text.dart';
import '../widgets/responsive_tile_grid.dart';
import '../widgets/user_avatar.dart';
import '../widgets/user_edit_dialog.dart';
import 'consumption_screen.dart';
import 'user_detail_screen.dart';

/// A row of avatar, name and balance stays this tall however wide the window gets.
const _tileHeight = 88.0;
const _minTileWidth = 340.0;

/// Everyone with a tab, grouped, and the way into recording a drink.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late final UsersDao _dao = Database.of(context).usersDao;
  late final Stream<List<UserGroupRow>> _groups = _dao.watchUserGroups();

  // Every group at once, filtered below. One subscription: changing the chip or
  // typing in the search box then costs nothing, and the search case — which
  // spans all groups in exactly this order — is this same list unfiltered.
  late final Stream<List<UserWithBalance>> _users = _dao
      .watchUsersWithBalances();

  final _searchController = TextEditingController();

  /// Null when the search field is closed, which is not the same as open and
  /// empty: an open empty field still hides the chips.
  String? _search;

  int? _selectedGroupId;

  void _closeSearch() {
    _searchController.clear();
    setState(() => _search = null);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final search = _search;

    return Scaffold(
      appBar: AppBar(
        title: search == null
            ? Text(l10n.navUsers)
            : TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.search,
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _search = value),
              ),
        actions: [
          IconButton(
            icon: Icon(search == null ? Icons.search : Icons.close),
            tooltip: search == null ? l10n.search : l10n.cancel,
            onPressed: search == null
                ? () => setState(() => _search = '')
                : _closeSearch,
          ),
        ],
      ),
      body: StreamBuilder<List<UserGroupRow>>(
        stream: _groups,
        builder: (context, groupSnapshot) {
          final groups = groupSnapshot.data;
          // No spinner on the first frame: the query is local and a flash of
          // one reads worse than nothing.
          if (groups == null) return const SizedBox.shrink();
          if (groups.isEmpty) {
            return EmptyState(
              icon: Icons.groups_rounded,
              message: l10n.noGroupsYet,
            );
          }

          // Resolved here rather than seeded in a callback, so the first frame
          // after the groups arrive already has a valid chip and nothing calls
          // setState during a build.
          final selectedId = groups.any((g) => g.id == _selectedGroupId)
              ? _selectedGroupId!
              : groups.first.id;

          return StreamBuilder<List<UserWithBalance>>(
            stream: _users,
            builder: (context, userSnapshot) {
              final users = userSnapshot.data;
              if (users == null) return const SizedBox.shrink();

              return Column(
                children: [
                  if (search == null)
                    _GroupChips(
                      groups: groups,
                      selectedId: selectedId,
                      onSelected: (id) => setState(() => _selectedGroupId = id),
                    ),
                  Expanded(
                    child: _UserGrid(
                      users: _visibleUsers(users, search, selectedId),
                      emptyMessage: search == null
                          ? l10n.noUsersInGroup
                          : l10n.noSearchResults,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      // Only when an admin has said anyone may add users; otherwise users are
      // added from settings.
      floatingActionButton: AppSettings.of(context).allowSelfRegistration
          ? FloatingActionButton.extended(
              onPressed: () => unawaited(showUserEditDialog(context)),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(l10n.addUser),
            )
          : null,
    );
  }

  /// Searching crosses every group; otherwise the chip decides. The list is
  /// already in group-then-entry order, so neither case has to re-sort.
  List<UserWithBalance> _visibleUsers(
    List<UserWithBalance> users,
    String? search,
    int selectedId,
  ) {
    if (search == null) {
      return [
        for (final m in users)
          if (m.user.groupId == selectedId) m,
      ];
    }
    final needle = search.trim().toLowerCase();
    if (needle.isEmpty) return users;
    return [
      for (final m in users)
        if (m.user.name.toLowerCase().contains(needle)) m,
    ];
  }
}

class _GroupChips extends StatelessWidget {
  const _GroupChips({
    required this.groups,
    required this.selectedId,
    required this.onSelected,
  });

  final List<UserGroupRow> groups;
  final int selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      spacing: 8,
      children: [
        for (final group in groups)
          ChoiceChip(
            label: Text(
              group.emoji == null
                  ? group.name
                  : '${group.emoji}  ${group.name}',
            ),
            selected: group.id == selectedId,
            onSelected: (_) => onSelected(group.id),
          ),
      ],
    ),
  );
}

class _UserGrid extends StatelessWidget {
  const _UserGrid({required this.users, required this.emptyMessage});

  final List<UserWithBalance> users;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return EmptyState(icon: Icons.people_rounded, message: emptyMessage);
    }

    return ResponsiveTileGrid(
      minTileWidth: _minTileWidth,
      tileHeight: _tileHeight,
      children: [for (final entry in users) _UserTile(entry: entry)],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.entry});

  final UserWithBalance entry;

  void _openDetail(BuildContext context) => unawaited(
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => UserDetailScreen(user: entry.user)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = entry.user;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => unawaited(
          Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => ConsumptionScreen(user: user)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            spacing: 12,
            children: [
              // The list runs on the app's theme, so each avatar brings the
              // entry's own colour with it.
              UserAvatar(
                emoji: user.avatarEmoji,
                seedColorArgb: user.seedColorArgb,
                size: 48,
                onTap: () => _openDetail(context),
              ),
              Expanded(
                child: Text(
                  user.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              MoneyText(amountMinorUnits: entry.balanceMinorUnits),
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: l10n.userOverview,
                onPressed: () => _openDetail(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
