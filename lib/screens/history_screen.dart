import 'dart:async';

import 'package:flutter/material.dart';

import '../data/daos/transactions_dao.dart';
import '../data/daos/users_dao.dart';
import '../data/database.dart';
import '../data/database_provider.dart';
import '../data/logical_day.dart';
import '../data/tables/transactions_table.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import '../widgets/empty_state.dart';
import '../widgets/transaction_detail_dialog.dart';
import '../widgets/transaction_history.dart';
import '../widgets/user_avatar.dart';

/// What the history is narrowed to. All four are single-select, and null on
/// each means "everything".
typedef HistoryFilters = ({
  UserRow? user,
  ItemGroupRow? category,
  TransactionType? type,
  DateTimeRange? range,
});

const _emptyFilters =
    (user: null, category: null, type: null, range: null) as HistoryFilters;

/// How many more rows each pull from the bottom asks for.
const _pageSize = 50;

/// The whole ledger, newest first, with everything voided still in it.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.initialUser});

  /// Pre-applies the user filter, for the way in from a user's own page.
  final UserRow? initialUser;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final AppDatabase _db = Database.of(context);

  late HistoryFilters _filters = (
    user: widget.initialUser,
    category: null,
    type: null,
    range: null,
  );

  int _limit = _pageSize;

  // This screen re-subscribes — on every filter change and every page — which
  // a StreamBuilder would answer with a null frame, blanking the list each
  // time. Holding the rows here keeps the old ones on screen until the new
  // query lands. The only screen in the app that needs this.
  StreamSubscription<List<TransactionEntry>>? _subscription;
  List<TransactionEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    unawaited(_subscription?.cancel());
    _subscription = _db.transactionsDao
        .watchHistory(
          userId: _filters.user?.id,
          itemGroupId: _filters.category?.id,
          type: _filters.type,
          from: _filters.range?.start,
          to: _filters.range?.end,
          limit: _limit,
        )
        .listen((entries) => setState(() => _entries = entries));
  }

  void _apply(HistoryFilters filters) {
    setState(() {
      _filters = filters;
      // A narrower question deserves a fresh first page rather than however
      // deep the last one had been scrolled.
      _limit = _pageSize;
    });
    _subscribe();
  }

  /// Only worth asking for more once the current page came back full — a short
  /// page is the end of the ledger, and asking again would re-read it forever.
  bool _loadMore() {
    if ((_entries?.length ?? 0) < _limit) return false;
    setState(() => _limit += _pageSize);
    _subscribe();
    return true;
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = _entries;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.history),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: l10n.filters,
            onPressed: () => unawaited(_openFilters()),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterChips(filters: _filters, onChanged: _apply),
          Expanded(
            child: switch (entries) {
              // No spinner on the first frame: the query is local and a flash
              // of one reads worse than nothing.
              null => const SizedBox.shrink(),
              [] => EmptyState(
                icon: Icons.receipt_long,
                message: l10n.noTransactionsYet,
              ),
              _ => _HistoryList(
                entries: entries,
                showUser: _filters.user == null,
                onLoadMore: _loadMore,
              ),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openFilters() async {
    final applied = await showModalBottomSheet<HistoryFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FilterSheet(filters: _filters),
    );
    if (applied != null) _apply(applied);
  }
}

/// The active filters, each dismissible on its own. Nothing is shown while the
/// history is unfiltered — an empty strip of chrome is worse than none.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.filters, required this.onChanged});

  final HistoryFilters filters;
  final ValueChanged<HistoryFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);

    final chips = <Widget>[
      if (filters.user case final user?)
        InputChip(
          label: Text(user.name),
          onDeleted: () => onChanged((
            user: null,
            category: filters.category,
            type: filters.type,
            range: filters.range,
          )),
        ),
      if (filters.category case final category?)
        InputChip(
          label: Text(category.name),
          onDeleted: () => onChanged((
            user: filters.user,
            category: null,
            type: filters.type,
            range: filters.range,
          )),
        ),
      if (filters.type case final type?)
        InputChip(
          label: Text(transactionTypeLabel(l10n, type)),
          onDeleted: () => onChanged((
            user: filters.user,
            category: filters.category,
            type: null,
            range: filters.range,
          )),
        ),
      if (filters.range case final range?)
        InputChip(
          label: Text(
            l10n.dateRangeChip(
              settings.formatDate(range.start),
              settings.formatDate(range.end),
            ),
          ),
          onDeleted: () => onChanged((
            user: filters.user,
            category: filters.category,
            type: filters.type,
            range: null,
          )),
        ),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(spacing: 8, children: chips),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.entries,
    required this.showUser,
    required this.onLoadMore,
  });

  final List<TransactionEntry> entries;
  final bool showUser;

  /// Returns false once the ledger is exhausted, which stops the footer.
  final bool Function() onLoadMore;

  /// Grouped on the stored logical day, not the calendar date of `createdAt`:
  /// a drink at 01:00 belongs to the evening before, the way it does
  /// everywhere else in the app.
  List<({String day, List<TransactionEntry> entries})> get _days {
    final days = <({String day, List<TransactionEntry> entries})>[];
    for (final entry in entries) {
      final day = entry.transaction.logicalDate;
      if (days.isEmpty || days.last.day != day) {
        days.add((day: day, entries: [entry]));
      } else {
        days.last.entries.add(entry);
      }
    }
    return days;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          final metrics = notification.metrics;
          if (metrics.extentAfter < 400) onLoadMore();
          return false;
        },
        child: CustomScrollView(
          slivers: [
            for (final day in _days)
              // A group per day, so its header pins while that day is on screen
              // and is pushed off by the next one — sticky headers with nothing
              // added to pubspec.
              SliverMainAxisGroup(
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _DayHeader(day.day),
                  ),
                  SliverList.builder(
                    itemCount: day.entries.length,
                    itemBuilder: (context, index) {
                      final entry = day.entries[index];
                      void open() => unawaited(
                        showTransactionDetailDialog(context, entry: entry),
                      );

                      return showUser
                          ? TransactionListTile(entry: entry, onTap: open)
                          : TransactionListTile.forUser(
                              entry: entry,
                              onTap: open,
                            );
                    },
                  ),
                ],
              ),
          ],
        ),
      );
}

class _DayHeader extends SliverPersistentHeaderDelegate {
  const _DayHeader(this.day);

  final String day;

  static const _height = 40.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);

    return Container(
      height: _height,
      // Opaque: the rows scroll underneath it while it is pinned.
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        AppSettings.of(context).formatDate(logicalDayFromKey(day)),
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_DayHeader oldDelegate) => oldDelegate.day != day;
}

/// The name a transaction type goes by in the UI.
String transactionTypeLabel(AppLocalizations l10n, TransactionType type) =>
    switch (type) {
      TransactionType.consumption => l10n.transactionConsumption,
      TransactionType.topUp => l10n.transactionTopUp,
      TransactionType.adjustment => l10n.transactionAdjustment,
    };

/// All four filters at once. Edits a local copy and returns it whole, so
/// dismissing the sheet changes nothing.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.filters});

  final HistoryFilters filters;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late HistoryFilters _draft = widget.filters;

  late final Stream<List<ItemGroupRow>> _categories = Database.of(context)
      .itemsDao
      .watchItemGroups();

  Future<void> _pickUser() async {
    final picked = await showModalBottomSheet<({UserRow? user})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _UserPickerSheet(),
    );
    if (picked == null) return;
    setState(
      () => _draft = (
        user: picked.user,
        category: _draft.category,
        type: _draft.type,
        range: _draft.range,
      ),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      // The ledger cannot predate the app, and nothing is logged in the
      // future; a decade back is generous for a fridge.
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      initialDateRange: _draft.range,
    );
    if (picked == null) return;
    setState(
      () => _draft = (
        user: _draft.user,
        category: _draft.category,
        type: _draft.type,
        range: picked,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          Center(child: Text(l10n.filters, style: theme.textTheme.titleLarge)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.filterUser),
            // A hundred users is no dropdown, so this opens a searchable list.
            subtitle: Text(_draft.user?.name ?? l10n.filterEveryone),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => unawaited(_pickUser()),
          ),
          StreamBuilder<List<ItemGroupRow>>(
            stream: _categories,
            builder: (context, snapshot) {
              final categories = snapshot.data ?? const <ItemGroupRow>[];
              // The value has to be one of the items or the dropdown asserts,
              // which it is not on the first frame before the query resolves.
              final selected =
                  categories.any((c) => c.id == _draft.category?.id)
                  ? _draft.category?.id
                  : null;

              return DropdownButtonFormField<int?>(
                initialValue: selected,
                decoration: InputDecoration(
                  labelText: l10n.filterCategory,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.filterAll)),
                  for (final category in categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(
                        category.emoji == null
                            ? category.name
                            : '${category.emoji}  ${category.name}',
                      ),
                    ),
                ],
                onChanged: (id) => setState(
                  () => _draft = (
                    user: _draft.user,
                    category: id == null
                        ? null
                        : categories.firstWhere((c) => c.id == id),
                    type: _draft.type,
                    range: _draft.range,
                  ),
                ),
              );
            },
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(l10n.filterType, style: theme.textTheme.labelLarge),
              Wrap(
                spacing: 8,
                children: [
                  for (final type in [null, ...TransactionType.values])
                    ChoiceChip(
                      label: Text(
                        type == null
                            ? l10n.filterAll
                            : transactionTypeLabel(l10n, type),
                      ),
                      selected: _draft.type == type,
                      onSelected: (_) => setState(
                        () => _draft = (
                          user: _draft.user,
                          category: _draft.category,
                          type: type,
                          range: _draft.range,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.date_range),
            title: Text(l10n.filterDateRange),
            subtitle: Text(switch (_draft.range) {
              final range? => l10n.dateRangeChip(
                settings.formatDate(range.start),
                settings.formatDate(range.end),
              ),
              _ => l10n.filterAll,
            }),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => unawaited(_pickRange()),
          ),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, _emptyFilters),
                  child: Text(l10n.filterAll),
                ),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _draft),
                  child: Text(l10n.ok),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One user out of all of them, searchable.
///
/// Pops a record rather than the row, so "everyone" and "dismissed" stay
/// distinguishable — both would otherwise be a bare null.
class _UserPickerSheet extends StatefulWidget {
  const _UserPickerSheet();

  @override
  State<_UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends State<_UserPickerSheet> {
  late final Stream<List<UserWithBalance>> _users = Database.of(context)
      .usersDao
      .watchUsersWithBalances();

  final _controller = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final needle = _search.trim().toLowerCase();

    return Padding(
      padding: MediaQuery.viewInsetsOf(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.groups_rounded),
            title: Text(l10n.filterEveryone),
            onTap: () => Navigator.pop(context, (user: null)),
          ),
          const Divider(height: 1),
          Flexible(
            child: StreamBuilder<List<UserWithBalance>>(
              stream: _users,
              builder: (context, snapshot) {
                final all = snapshot.data;
                if (all == null) return const SizedBox.shrink();
                final users = [
                  for (final entry in all)
                    if (needle.isEmpty ||
                        entry.user.name.toLowerCase().contains(needle))
                      entry.user,
                ];

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      // This list runs on the app's theme, so each avatar
                      // brings the user's own colour with it.
                      leading: UserAvatar(
                        emoji: user.avatarEmoji,
                        seedColorArgb: user.seedColorArgb,
                        size: 40,
                      ),
                      title: Text(user.name),
                      onTap: () => Navigator.pop(context, (user: user)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
