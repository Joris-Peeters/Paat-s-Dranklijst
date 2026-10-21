import 'package:flutter/material.dart';

import '../data/daos/stats_dao.dart';
import '../data/database.dart';
import '../data/database_provider.dart';
import '../data/stat_period.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import '../widgets/empty_state.dart';
import '../widgets/period_chips.dart';
import '../widgets/ranked_bar_list.dart';
import '../widgets/stats_card.dart';
import '../widgets/user_avatar.dart';

typedef _Rankings = ({
  List<RankedUser> consumers,
  List<RankedUser> present,
  List<BestDay> bestDays,
  List<LoyalUser> loyal,
});

/// The item dropdown's choice: one item, or a whole category.
typedef _ItemFilter = ({bool category, int id});

/// Who took the most, was there the most, had the biggest day and sticks to
/// one item — by count only, never by balance.
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
  late final Stream<List<({ItemGroupRow group, List<ItemRow> items})>> _items =
      _db.itemsDao.watchItemsByCategory();

  StatPeriod _period = StatPeriod.month;
  int? _userGroupId;
  _ItemFilter? _itemFilter;
  Future<_Rankings>? _data;

  /// A ranking needs this many people before it is worth showing.
  static const _minimumPeople = 5;

  /// Consumptions a user needs before a share of them means anything.
  static int _loyaltyMinimum(StatPeriod period) =>
      period == StatPeriod.month ? 20 : 75;

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
    final filter = _itemFilter;
    final itemId = filter == null || filter.category ? null : filter.id;
    final itemGroupId = filter != null && filter.category ? filter.id : null;
    final at = DateTime.now();
    _data = () async {
      final (consumers, present, bestDays, loyal) = await (
        stats.readTopConsumers(
          period,
          at: at,
          userGroupId: userGroupId,
          itemId: itemId,
          itemGroupId: itemGroupId,
        ),
        stats.readMostPresent(
          period,
          at: at,
          userGroupId: userGroupId,
          itemId: itemId,
          itemGroupId: itemGroupId,
        ),
        stats.readBestDays(
          period,
          at: at,
          userGroupId: userGroupId,
          itemId: itemId,
          itemGroupId: itemGroupId,
        ),
        stats.readMostLoyal(
          period,
          at: at,
          minimumTotal: _loyaltyMinimum(period),
          userGroupId: userGroupId,
          itemId: itemId,
          itemGroupId: itemGroupId,
        ),
      ).wait;
      return (
        consumers: consumers,
        present: present,
        bestDays: bestDays,
        loyal: loyal,
      );
    }();
  }

  void _update(VoidCallback change) => setState(() {
    change();
    _load();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);

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
                    Expanded(child: _itemDropdown(l10n)),
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

              bool enough(List<Object> ranking) =>
                  ranking.length >= _minimumPeople;
              final cards = [
                if (enough(data.consumers))
                  StatsCard(
                    icon: Icons.local_drink_outlined,
                    label: l10n.leaderboardTopConsumers,
                    child: RankedBarList(
                      entries: data.consumers,
                      leading: (ranked) => _avatar(ranked.user),
                      label: (ranked) => ranked.user.name,
                      value: (ranked) => ranked.count,
                    ),
                  ),
                if (enough(data.present))
                  StatsCard(
                    icon: Icons.event_available_outlined,
                    label: l10n.leaderboardMostPresent,
                    child: RankedBarList(
                      entries: data.present,
                      leading: (ranked) => _avatar(ranked.user),
                      label: (ranked) => ranked.user.name,
                      value: (ranked) => ranked.count,
                    ),
                  ),
                if (enough(data.bestDays))
                  StatsCard(
                    icon: Icons.local_fire_department_outlined,
                    label: l10n.leaderboardBestDay,
                    child: RankedBarList(
                      entries: data.bestDays,
                      leading: (best) => _avatar(best.user),
                      label: (best) => best.user.name,
                      value: (best) => best.count,
                      detail: (best) => settings.formatDate(best.day),
                    ),
                  ),
                if (enough(data.loyal))
                  StatsCard(
                    icon: Icons.favorite_outline,
                    label: l10n.leaderboardMostLoyal,
                    child: RankedBarList(
                      entries: data.loyal,
                      leading: (loyal) => _avatar(loyal.user),
                      label: (loyal) => loyal.user.name,
                      value: (loyal) => loyal.share,
                      valueLabel: (loyal) =>
                          settings.formatPercent(loyal.share),
                      outOf: 1,
                      // One item selected: the same emoji on every row.
                      detail: (loyal) => _itemFilter?.category == false
                          ? null
                          : loyal.item.emoji,
                    ),
                  ),
              ];
              if (cards.isEmpty) {
                return EmptyState(
                  icon: Icons.emoji_events_outlined,
                  message: l10n.statsNotEnoughData,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: cards,
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

  Widget _itemDropdown(AppLocalizations l10n) =>
      StreamBuilder<List<({ItemGroupRow group, List<ItemRow> items})>>(
        stream: _items,
        builder: (context, snapshot) {
          final sections = snapshot.data ?? const [];
          final options = <(_ItemFilter, String)>[
            for (final (:group, :items) in sections) ...[
              (
                (category: true, id: group.id),
                group.emoji == null
                    ? group.name
                    : '${group.emoji}  ${group.name}',
              ),
              for (final item in items)
                ((category: false, id: item.id), '${item.emoji}  ${item.name}'),
            ],
          ];
          final selected = options.any((o) => o.$1 == _itemFilter)
              ? _itemFilter
              : null;
          final categoryStyle = Theme.of(context).textTheme.bodyLarge
              ?.copyWith(fontWeight: FontWeight.bold);

          return DropdownButtonFormField<_ItemFilter?>(
            initialValue: selected,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.filterItem,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.filterAll)),
              for (final (filter, label) in options)
                DropdownMenuItem(
                  value: filter,
                  child: Padding(
                    // Items sit indented under their category.
                    padding: EdgeInsetsDirectional.only(
                      start: filter.category ? 0 : 24,
                    ),
                    child: Text(
                      label,
                      style: filter.category ? categoryStyle : null,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
            // The closed field shows the choice plainly, without the indent.
            selectedItemBuilder: (context) => [
              Text(l10n.filterAll, overflow: TextOverflow.ellipsis),
              for (final (_, label) in options)
                Text(label, overflow: TextOverflow.ellipsis),
            ],
            onChanged: (filter) => _update(() => _itemFilter = filter),
          );
        },
      );
}

Widget _avatar(UserRow user) => UserAvatar(
  emoji: user.avatarEmoji,
  seedColorArgb: user.seedColorArgb,
  image: user.avatarImage,
  size: 40,
);
