import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/random_emoji.dart';
import 'emoji_picker_dialog.dart';
import 'full_screen_editor.dart';
import 'palette_picker.dart';
import 'user_avatar.dart';

/// Creates or edits one user. Closes on save; the caller's stream updates.
///
/// The same dialog does both jobs because they ask for the same four things —
/// there is no separate user settings screen anywhere in the app.
Future<void> showUserEditDialog(
  BuildContext context, {
  UserRow? user,
  int? presetGroupId,
}) => showDialog<void>(
  context: context,
  builder: (_) => UserEditDialog(user: user, presetGroupId: presetGroupId),
);

class UserEditDialog extends StatefulWidget {
  const UserEditDialog({super.key, this.user, this.presetGroupId});

  /// Null creates a new user.
  final UserRow? user;

  /// Pre-selects the group when creating from inside one.
  final int? presetGroupId;

  @override
  State<UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<UserEditDialog> {
  late final _controller = TextEditingController(text: widget.user?.name);

  // A new user is handed a face and a colour rather than starting blank, so
  // the two non-null columns always have a value and nobody has to choose
  // before they can save. Both are visible in the preview and freely changed.
  late String _emoji = widget.user?.avatarEmoji ?? randomAvatarEmoji();
  late int _seedColorArgb =
      widget.user?.seedColorArgb ?? _randomPaletteColor().toARGB32();
  late int? _groupId = widget.user?.groupId ?? widget.presetGroupId;

  static Color _randomPaletteColor() =>
      seedColorPalette[Random().nextInt(seedColorPalette.length)];

  bool get _canSave => _controller.text.trim().isNotEmpty && _groupId != null;

  Future<void> _pickEmoji() async {
    final picked = await showEmojiPickerDialog(context);
    if (picked != null && mounted) setState(() => _emoji = picked);
  }

  Future<void> _save() async {
    final dao = Database.of(context).usersDao;
    final name = _controller.text.trim();
    final groupId = _groupId!;
    final user = widget.user;
    final navigator = Navigator.of(context);

    if (user == null) {
      await dao.createUser(
        name: name,
        groupId: groupId,
        avatarEmoji: _emoji,
        seedColorArgb: _seedColorArgb,
      );
    } else {
      await dao.updateUserDetails(
        id: user.id,
        name: name,
        avatarEmoji: _emoji,
        seedColorArgb: _seedColorArgb,
        groupId: groupId,
      );
    }
    navigator.pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FullScreenEditor(
      title: widget.user == null ? l10n.newUser : l10n.editUser,
      onSave: _canSave ? () => unawaited(_save()) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 24,
        children: [
          Center(
            child: UserAvatar(
              emoji: _emoji,
              seedColorArgb: _seedColorArgb,
              size: 96,
              onTap: () => unawaited(_pickEmoji()),
            ),
          ),
          TextField(
            controller: _controller,
            autofocus: widget.user == null,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.nameLabel,
              border: const OutlineInputBorder(),
            ),
            // Save is enabled off the name, so every keystroke has to be seen.
            onChanged: (_) => setState(() {}),
          ),
          _GroupField(
            selected: _groupId,
            onSelected: (id) => setState(() => _groupId = id),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(
                l10n.colorLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              ColorPicker(
                selected: Color(_seedColorArgb),
                onSelected: (color) =>
                    setState(() => _seedColorArgb = color.toARGB32()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Always editable, even in create mode: moving a user between groups is an
/// ordinary correction, not a special operation.
class _GroupField extends StatefulWidget {
  const _GroupField({required this.selected, required this.onSelected});

  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  State<_GroupField> createState() => _GroupFieldState();
}

class _GroupFieldState extends State<_GroupField> {
  late final _groups = Database.of(context).usersDao.watchUserGroups();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<List<UserGroupRow>>(
      stream: _groups,
      builder: (context, snapshot) {
        final groups = snapshot.data ?? const <UserGroupRow>[];
        // The value has to be one of the items or the dropdown asserts, which
        // it is not on the first frame before the query resolves.
        final selected = groups.any((g) => g.id == widget.selected)
            ? widget.selected
            : null;

        return DropdownButtonFormField<int>(
          initialValue: selected,
          decoration: InputDecoration(
            labelText: l10n.groupLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final group in groups)
              DropdownMenuItem(
                value: group.id,
                child: Text(
                  group.emoji == null
                      ? group.name
                      : '${group.emoji}  ${group.name}',
                ),
              ),
          ],
          onChanged: (id) {
            if (id != null) widget.onSelected(id);
          },
        );
      },
    );
  }
}
