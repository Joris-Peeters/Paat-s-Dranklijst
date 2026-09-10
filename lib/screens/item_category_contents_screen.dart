import 'dart:async';

import 'package:flutter/material.dart';

import '../data/daos/items_dao.dart';
import '../data/database.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/item_edit_dialog.dart';
import '../widgets/reorderable_sliver_section.dart';

const _cardMargin = EdgeInsets.symmetric(horizontal: 16, vertical: 4);

/// The items in one category, in the order they appear on the fridge.
class ItemCategoryContentsScreen extends StatefulWidget {
  const ItemCategoryContentsScreen({super.key, required this.group});

  final ItemGroupRow group;

  @override
  State<ItemCategoryContentsScreen> createState() =>
      _ItemCategoryContentsScreenState();
}

class _ItemCategoryContentsScreenState
    extends State<ItemCategoryContentsScreen> {
  late final ItemsDao _dao = Database.of(context).itemsDao;

  // Subscribed once, archived rows included, and partitioned below; see the
  // note in UserGroupContentsScreen.
  late final Stream<List<ItemRow>> _items = _dao.watchItemsInGroup(
    widget.group.id,
    includeArchived: true,
  );

  Future<void> _archive(ItemRow item) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.archive,
      message: l10n.archiveItemConfirm(item.name),
      confirmLabel: l10n.archive,
    );
    if (confirmed) await _dao.archiveItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final emoji = widget.group.emoji;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          emoji == null ? widget.group.name : '$emoji  ${widget.group.name}',
        ),
      ),
      body: StreamBuilder<List<ItemRow>>(
        stream: _items,
        builder: (context, snapshot) {
          final items = snapshot.data;
          if (items == null) return const SizedBox.shrink();

          final active = [
            for (final i in items)
              if (i.archivedAt == null) i,
          ];
          final archived = [
            for (final i in items)
              if (i.archivedAt != null) i,
          ];

          if (active.isEmpty && archived.isEmpty) {
            return EmptyState(
              icon: Icons.local_cafe,
              message: l10n.noItemsInCategory,
            );
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(top: 8),
                sliver: ReorderableSliverSection<ItemRow>(
                  items: active,
                  keyOf: (item) => ValueKey(item.id),
                  onReorder: (ordered) => unawaited(
                    _dao.reorderItems(
                      groupId: widget.group.id,
                      idsInOrder: [for (final i in ordered) i.id],
                    ),
                  ),
                  itemBuilder: (context, item, index) => _ItemTile(
                    item: item,
                    index: index,
                    onArchive: () => unawaited(_archive(item)),
                  ),
                ),
              ),
              if (archived.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(title: l10n.archivedSection),
                ),
                SliverList.builder(
                  itemCount: archived.length,
                  itemBuilder: (context, index) => _ItemTile(
                    item: archived[index],
                    onRestore: () =>
                        unawaited(_dao.restoreItem(archived[index].id)),
                  ),
                ),
              ],
              // Room for the FAB to not cover the last row.
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(
          showItemEditDialog(context, presetGroupId: widget.group.id),
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.newItem),
      ),
    );
  }
}

/// One item. Archived when [onRestore] is given instead of [onArchive]: no drag
/// handle then, and dimmed. There is no archive guard here — an item holds no
/// money, so retiring one has no precondition to check.
class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    this.index,
    this.onArchive,
    this.onRestore,
  });

  final ItemRow item;
  final int? index;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;

  bool get _archived => onRestore != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final index = this.index;

    final tile = Card(
      margin: _cardMargin,
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 8, right: 4),
        leading: SizedBox(
          width: 48,
          child: index == null ? null : DragHandle(index: index),
        ),
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        // The current price. Past transactions keep their own frozen copy, so
        // this is what it costs now, not what anyone paid.
        subtitle: Text(
          AppSettings.of(context).formatMoney(item.priceMinorUnits),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.edit,
              onPressed: () =>
                  unawaited(showItemEditDialog(context, item: item)),
            ),
            if (_archived)
              IconButton(
                icon: const Icon(Icons.unarchive_outlined),
                tooltip: l10n.unarchive,
                onPressed: onRestore,
              )
            else
              IconButton(
                icon: const Icon(Icons.archive_outlined),
                tooltip: l10n.archive,
                onPressed: onArchive,
              ),
          ],
        ),
      ),
    );

    return _archived ? Opacity(opacity: 0.5, child: tile) : tile;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
