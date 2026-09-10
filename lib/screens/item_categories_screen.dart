// Only Value: drift also exports a `Column`, which would shadow the widget.
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../data/daos/items_dao.dart';
import '../data/database.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/group_management_view.dart';
import 'item_category_contents_screen.dart';

/// The categories drinks and snacks are organised into.
class ItemCategoriesScreen extends StatefulWidget {
  const ItemCategoriesScreen({super.key});

  @override
  State<ItemCategoriesScreen> createState() => _ItemCategoriesScreenState();
}

class _ItemCategoriesScreenState extends State<ItemCategoriesScreen> {
  // Built once; see the note in UserGroupsScreen.
  late final ItemsDao _dao = Database.of(context).itemsDao;
  late final Stream<List<GroupEntry>> _groups = _dao
      .watchItemGroupsWithUsage()
      .map(
        (rows) => [
          for (final row in rows)
            (
              id: row.group.id,
              name: row.group.name,
              emoji: row.group.emoji,
              usage: row.usage,
            ),
        ],
      );

  /// The view deals in flattened records, so the row itself is re-read here —
  /// the contents screen wants the category's own name and emoji for its title.
  Future<void> _open(int groupId) async {
    final group = await _dao.readItemGroup(groupId);
    if (group == null || !mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemCategoryContentsScreen(group: group),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return GroupManagementView(
      title: l10n.itemCategories,
      groups: _groups,
      emptyMessage: l10n.noCategoriesYet,
      createLabel: l10n.newCategory,
      editLabel: l10n.editCategory,
      deleteLabel: l10n.deleteCategory,
      countLabel: l10n.categoryItemCount,
      onCreate: (edit) async =>
          _dao.createItemGroup(name: edit.name, emoji: edit.emoji),
      onEdit: (id, edit) => _dao.updateItemGroup(
        id,
        ItemGroupsCompanion(name: Value(edit.name), emoji: Value(edit.emoji)),
      ),
      onDelete: _dao.deleteItemGroup,
      onReorder: _dao.reorderItemGroups,
      onOpen: (group) => unawaited(_open(group.id)),
    );
  }
}
