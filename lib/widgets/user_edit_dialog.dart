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
  bool canChangeGroup = true,
}) => showDialog<void>(
  context: context,
  builder: (_) => UserEditDialog(
    user: user,
    presetGroupId: presetGroupId,
    canChangeGroup: canChangeGroup,
  ),
);

class UserEditDialog extends StatefulWidget {
  const UserEditDialog({
    super.key,
    this.user,
    this.presetGroupId,
    this.canChangeGroup = true,
  });

  /// Null creates a new user.
  final UserRow? user;

  /// Pre-selects the group when creating from inside one.
  final int? presetGroupId;

  /// Whether an *existing* user may be moved to another group. Creating one is
  /// never gated by this: picking a first group is not switching groups, and
  /// the kiosk's own add button passes no preset, so a locked field there would
  /// leave Save unreachable.
  final bool canChangeGroup;

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

  /// Every other active user's name, lowercased.
  ///
  /// Held rather than queried per keystroke: under a hundred users this is one
  /// subscription and a set lookup, where an async check on each character
  /// would need debouncing to avoid racing itself.
  StreamSubscription<List<UserRow>>? _subscription;
  Set<String> _takenNames = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not initState: `Database.of` depends on an inherited widget. `??=` so a
    // later dependency change does not open a second subscription.
    //
    // Active users only, which is the whole point: a departed Wout should not
    // keep his name reserved.
    _subscription ??= Database.of(context).usersDao.watchUsers().listen(
      (users) => setState(() {
        _takenNames = {
          for (final user in users)
            // Someone is never a duplicate of themselves.
            if (user.id != widget.user?.id) user.name.trim().toLowerCase(),
        };
      }),
    );
  }

  static Color _randomPaletteColor() =>
      seedColorPalette[Random().nextInt(seedColorPalette.length)];

  bool get _canSave => _controller.text.trim().isNotEmpty && _groupId != null;

  /// A warning, never a refusal: two people really can share a name, and the
  /// schema deliberately allows it. This only makes sure nobody does it by
  /// accident. Dart's `toLowerCase` is full Unicode, so accented names fold too.
  bool get _nameIsTaken =>
      _takenNames.contains(_controller.text.trim().toLowerCase());

  /// Only an existing user can be *moved*; choosing a first group is not a
  /// move, so creating is never locked.
  bool get _groupIsLocked => widget.user != null && !widget.canChangeGroup;

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
    unawaited(_subscription?.cancel());
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
              // helperText, not errorText: nothing is being refused and Save
              // stays live. Only the colour says to look twice.
              helperText: _nameIsTaken ? l10n.nameTakenWarning : null,
              helperStyle: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
              border: const OutlineInputBorder(),
            ),
            // Save is enabled off the name, so every keystroke has to be seen.
            onChanged: (_) => setState(() {}),
          ),
          _GroupField(
            selected: _groupId,
            locked: _groupIsLocked,
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

/// The group a user belongs to.
///
/// Shown even when it cannot be changed, rather than hidden: which group
/// someone is in is worth reading whether or not it can be edited here.
class _GroupField extends StatefulWidget {
  const _GroupField({
    required this.selected,
    required this.locked,
    required this.onSelected,
  });

  final int? selected;

  /// Renders the field inert. A null `onChanged` is Material's own read-only
  /// state for a dropdown: still labelled and legible, just greyed.
  final bool locked;

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
          onChanged: widget.locked
              ? null
              : (id) {
                  if (id != null) widget.onSelected(id);
                },
        );
      },
    );
  }
}
