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
  const UsersScreen({super.key, this.active = true});

  /// Whether this tab is the one on screen. Leaving it ends a selection, so
  /// the tab never waits with people still ticked.
  final bool active;

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

  /// Picking several people to log the same drink for. Always starts off, and
  /// ends after logging, on Cancel or Back, and when the tab is left.
  bool _selecting = false;

  /// Ids rather than rows, so a tick survives switching chips and searching.
  final _picked = <int>{};

  @override
  void didUpdateWidget(UsersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // No setState: a rebuild follows didUpdateWidget anyway. Going idle lands
    // here too, since it selects the Start tab.
    if (oldWidget.active && !widget.active) {
      _selecting = false;
      _picked.clear();
    }
  }

  void _startSelecting(UserRow user) => setState(() {
    _selecting = true;
    _picked.add(user.id);
  });

  void _stopSelecting() => setState(() {
    _selecting = false;
    _picked.clear();
  });

  void _toggle(UserRow user) => setState(() {
    if (!_picked.remove(user.id)) _picked.add(user.id);
  });

  /// Backing out keeps the ticks, so someone can be added or taken off; only
  /// logging ends the selection.
  Future<void> _next(List<UserRow> users) async {
    final logged = await _push(
      MaterialPageRoute<bool>(
        builder: (_) => ConsumptionScreen.forUsers(users: users),
      ),
    );
    if (logged == true && mounted) _stopSelecting();
  }

  void _openConsumption(UserRow user) => unawaited(
    _push(
      MaterialPageRoute<void>(builder: (_) => ConsumptionScreen(user: user)),
    ),
  );

  void _openDetail(UserRow user) => unawaited(
    _push(
      MaterialPageRoute<void>(builder: (_) => UserDetailScreen(user: user)),
    ),
  );

  /// Pushes [route] and closes the search: a search is one lookup, and the
  /// next person at the fridge should find the tab as it normally is.
  ///
  /// Closed only once the new page fully covers this one. Closing it before
  /// the push visibly snaps the list back just as the page slides in.
  Future<T?> _push<T>(TransitionRoute<T> route) {
    final pushed = Navigator.push(context, route);
    // The route is installed during push, so its animation exists by now.
    final animation = route.animation;
    if (_search != null && animation != null) {
      void closeWhenCovered(AnimationStatus status) {
        if (status != AnimationStatus.completed) return;
        animation.removeStatusListener(closeWhenCovered);
        if (mounted) _closeSearch();
      }

      animation.addStatusListener(closeWhenCovered);
    }
    return pushed;
  }

  void _closeSearch() {
    if (_search == null) return;
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

    return PopScope(
      // Back ends a selection first rather than leaving with people ticked.
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stopSelecting();
      },
      child: Scaffold(
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
              icon: const Icon(Icons.checklist_rounded),
              tooltip: l10n.selectPeople,
              isSelected: _selecting,
              // Visible because long-press is not: nobody finds a gesture they
              // were never told about.
              onPressed: _selecting
                  ? _stopSelecting
                  : () => setState(() => _selecting = true),
            ),
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

                // In list order, and only people still listed: someone archived
                // while ticked quietly drops out.
                final picked = [
                  for (final m in users)
                    if (_picked.contains(m.user.id)) m.user,
                ];

                return Column(
                  children: [
                    if (search == null)
                      _GroupChips(
                        groups: groups,
                        selectedId: selectedId,
                        onSelected: (id) =>
                            setState(() => _selectedGroupId = id),
                      ),
                    Expanded(
                      child: _UserGrid(
                        users: _visibleUsers(users, search, selectedId),
                        emptyMessage: search == null
                            ? l10n.noUsersInGroup
                            : l10n.noSearchResults,
                        picked: _selecting ? _picked : null,
                        onOpen: _openConsumption,
                        onOpenDetail: _openDetail,
                        onToggle: _toggle,
                        onLongPress: _selecting ? _toggle : _startSelecting,
                      ),
                    ),
                    if (_selecting)
                      _SelectionBar(
                        count: picked.length,
                        onCancel: _stopSelecting,
                        // One person is the ordinary flow, which has its own
                        // page with their colours and balance.
                        onNext: picked.length < 2
                            ? null
                            : () => unawaited(_next(picked)),
                      ),
                  ],
                );
              },
            );
          },
        ),
        // Only when an admin has said anyone may add users; otherwise users are
        // added from settings.
        floatingActionButton:
            !_selecting && AppSettings.of(context).allowSelfRegistration
            ? FloatingActionButton.extended(
                onPressed: () => unawaited(
                  showUserEditDialog(
                    context,
                    canChangeGroup: AppSettings.of(context).allowGroupSwitching,
                  ),
                ),
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(l10n.addUser),
              )
            : null,
      ),
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
  const _UserGrid({
    required this.users,
    required this.emptyMessage,
    required this.picked,
    required this.onOpen,
    required this.onOpenDetail,
    required this.onToggle,
    required this.onLongPress,
  });

  final List<UserWithBalance> users;
  final String emptyMessage;

  /// Who is ticked while selecting; null when not selecting at all.
  final Set<int>? picked;

  final ValueChanged<UserRow> onOpen;
  final ValueChanged<UserRow> onOpenDetail;
  final ValueChanged<UserRow> onToggle;
  final ValueChanged<UserRow> onLongPress;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return EmptyState(icon: Icons.people_rounded, message: emptyMessage);
    }

    return ResponsiveTileGrid(
      minTileWidth: _minTileWidth,
      tileHeight: _tileHeight,
      children: [
        for (final entry in users)
          _UserTile(
            entry: entry,
            picked: picked?.contains(entry.user.id),
            onOpen: () => onOpen(entry.user),
            onOpenDetail: () => onOpenDetail(entry.user),
            onToggle: () => onToggle(entry.user),
            onLongPress: () => onLongPress(entry.user),
          ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.entry,
    required this.picked,
    required this.onOpen,
    required this.onOpenDetail,
    required this.onToggle,
    required this.onLongPress,
  });

  final UserWithBalance entry;

  /// Null outside selection mode, where a tap opens the drink screen.
  final bool? picked;

  final VoidCallback onOpen;
  final VoidCallback onOpenDetail;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = entry.user;
    final picked = this.picked;
    final selecting = picked != null;

    final card = Card(
      color: picked == true ? theme.colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: selecting ? onToggle : onOpen,
        onLongPress: onLongPress,
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
                // The avatar ticks too while selecting: a tap that opened
                // someone's page instead would lose the whole selection.
                onTap: selecting ? onToggle : onOpenDetail,
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
            ],
          ),
        ),
      ),
    );

    // Always the same shape of tree, so ticking does not rebuild the card and
    // cut its ink splash short.
    return Stack(
      children: [
        Positioned.fill(child: card),
        if (picked == true)
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: theme.colorScheme.primary,
              child: Icon(
                Icons.check_rounded,
                size: 16,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onCancel,
    required this.onNext,
  });

  final int count;
  final VoidCallback onCancel;

  /// Null until enough people are ticked.
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return BottomAppBar(
      child: Row(
        spacing: 12,
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.cancel,
            onPressed: onCancel,
          ),
          Expanded(
            child: Text(
              l10n.peopleSelected(count),
              style: theme.textTheme.titleMedium,
            ),
          ),
          FilledButton(onPressed: onNext, child: Text(l10n.setupNext)),
        ],
      ),
    );
  }
}
