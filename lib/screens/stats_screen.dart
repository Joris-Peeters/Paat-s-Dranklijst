import 'package:flutter/material.dart';

import '../data/daos/stats_dao.dart';
import '../data/database_provider.dart';
import '../data/stat_buckets.dart';
import '../data/stat_period.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import '../widgets/count_bar_chart.dart';
import '../widgets/empty_state.dart';
import '../widgets/period_chips.dart';
import '../widgets/ranked_bar_list.dart';
import '../widgets/stat_tile.dart';
import '../widgets/stats_card.dart';
import '../widgets/user_avatar.dart';

typedef _StatsData = ({
  StatsKpis kpis,
  Volume volume,
  List<RankedItem> topItems,
  List<({int hour, int count})> hours,
});

/// How the fridge is used: totals, volume over time, favourites, and when.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.active});

  /// Whether this tab is the one on screen. The figures load each time it
  /// becomes true rather than following every tap at the fridge live.
  final bool active;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final StatsDao _stats = Database.of(context).statsDao;

  StatPeriod _period = StatPeriod.month;
  Future<_StatsData>? _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.active && _data == null) _load();
  }

  @override
  void didUpdateWidget(StatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  /// Reads "now" afresh, so a visit after 07:00 is about the new day.
  void _load() {
    final period = _period;
    final at = DateTime.now();
    _data = () async {
      final (kpis, volume, topItems, hours) = await (
        _stats.readKpis(period, at: at),
        _stats.readVolume(period, at: at),
        _stats.readTopItems(period, at: at),
        _stats.readHourOfNight(period, at: at),
      ).wait;
      return (kpis: kpis, volume: volume, topItems: topItems, hours: hours);
    }();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navStats)),
      body: FutureBuilder<_StatsData>(
        future: _data,
        // Keeps the previous period's data while the next one loads, so the
        // page does not blank out on every chip tap.
        builder: (context, snapshot) {
          final data = snapshot.data;

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: PeriodChips(
                  selected: _period,
                  onSelected: (period) => setState(() {
                    _period = period;
                    _load();
                  }),
                ),
              ),
              // Never loaded: the tab has not been on screen yet.
              if (snapshot.connectionState == ConnectionState.none)
                const SizedBox.shrink()
              else if (data == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (data.kpis.current.consumptions == 0)
                EmptyState(
                  icon: Icons.bar_chart_rounded,
                  message: l10n.statsNotEnoughData,
                )
              else
                _Sections(data: data),
            ],
          );
        },
      ),
    );
  }
}

class _Sections extends StatelessWidget {
  const _Sections({required this.data});

  final _StatsData data;

  /// Below this, an hour-by-hour split is a handful of lonely bars.
  static const _hourOfNightMinimum = 50;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);
    final figure = Theme.of(context).textTheme.headlineSmall;
    final current = data.kpis.current;
    final previous = data.kpis.previous;

    String? delta(int now, int? before) => previous == null
        ? null
        : settings.formatPercentChange(percentChange(now, before ?? 0));

    final volume = data.volume.buckets;
    final hourTotal = data.hours.fold(0, (sum, h) => sum + h.count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Expanded(
                child: StatTile(
                  label: l10n.statConsumptions,
                  delta: delta(current.consumptions, previous?.consumptions),
                  child: Text('${current.consumptions}', style: figure),
                ),
              ),
              Expanded(
                child: StatTile(
                  label: l10n.statActiveUsers,
                  delta: delta(current.activeUsers, previous?.activeUsers),
                  child: Text('${current.activeUsers}', style: figure),
                ),
              ),
              Expanded(
                child: StatTile(
                  label: l10n.statActiveDays,
                  delta: delta(current.activeDays, previous?.activeDays),
                  child: Text('${current.activeDays}', style: figure),
                ),
              ),
            ],
          ),
        ),
        StatsCard(
          icon: Icons.bar_chart_rounded,
          label: l10n.statsVolume,
          child: CountBarChart(
            counts: [for (final bucket in volume) bucket.count],
            labelOf: (i) => switch (data.volume.size) {
              BucketSize.day ||
              BucketSize.week => settings.formatDayMonth(volume[i].start),
              BucketSize.month => settings.formatMonthYear(volume[i].start),
            },
          ),
        ),
        if (data.topItems.isNotEmpty)
          StatsCard(
            icon: Icons.local_drink_outlined,
            label: l10n.statsTopItems,
            child: RankedBarList(
              entries: [
                for (final ranked in data.topItems)
                  RankedBar(
                    leading: AvatarCircle(emoji: ranked.item.emoji, size: 40),
                    label: ranked.item.name,
                    count: ranked.count,
                  ),
              ],
            ),
          ),
        if (hourTotal >= _hourOfNightMinimum)
          StatsCard(
            icon: Icons.nightlight_outlined,
            label: l10n.statsHourOfNight,
            child: CountBarChart(
              counts: [for (final hour in data.hours) hour.count],
              labelOf: (i) => settings.formatHour(data.hours[i].hour),
            ),
          ),
      ],
    );
  }
}
