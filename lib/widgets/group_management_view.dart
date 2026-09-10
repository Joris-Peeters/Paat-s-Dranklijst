import 'dart:async';

import 'package:flutter/material.dart';

import '../data/group_usage.dart';
import '../l10n/app_localizations.dart';
import 'confirm_dialog.dart';
import 'emoji_picker_dialog.dart';
import 'empty_state.dart';
import 'reorderable_sliver_section.dart';

/// One group as this screen needs it, flattened from whichever table it came
/// from. A plain record rather than a generic over drift's row types: user
/// groups and item categories share no supertype, and the two DAOs are
/// deliberately kept parallel rather than merged.
typedef GroupEntry = ({int id, String name, String? emoji, GroupUsage usage});

/// What a group dialog produced.
typedef GroupEdit = ({String name, String? emoji});

const _cardMargin = EdgeInsets.symmetric(horizontal: 16, vertical: 4);

/// The management list behind both "User groups" and "Categories".
///
/// The two screens must look identical, so they share this and differ only in
/// the DAO they wire to and the words they pass in.
class GroupManagementView extends StatelessWidget {
  const GroupManagementView({
    super.key,
    required this.title,
    required this.groups,
    required this.emptyMessage,
    required this.createLabel,
    required this.editLabel,
    required this.deleteLabel,
    required this.countLabel,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
    required this.onOpen,
  });

  final String title;
  final Stream<List<GroupEntry>> groups;

  final String emptyMessage;
  final String createLabel;
  final String editLabel;
  final String deleteLabel;

  /// Renders "3 members". A callback because members and items need different
  /// words for the same number. Counts only live rows: an archived one still
  /// pins the group, but saying so in every subtitle was more confusing than
  /// the one disabled delete it explains.
  final String Function(int count) countLabel;

  final Future<void> Function(GroupEdit edit) onCreate;
  final Future<void> Function(int id, GroupEdit edit) onEdit;
  final Future<void> Function(int id) onDelete;
  final Future<void> Function(List<int> idsInOrder) onReorder;

  /// Opens the group's contents.
  final void Function(GroupEntry group) onOpen;

  Future<void> _create(BuildContext context) async {
    final edit = await showGroupEditDialog(context, title: createLabel);
    if (edit != null) await onCreate(edit);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: StreamBuilder<List<GroupEntry>>(
      stream: groups,
      builder: (context, snapshot) {
        final entries = snapshot.data;
        // No spinner on the first frame: the query is local and resolves
        // within a frame or two, and a flash of one reads worse than nothing.
        if (entries == null) return const SizedBox.shrink();
        if (entries.isEmpty) {
          return EmptyState(
            icon: Icons.category_rounded,
            message: emptyMessage,
          );
        }
        return _GroupList(entries: entries, view: this);
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => unawaited(_create(context)),
      icon: const Icon(Icons.add),
      label: Text(createLabel),
    ),
  );
}

class _GroupList extends StatelessWidget {
  const _GroupList({required this.entries, required this.view});

  final List<GroupEntry> entries;
  final GroupManagementView view;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        // Room for the FAB to not cover the last row.
        padding: const EdgeInsets.only(top: 8, bottom: 88),
        sliver: ReorderableSliverSection<GroupEntry>(
          items: entries,
          keyOf: (entry) => ValueKey(entry.id),
          onReorder: (ordered) =>
              unawaited(view.onReorder([for (final e in ordered) e.id])),
          itemBuilder: (context, entry, index) =>
              _GroupTile(entry: entry, index: index, view: view),
        ),
      ),
    ],
  );
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.entry,
    required this.index,
    required this.view,
  });

  final GroupEntry entry;
  final int index;
  final GroupManagementView view;

  Future<void> _edit(BuildContext context) async {
    final edit = await showGroupEditDialog(
      context,
      title: view.editLabel,
      name: entry.name,
      emoji: entry.emoji,
    );
    if (edit != null) await view.onEdit(entry.id, edit);
  }

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: view.deleteLabel,
      message: l10n.deleteConfirm(entry.name),
      confirmLabel: l10n.delete,
    );
    if (confirmed) await view.onDelete(entry.id);
  }

  /// A disabled IconButton swallows the tap, so the delete stays live and only
  /// looks disabled — otherwise the reason it cannot be used has nowhere to go.
  void _explainBlocked(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.deleteBlockedInUse),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Archived rows count: they still carry a groupId, so a group can look
    // empty on screen while they pin it.
    final canDelete = entry.usage.total == 0;

    return Card(
      margin: _cardMargin,
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 8, right: 4),
        onTap: () => view.onOpen(entry),
        leading: SizedBox(
          width: 84,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DragHandle(index: index),
              _GroupEmoji(emoji: entry.emoji),
            ],
          ),
        ),
        title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(view.countLabel(entry.usage.activeCount)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.edit,
              onPressed: () => unawaited(_edit(context)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: canDelete
                  ? view.deleteLabel
                  : l10n.deleteBlockedInUse,
              color: canDelete ? null : theme.disabledColor,
              onPressed: canDelete
                  ? () => unawaited(_delete(context))
                  : () => _explainBlocked(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// A group's emoji, or a neutral stand-in. Group emoji are nullable on purpose
/// — an admin naming a group is choosing deliberately, not being handed a
/// random face like a new member is.
class _GroupEmoji extends StatelessWidget {
  const _GroupEmoji({required this.emoji});

  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final emoji = this.emoji;

    return SizedBox(
      width: 36,
      child: Center(
        child: emoji == null
            ? Icon(Icons.folder_outlined, color: colors.onSurfaceVariant)
            : Text(
                emoji,
                // Emoji fonts carry generous leading, and the glyph is drawn in
                // the text colour where no colour emoji font exists.
                style: TextStyle(
                  fontSize: 22,
                  color: colors.onSurface,
                  height: 1.0,
                ),
              ),
      ),
    );
  }
}

/// Creates or renames a group. Null when dismissed.
Future<GroupEdit?> showGroupEditDialog(
  BuildContext context, {
  required String title,
  String? name,
  String? emoji,
}) => showDialog<GroupEdit>(
  context: context,
  builder: (_) => _GroupEditDialog(title: title, name: name, emoji: emoji),
);

class _GroupEditDialog extends StatefulWidget {
  const _GroupEditDialog({required this.title, this.name, this.emoji});

  final String title;
  final String? name;
  final String? emoji;

  @override
  State<_GroupEditDialog> createState() => _GroupEditDialogState();
}

class _GroupEditDialogState extends State<_GroupEditDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.name,
  );
  late String? _emoji = widget.emoji;

  // Unlike the settings fields, which commit on blur, a dialog has a natural
  // commit point — so nothing is written until Save.
  bool get _canSave => _controller.text.trim().isNotEmpty;

  void _save() =>
      Navigator.pop(context, (name: _controller.text.trim(), emoji: _emoji));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: Row(
        spacing: 12,
        children: [
          EmojiPickerButton(
            emoji: _emoji,
            onPicked: (emoji) => setState(() => _emoji = emoji),
          ),
          if (_emoji != null)
            IconButton(
              icon: const Icon(Icons.backspace_outlined),
              tooltip: l10n.clearEmoji,
              onPressed: () => setState(() => _emoji = null),
            ),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.nameLabel,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_canSave) _save();
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
