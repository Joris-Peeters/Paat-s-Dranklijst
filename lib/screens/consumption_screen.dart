import 'dart:async';

import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import '../widgets/empty_state.dart';
import '../widgets/money_text.dart';
import '../widgets/responsive_tile_grid.dart';
import '../widgets/user_avatar.dart';
import '../widgets/user_theme_scope.dart';

/// How long the undo stays reachable. After this the row is permanent and only
/// an admin can void it.
const _undoWindow = Duration(seconds: 5);

/// Recording a drink: the screen the whole app exists for.
///
/// Everything below sits in the user's own theme, so the page they tap on is
/// unmistakably theirs.
class ConsumptionScreen extends StatefulWidget {
  const ConsumptionScreen({super.key, required this.user});

  final UserRow user;

  @override
  State<ConsumptionScreen> createState() => _ConsumptionScreenState();
}

class _ConsumptionScreenState extends State<ConsumptionScreen> {
  late final AppDatabase _db = Database.of(context);
  late final Stream<List<({ItemGroupRow group, List<ItemRow> items})>>
  _sections = _db.itemsDao.watchItemsByCategory();
  late final Stream<int> _balance = _db.usersDao.watchBalance(widget.user.id);

  /// Item id to how many of it. Empty and false means the ordinary one-tap
  /// flow; there is no decrement, so Cancel is the only way back out.
  final _basket = <int, int>{};
  bool _selecting = false;

  void _add(ItemRow item) =>
      setState(() => _basket.update(item.id, (n) => n + 1, ifAbsent: () => 1));

  void _startSelecting(ItemRow item) => setState(() {
    _selecting = true;
    _basket.update(item.id, (n) => n + 1, ifAbsent: () => 1);
  });

  void _cancelSelecting() => setState(() {
    _selecting = false;
    _basket.clear();
  });

  int _basketTotal(List<ItemRow> items) => items.fold(
    0,
    (sum, item) => sum + item.priceMinorUnits * (_basket[item.id] ?? 0),
  );

  int get _basketCount => _basket.values.fold(0, (sum, n) => sum + n);

  /// Both flows end the same way: write, leave, and offer the row back for five
  /// seconds. The messenger and navigator are taken *before* the await — after
  /// it this context is on its way out and neither lookup is safe.
  Future<void> _commit(
    Future<List<int>> Function() write,
    String Function(AppLocalizations l10n) message,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final dao = _db.transactionsDao;

    final ids = await write();
    navigator.pop();

    // MaterialApp owns the only messenger in the tree, so this outlives the
    // route that raised it.
    messenger.showSnackBar(
      SnackBar(
        content: Text(message(l10n)),
        duration: _undoWindow,
        // Load-bearing: a SnackBar carrying an action defaults to persisting
        // until it is tapped, and the expiry is the whole point here. The row
        // becomes permanent when this closes, so the window has to close on
        // its own.
        persist: false,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => unawaited(dao.undoConsumption(ids)),
        ),
      ),
    );
  }

  Future<void> _tap(ItemRow item) => _commit(
    () async => [
      await _db.transactionsDao.logConsumption(
        userId: widget.user.id,
        item: item,
      ),
    ],
    (l10n) => l10n.consumptionLogged(item.name, widget.user.name),
  );

  Future<void> _confirm(List<ItemRow> items) {
    final lines = [
      for (final item in items)
        if (_basket[item.id] case final quantity?)
          (item: item, quantity: quantity),
    ];
    final count = _basketCount;

    return _commit(
      () => _db.transactionsDao.logConsumptions(
        userId: widget.user.id,
        lines: lines,
      ),
      (l10n) => l10n.consumptionLoggedMultiple(count, widget.user.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return UserThemeScope(
      seedColorArgb: widget.user.seedColorArgb,
      child: StreamBuilder<List<({ItemGroupRow group, List<ItemRow> items})>>(
        stream: _sections,
        builder: (context, snapshot) {
          // Null only until the query resolves, which is a different thing from
          // resolving to nothing on offer.
          final loaded = snapshot.data;
          final sections =
              loaded ?? const <({ItemGroupRow group, List<ItemRow> items})>[];
          // Flattened once, so the basket's total and its lines can be read
          // without walking the sections again.
          final items = <ItemRow>[
            for (final section in sections) ...section.items,
          ];

          return PopScope(
            // Leaving with a basket open would discard it silently, so the
            // first back press clears the selection instead.
            canPop: !_selecting,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _cancelSelecting();
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text(widget.user.name),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.playlist_add),
                    tooltip: l10n.selectMultiple,
                    isSelected: _selecting,
                    // Visible because long-press is not: nobody finds a gesture
                    // they were never told about.
                    onPressed: _selecting
                        ? _cancelSelecting
                        : () => setState(() => _selecting = true),
                  ),
                ],
              ),
              // One scroll view over the header and the catalogue together, so
              // the avatar and balance scroll away rather than eating a third
              // of a phone screen while someone browses.
              body: loaded == null
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(user: widget.user, balance: _balance),
                          if (sections.isEmpty)
                            EmptyState(
                              icon: Icons.local_cafe,
                              message: l10n.noItemsYet,
                            )
                          else
                            _Catalogue(
                              sections: sections,
                              basket: _basket,
                              onTap: (item) => _selecting
                                  ? _add(item)
                                  : unawaited(_tap(item)),
                              onLongPress: (item) => _selecting
                                  ? _add(item)
                                  : _startSelecting(item),
                            ),
                        ],
                      ),
                    ),
              bottomNavigationBar: _selecting
                  ? _ConfirmBar(
                      count: _basketCount,
                      totalMinorUnits: _basketTotal(items),
                      onCancel: _cancelSelecting,
                      onConfirm: _basket.isEmpty
                          ? null
                          : () => unawaited(_confirm(items)),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.balance});

  final UserRow user;
  final Stream<int> balance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        spacing: 8,
        children: [
          // AvatarCircle, not UserAvatar: this page is already inside the
          // user's theme, so the circle only has to read it.
          AvatarCircle(emoji: user.avatarEmoji, size: 88),
          Text(user.name, style: theme.textTheme.headlineSmall),
          StreamBuilder<int>(
            stream: balance,
            builder: (context, snapshot) => MoneyText(
              amountMinorUnits: snapshot.data ?? 0,
              style: theme.textTheme.titleLarge,
            ),
          ),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.add_card),
            label: Text(l10n.topUp),
            // Wired up in the top-up step; disabled rather than pretending.
            onPressed: null,
          ),
        ],
      ),
    );
  }
}

class _Catalogue extends StatelessWidget {
  const _Catalogue({
    required this.sections,
    required this.basket,
    required this.onTap,
    required this.onLongPress,
  });

  final List<({ItemGroupRow group, List<ItemRow> items})> sections;
  final Map<int, int> basket;
  final ValueChanged<ItemRow> onTap;
  final ValueChanged<ItemRow> onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Not a scroll view of its own: the screen scrolls the header and this
    // together, so each grid here is just a section of that one scroll.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              section.group.emoji == null
                  ? section.group.name
                  : '${section.group.emoji}  ${section.group.name}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ResponsiveTileGrid(
            minTileWidth: 180,
            tileHeight: 168,
            // One section of a bigger scroll view, so it must not scroll.
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              for (final item in section.items)
                _ItemTile(
                  item: item,
                  count: basket[item.id],
                  onTap: () => onTap(item),
                  onLongPress: () => onLongPress(item),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.count,
    required this.onTap,
    required this.onLongPress,
  });

  final ItemRow item;

  /// Null while nothing of this item is in the basket.
  final int? count;

  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = this.count;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: count == null ? null : theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            // Centred explicitly rather than relying on how the Stack passes
            // constraints down: a shrink-wrapped column inside a Center lands
            // in the middle whatever height the tile ends up with.
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    AvatarCircle(emoji: item.emoji, size: 72),
                    Text(
                      item.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    MoneyText(
                      amountMinorUnits: item.priceMinorUnits,
                      // A price, not a balance: nobody is up or down by it.
                      colored: false,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            if (count != null)
              Positioned(
                top: 4,
                right: 4,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    '$count',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.count,
    required this.totalMinorUnits,
    required this.onCancel,
    required this.onConfirm,
  });

  final int count;
  final int totalMinorUnits;
  final VoidCallback onCancel;

  /// Null while the basket is empty, which is the state the toggle starts in.
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);
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
              l10n.basketSummary(count, settings.formatMoney(totalMinorUnits)),
              style: theme.textTheme.titleMedium,
            ),
          ),
          FilledButton(onPressed: onConfirm, child: Text(l10n.confirm)),
        ],
      ),
    );
  }
}
