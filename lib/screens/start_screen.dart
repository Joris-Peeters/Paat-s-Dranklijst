import 'dart:async';

import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/database_provider.dart';
import '../data/logical_day.dart';
import '../l10n/app_localizations.dart';
import '../widgets/card_heading.dart';
import '../widgets/money_text.dart';
import '../widgets/transaction_history.dart';
import 'settings_screen.dart';

/// The screen the fridge sits on all day: how today is going, and one large
/// way through to the user list.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key, required this.onOpenUsers});

  /// Switches to the Users tab. A callback rather than a push: that page is a
  /// tab of the shell, and pushing it would stack a second copy over the
  /// navigation bar.
  final VoidCallback onOpenUsers;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> with WidgetsBindingObserver {
  late final AppDatabase _db = Database.of(context);

  /// The logical day the figures below are for. A stream resolves its day once,
  /// at subscription, so this is what has to change for them to move on.
  late String _day = logicalDayKey(DateTime.now());
  late Stream<({int quantity, int turnoverMinorUnits})> _totals = _watch();

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A kiosk is never reloaded, so nothing else would ever notice 07:00
    // arriving. Cheap: all but one tick a day is a string compare.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => _rollOver());
  }

  Stream<({int quantity, int turnoverMinorUnits})> _watch() =>
      _db.transactionsDao.watchDayTotals(at: DateTime.now());

  /// Re-subscribes only when the day has actually turned over.
  void _rollOver() {
    final day = logicalDayKey(DateTime.now());
    if (day == _day) return;
    setState(() {
      _day = day;
      _totals = _watch();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A tablet that slept through 07:00 has a ticker that did not fire.
    if (state == AppLifecycleState.resumed) _rollOver();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navStart),
        actions: [
          // Settings hang off the Start page only.
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: l10n.settings,
            onPressed: () => openSettings(context),
          ),
        ],
      ),
      body: SafeArea(
        // `spacing` only puts gaps between children, so the filled card would
        // otherwise end flush against the navigation bar.
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              _TodayCard(totals: _totals),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FilledButton.icon(
                  onPressed: widget.onOpenUsers,
                  icon: const Icon(Icons.people_rounded, size: 32),
                  label: Text(
                    l10n.chooseYourName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  // The one thing anyone comes to this screen to do, tapped with
                  // cold wet fingers on a fridge door.
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(96),
                  ),
                ),
              ),
              // No user, so the global form: avatars and names, and a footer that
              // opens the unfiltered history.
              const Expanded(
                child: RecentTransactionsCard(fill: true, limit: 30),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.totals});

  final Stream<({int quantity, int turnoverMinorUnits})> totals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardHeading(icon: Icons.today, label: l10n.today),
            StreamBuilder<({int quantity, int turnoverMinorUnits})>(
              stream: totals,
              builder: (context, snapshot) {
                final totals = snapshot.data;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: _Stat(
                          label: l10n.statConsumptions,
                          // Hidden rather than absent until the query lands, so
                          // the card does not resize under a finger.
                          ready: totals != null,
                          child: Text(
                            '${totals?.quantity ?? 0}',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _Stat(
                          label: l10n.statTurnover,
                          ready: totals != null,
                          child: MoneyText(
                            amountMinorUnits: totals?.turnoverMinorUnits ?? 0,
                            // Money taken, not a balance: nobody is up by it.
                            colored: false,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.ready, required this.child});

  final String label;
  final bool ready;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          spacing: 4,
          children: [
            Opacity(opacity: ready ? 1 : 0, child: child),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
