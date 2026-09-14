import 'package:flutter/material.dart';

import '../data/daos/users_dao.dart';
import '../data/database.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import '../widgets/empty_state.dart';
import '../widgets/money_text.dart';
import '../widgets/user_avatar.dart';

/// Wide enough for a long name beside an amount; any wider and a screenshot on
/// a tablet puts them a whole screen apart.
const _maxCardWidth = 520.0;

/// Everyone who owes money, most first, laid out to be screenshotted and
/// shared with the group.
class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  late final UsersDao _dao = Database.of(context).usersDao;
  late final Stream<List<UserGroupRow>> _groups = _dao.watchUserGroups();

  // Every group at once, filtered below, so switching chips costs nothing.
  late final Stream<List<UserWithBalance>> _debtors = _dao.watchDebtors();

  /// Null shows every group.
  int? _groupId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.debts)),
      body: StreamBuilder<List<UserGroupRow>>(
        stream: _groups,
        builder: (context, groupsSnapshot) =>
            StreamBuilder<List<UserWithBalance>>(
              stream: _debtors,
              builder: (context, debtorsSnapshot) {
                final groups = groupsSnapshot.data;
                final debtors = debtorsSnapshot.data;
                if (groups == null || debtors == null) {
                  return const SizedBox.shrink();
                }

                // A group deleted while selected falls back to all of them.
                final group = groups.where((g) => g.id == _groupId).firstOrNull;
                final visible = [
                  for (final d in debtors)
                    if (group == null || d.user.groupId == group.id) d,
                ];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GroupChips(
                      groups: groups,
                      selectedId: group?.id,
                      onSelected: (id) => setState(() => _groupId = id),
                    ),
                    Expanded(
                      child: visible.isEmpty
                          ? EmptyState(
                              icon: Icons.sentiment_satisfied_rounded,
                              message: l10n.noDebts,
                            )
                          : _DebtList(group: group, debtors: visible),
                    ),
                  ],
                );
              },
            ),
      ),
    );
  }
}

class _GroupChips extends StatelessWidget {
  const _GroupChips({
    required this.groups,
    required this.selectedId,
    required this.onSelected,
  });

  final List<UserGroupRow> groups;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        spacing: 8,
        children: [
          ChoiceChip(
            label: Text(l10n.filterAllGroups),
            selected: selectedId == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final group in groups)
            ChoiceChip(
              label: Text(_groupLabel(group)),
              selected: group.id == selectedId,
              onSelected: (_) => onSelected(group.id),
            ),
        ],
      ),
    );
  }
}

String _groupLabel(UserGroupRow group) =>
    group.emoji == null ? group.name : '${group.emoji}  ${group.name}';

/// One card holding a header and a row per debtor: the part worth cropping
/// out of a screenshot.
class _DebtList extends StatelessWidget {
  const _DebtList({required this.group, required this.debtors});

  final UserGroupRow? group;
  final List<UserWithBalance> debtors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = AppSettings.of(context);
    final group = this.group;
    final total = debtors.fold(0, (sum, d) => sum + d.balanceMinorUnits);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxCardWidth),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    group == null ? l10n.debts : _groupLabel(group),
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    l10n.debtsHeader(
                      settings.formatDate(DateTime.now()),
                      debtors.length,
                      settings.formatMoney(total),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final debtor in debtors) _DebtRow(entry: debtor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({required this.entry});

  final UserWithBalance entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = entry.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        spacing: 12,
        children: [
          UserAvatar(
            emoji: user.avatarEmoji,
            seedColorArgb: user.seedColorArgb,
            size: 28,
          ),
          Expanded(
            child: Text(
              user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          MoneyText(
            amountMinorUnits: entry.balanceMinorUnits,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
