import 'package:flutter/material.dart';

import '../data/daos/stats_dao.dart';
import '../data/database.dart';
import '../data/database_provider.dart';
import '../data/stat_period.dart';
import '../l10n/app_localizations.dart';
import '../widgets/empty_state.dart';
import '../widgets/period_chips.dart';
import '../widgets/ranked_bar_list.dart';
import '../widgets/stats_card.dart';
import '../widgets/user_avatar.dart';

typedef _Rankings = ({List<RankedUser> consumers, List<RankedUser> present});

/// Who took the most and who was there the most, by count only — never by
/// balance.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.active});

  /// Whether this tab is the one on screen. The rankings load each time it
  /// becomes true rather than following every tap at the fridge live.
  final bool active;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final AppDatabase _db = Database.of(context);

  // The options, unlike the rankings, stay live: they read users and items
  // only, which a tap at the fridge never writes.
  late final Stream<List<UserGroupRow>> _groups = _db.usersDao
      .watchUserGroups();
  late final Stream<List<ItemRow>> _items = _db.itemsDao.watchItems(
    includeArchived: true,
  );

  StatPeriod _period = StatPeriod.month;
  int? _userGroupId;
  int? _itemId;
  Future<_Rankings>? _data;

  /// A ranking needs this many people before it is worth showing.
  static const _minimumPeople = 5;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.active && _data == null) _load();
  }

  @override
  void didUpdateWidget(LeaderboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  void _load() {
    final stats = _db.statsDao;
    final period = _period;
    final userGroupId = _userGroupId;
    final itemId = _itemId;
    final at = DateTime.now();
    _data = () async {
      final (consumers, present) = await (
        stats.readTopConsumers(
          period,
          at: at,
          userGroupId: userGroupId,
          itemId: itemId,
        ),
        stats.readMostPresent(
          period,
          at: at,
          userGroupId: userGroupId,
          itemId: itemId,
        ),
      ).wait;
      return (consumers: consumers, present: present);
    }();
  }

  void _update(VoidCallback change) => setState(() {
    change();
    _load();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navLeaderboard)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                PeriodChips(
                  selected: _period,
                  onSelected: (period) => _update(() => _period = period),
                ),
                Row(
                  spacing: 12,
                  children: [
                    Expanded(child: _groupFilter(l10n)),
                    Expanded(child: _itemFilter(l10n)),
                  ],
                ),
              ],
            ),
          ),
          FutureBuilder<_Rankings>(
            future: _data,
            builder: (context, snapshot) {
              final data = snapshot.data;
              // Never loaded: the tab has not been on screen yet.
              if (snapshot.connectionState == ConnectionState.none) {
                return const SizedBox.shrink();
              }
              if (data == null) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final consumers = data.consumers.length >= _minimumPeople;
              final present = data.present.length >= _minimumPeople;
              if (!consumers && !present) {
                return EmptyState(
                  icon: Icons.emoji_events_outlined,
                  message: l10n.statsNotEnoughData,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  if (consumers)
                    _Ranking(
                      icon: Icons.local_drink_outlined,
                      label: l10n.leaderboardTopConsumers,
                      entries: data.consumers,
                    ),
                  if (present)
                    _Ranking(
                      icon: Icons.event_available_outlined,
                      label: l10n.leaderboardMostPresent,
                      entries: data.present,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _groupFilter(AppLocalizations l10n) =>
      StreamBuilder<List<UserGroupRow>>(
        stream: _groups,
        builder: (context, snapshot) {
          final groups = snapshot.data ?? const <UserGroupRow>[];
          // The value has to be one of the items or the dropdown asserts,
          // which it is not on the first frame before the query resolves.
          final selected = groups.any((g) => g.id == _userGroupId)
              ? _userGroupId
              : null;

          return DropdownButtonFormField<int?>(
            initialValue: selected,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.groupLabel,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.filterEveryone)),
              for (final group in groups)
                DropdownMenuItem(
                  value: group.id,
                  child: Text(
                    group.emoji == null
                        ? group.name
                        : '${group.emoji}  ${group.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) => _update(() => _userGroupId = id),
          );
        },
      );

  Widget _itemFilter(AppLocalizations l10n) => StreamBuilder<List<ItemRow>>(
    stream: _items,
    builder: (context, snapshot) {
      final items = snapshot.data ?? const <ItemRow>[];
      final selected = items.any((i) => i.id == _itemId) ? _itemId : null;

      return DropdownButtonFormField<int?>(
        initialValue: selected,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.filterItem,
          border: const OutlineInputBorder(),
        ),
        items: [
          DropdownMenuItem(value: null, child: Text(l10n.filterAll)),
          for (final item in items)
            DropdownMenuItem(
              value: item.id,
              child: Text(
                '${item.emoji}  ${item.name}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (id) => _update(() => _itemId = id),
      );
    },
  );
}

class _Ranking extends StatelessWidget {
  const _Ranking({
    required this.icon,
    required this.label,
    required this.entries,
  });

  final IconData icon;
  final String label;
  final List<RankedUser> entries;

  @override
  Widget build(BuildContext context) => StatsCard(
    icon: icon,
    label: label,
    child: RankedBarList(
      entries: [
        for (final ranked in entries)
          RankedBar(
            leading: UserAvatar(
              emoji: ranked.user.avatarEmoji,
              seedColorArgb: ranked.user.seedColorArgb,
              size: 40,
            ),
            label: ranked.user.name,
            count: ranked.count,
          ),
      ],
    ),
  );
}
