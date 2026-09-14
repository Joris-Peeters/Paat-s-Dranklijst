import 'dart:async';

import 'package:flutter/material.dart';

import '../data/daos/stats_dao.dart';
import '../data/database.dart';
import '../data/database_provider.dart';
import '../data/logical_day.dart';
import '../data/stat_period.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import '../widgets/money_text.dart';
import '../widgets/period_chips.dart';
import '../widgets/ranked_bar_list.dart';
import '../widgets/stat_tile.dart';
import '../widgets/stats_card.dart';
import '../widgets/transaction_history.dart';
import '../widgets/trend_line_chart.dart';
import '../widgets/user_avatar.dart';
import '../widgets/user_edit_dialog.dart';
import '../widgets/user_header.dart';
import '../widgets/user_theme_scope.dart';
import 'consumption_screen.dart';

/// One user's page: where they stand, what they took, and the way to top up.
class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.user});

  final UserRow user;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late final AppDatabase _db = Database.of(context);

  // Watched rather than taken from the widget: the pencil in the app bar can
  // rename or recolour this very user, and a copy would leave the header and
  // the page's whole palette a step behind.
  late final Stream<UserRow?> _user = _db.usersDao.watchUser(widget.user.id);

  @override
  Widget build(BuildContext context) => StreamBuilder<UserRow?>(
    stream: _user,
    builder: (context, snapshot) {
      // The row passed in stands in until the query resolves, so nothing
      // flashes and the theme never starts on the wrong colour.
      final user = snapshot.data ?? widget.user;

      return UserThemeScope(
        seedColorArgb: user.seedColorArgb,
        child: _Page(user: user),
      );
    },
  );
}

class _Page extends StatelessWidget {
  const _Page({required this.user});

  final UserRow user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);

    return Scaffold(
      appBar: AppBar(
        // What the page is, not who: the name is already the largest thing on
        // it, and repeating it in the bar says nothing twice.
        title: Text(l10n.userOverview),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_cafe),
            tooltip: l10n.takeSomething,
            // Replaces rather than pushes: this page and that one are two views
            // of the same user, and both were opened from the user list, so
            // hopping between them must not stack up routes to back out of.
            onPressed: () => unawaited(
              Navigator.pushReplacement<void, void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ConsumptionScreen(user: user),
                ),
              ),
            ),
          ),
          // The one editing surface with no PIN in front of it, so it is the
          // one an admin can close off. The management screens ignore this.
          if (settings.allowUserEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.edit,
              onPressed: () => unawaited(
                showUserEditDialog(
                  context,
                  user: user,
                  canChangeGroup: settings.allowGroupSwitching,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            UserHeader(user: user),
            RecentTransactionsCard(user: user),
            _UserStats(userId: user.id),
          ],
        ),
      ),
    );
  }
}

/// Spend, favourites and the weekly trend. Live, because a row voided from the
/// history card above has to leave these figures too.
class _UserStats extends StatefulWidget {
  const _UserStats({required this.userId});

  final int userId;

  @override
  State<_UserStats> createState() => _UserStatsState();
}

class _UserStatsState extends State<_UserStats> {
  late final StatsDao _stats = Database.of(context).statsDao;

  // The day is fixed when the page opens; nobody stands on one user's page
  // across 07:00.
  final DateTime _openedAt = DateTime.now();

  late final Stream<UserSpend> _spend = _stats.watchUserSpend(
    widget.userId,
    at: _openedAt,
  );
  late final Stream<List<RankedItem>> _topItems = _stats.watchUserTopItems(
    widget.userId,
  );
  late final Stream<UserWeekly> _weekly = _stats.watchUserWeekly(
    widget.userId,
    at: _openedAt,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);
    final figure = Theme.of(context).textTheme.titleLarge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        StreamBuilder<UserSpend>(
          stream: _spend,
          builder: (context, snapshot) {
            final spend = snapshot.data;
            Widget money(int? amount) => MoneyText(
              amountMinorUnits: amount ?? 0,
              colored: false,
              style: figure,
            );

            return StatsCard(
              icon: Icons.payments_outlined,
              label: l10n.userSpend,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Expanded(
                      child: StatTile(
                        label: periodLabel(l10n, StatPeriod.month),
                        ready: spend != null,
                        child: money(spend?.month),
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: periodLabel(l10n, StatPeriod.year),
                        ready: spend != null,
                        child: money(spend?.year),
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: periodLabel(l10n, StatPeriod.all),
                        ready: spend != null,
                        child: money(spend?.allTime),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        StreamBuilder<List<RankedItem>>(
          stream: _topItems,
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <RankedItem>[];
            if (items.isEmpty) return const SizedBox.shrink();

            return StatsCard(
              icon: Icons.local_drink_outlined,
              label: l10n.statsTopItems,
              child: RankedBarList(
                entries: [
                  for (final ranked in items)
                    RankedBar(
                      // Already inside this user's theme, so only the circle.
                      leading: AvatarCircle(emoji: ranked.item.emoji, size: 40),
                      label: ranked.item.name,
                      count: ranked.count,
                    ),
                ],
              ),
            );
          },
        ),
        StreamBuilder<UserWeekly>(
          stream: _weekly,
          builder: (context, snapshot) {
            final weekly = snapshot.data;
            final firstDay = weekly?.firstDay;
            // Under six weeks of history a trend is mostly empty weeks.
            if (weekly == null ||
                firstDay == null ||
                daysBetween(firstDay, logicalDayOf(_openedAt)) < 42) {
              return const SizedBox.shrink();
            }

            return StatsCard(
              icon: Icons.show_chart,
              label: l10n.userTrend,
              child: TrendLineChart(
                counts: [for (final week in weekly.weeks) week.count],
                labelOf: (i) => settings.formatDayMonth(weekly.weeks[i].start),
              ),
            );
          },
        ),
      ],
    );
  }
}
