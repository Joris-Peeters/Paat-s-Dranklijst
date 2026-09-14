import 'dart:async';

import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import '../widgets/empty_state.dart';
import '../widgets/low_balance_dialog.dart';
import '../widgets/money_text.dart';
import '../widgets/responsive_tile_grid.dart';
import '../widgets/top_up_sheet.dart';
import '../widgets/user_avatar.dart';
import '../widgets/user_header.dart';
import '../widgets/user_theme_scope.dart';
import 'user_detail_screen.dart';

/// Recording a drink: the screen the whole app exists for.
///
/// For one user everything below sits in their own theme, so the page they tap
/// on is unmistakably theirs. For several at once — one person fetching a round
/// — it stays on the app's theme, since the page belongs to nobody in
/// particular, and every drink is logged for each of them.
///
/// Pops with `true` once something was logged, so a caller can tell that apart
/// from backing out.
class ConsumptionScreen extends StatefulWidget {
  ConsumptionScreen({super.key, required UserRow user})
    : users = [user],
      _forGroup = false;

  const ConsumptionScreen.forUsers({super.key, required this.users})
    : _forGroup = true;

  final List<UserRow> users;
  final bool _forGroup;

  @override
  State<ConsumptionScreen> createState() => _ConsumptionScreenState();
}

class _ConsumptionScreenState extends State<ConsumptionScreen> {
  late final AppDatabase _db = Database.of(context);
  late final Stream<List<({ItemGroupRow group, List<ItemRow> items})>>
  _sections = _db.itemsDao.watchItemsByCategory();

  /// Item id to how many of it. Empty and false means the ordinary one-tap
  /// flow; there is no decrement, so Cancel is the only way back out.
  final _basket = <int, int>{};
  bool _selecting = false;

  /// The one user, outside a round.
  UserRow get _user => widget.users.single;

  List<int> get _userIds => [for (final user in widget.users) user.id];

  @override
  void initState() {
    super.initState();
    // Never for a round: a warning per person would stand between them and
    // every drink, and it is not their own tab being opened.
    if (widget._forGroup) return;
    // After the first frame: a dialog cannot be raised during a build, and the
    // inherited lookups below want a mounted context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_warnIfLow());
    });
  }

  /// Warns once, on the way in.
  ///
  /// A one-shot read rather than the balance stream: this is about where they
  /// stood when they arrived, and a balance moving while the screen is open —
  /// which every tap does — must not raise it again.
  Future<void> _warnIfLow() async {
    final settings = AppSettings.of(context);
    if (!settings.lowBalanceWarningEnabled) return;

    final balance = await _db.usersDao.readBalance(_user.id);
    // Strict, so a threshold of zero warns on a debt and not on a settled tab.
    if (balance >= settings.lowBalanceThresholdMinorUnits) return;
    if (!mounted) return;

    final topUp = await showLowBalanceDialog(
      context,
      user: _user,
      balanceMinorUnits: balance,
    );
    if (topUp && mounted) {
      await showTopUpSheet(context, user: _user);
    }
  }

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
    navigator.pop(true);

    // MaterialApp owns the only messenger in the tree, so this outlives the
    // route that raised it.
    messenger.showSnackBar(
      SnackBar(
        content: Text(message(l10n)),
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
    () => _db.transactionsDao.logConsumptionsForUsers(
      userIds: _userIds,
      lines: [(item: item, quantity: 1)],
    ),
    (l10n) => widget._forGroup
        ? l10n.consumptionLoggedForPeople(item.name, widget.users.length)
        : l10n.consumptionLogged(item.name, _user.name),
  );

  Future<void> _confirm(List<ItemRow> items) {
    final lines = [
      for (final item in items)
        if (_basket[item.id] case final quantity?)
          (item: item, quantity: quantity),
    ];
    final count = _basketCount;

    return _commit(
      () => _db.transactionsDao.logConsumptionsForUsers(
        userIds: _userIds,
        lines: lines,
      ),
      (l10n) => widget._forGroup
          ? l10n.consumptionLoggedMultipleForPeople(count, widget.users.length)
          : l10n.consumptionLoggedMultiple(count, _user.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _buildPage(context);
    return widget._forGroup
        ? page
        : UserThemeScope(seedColorArgb: _user.seedColorArgb, child: page);
  }

  Widget _buildPage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final forGroup = widget._forGroup;

    return StreamBuilder<List<({ItemGroupRow group, List<ItemRow> items})>>(
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
              title: Text(
                forGroup
                    ? l10n.takeSomethingForPeople(widget.users.length)
                    : l10n.takeSomething,
              ),
              actions: [
                if (!forGroup)
                  IconButton(
                    icon: const Icon(Icons.account_circle_outlined),
                    tooltip: l10n.userOverview,
                    // Replaces rather than pushes: two views of one user, both
                    // opened from the user list, so hopping between them must
                    // not stack up routes to back out of.
                    onPressed: () => unawaited(
                      Navigator.pushReplacement<void, void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserDetailScreen(user: _user),
                        ),
                      ),
                    ),
                  ),
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
            body: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Deliberately outside the catalogue's loading gate below.
                  // The header opens its own balance query when it mounts, so
                  // withholding it until the items arrive runs the two round
                  // trips one after the other and the balance lands visibly
                  // late.
                  if (forGroup)
                    _PeopleHeader(users: widget.users)
                  else
                    UserHeader(user: _user),
                  if (loaded == null)
                    const SizedBox.shrink()
                  else if (sections.isEmpty)
                    EmptyState(icon: Icons.local_cafe, message: l10n.noItemsYet)
                  else
                    _Catalogue(
                      sections: sections,
                      basket: _basket,
                      onTap: (item) =>
                          _selecting ? _add(item) : unawaited(_tap(item)),
                      onLongPress: (item) =>
                          _selecting ? _add(item) : _startSelecting(item),
                    ),
                ],
              ),
            ),
            bottomNavigationBar: _selecting
                ? _ConfirmBar(
                    count: _basketCount,
                    people: forGroup ? widget.users.length : null,
                    totalMinorUnits: _basketTotal(items) * widget.users.length,
                    onCancel: _cancelSelecting,
                    onConfirm: _basket.isEmpty
                        ? null
                        : () => unawaited(_confirm(items)),
                  )
                : null,
          ),
        );
      },
    );
  }
}

/// Who a round is for: each person's avatar and name, in their own colour.
class _PeopleHeader extends StatelessWidget {
  const _PeopleHeader({required this.users});

  final List<UserRow> users;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          for (final user in users)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                UserAvatar(
                  emoji: user.avatarEmoji,
                  seedColorArgb: user.seedColorArgb,
                  size: 40,
                ),
                Text(user.name, style: theme.textTheme.titleMedium),
              ],
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
    required this.people,
    required this.totalMinorUnits,
    required this.onCancel,
    required this.onConfirm,
  });

  final int count;

  /// How many people each item is for, or null outside a round.
  final int? people;

  /// Already multiplied out over everyone the order is for.
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
            child: Text(switch (people) {
              final people? => l10n.basketSummaryForPeople(
                count,
                people,
                settings.formatMoney(totalMinorUnits),
              ),
              null => l10n.basketSummary(
                count,
                settings.formatMoney(totalMinorUnits),
              ),
            }, style: theme.textTheme.titleMedium),
          ),
          FilledButton(onPressed: onConfirm, child: Text(l10n.confirm)),
        ],
      ),
    );
  }
}
