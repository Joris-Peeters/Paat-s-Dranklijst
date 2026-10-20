import 'dart:async';

import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import 'emoji_picker_dialog.dart';
import 'money_text.dart';
import 'palette_picker.dart';
import 'top_up_sheet.dart';
import 'user_avatar.dart';

/// Who this is, what they are up or down, and the way to add money.
///
/// Shared by the consumption screen and the user's own page, which show the
/// same four things and must not drift apart. Owns its balance query rather
/// than taking one, so a page drops it in and nothing else has to know.
///
/// Belongs inside a `UserThemeScope` — both callers are one.
class UserHeader extends StatefulWidget {
  const UserHeader({super.key, required this.user});

  final UserRow user;

  @override
  State<UserHeader> createState() => _UserHeaderState();
}

class _UserHeaderState extends State<UserHeader> {
  late final Stream<int> _balance = Database.of(context).usersDao
      .watchBalance(widget.user.id);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        spacing: 8,
        children: [
          _AvatarMenu(user: widget.user),
          Text(widget.user.name, style: theme.textTheme.headlineSmall),
          StreamBuilder<int>(
            stream: _balance,
            builder: (context, snapshot) {
              final balance = snapshot.data;
              // The query takes a frame or two to come back, and a zero shown
              // in the meantime is a wrong number, not a missing one — someone
              // reads it as their balance. Hidden rather than absent so the
              // header does not resize underneath the button when it lands.
              return Opacity(
                opacity: balance == null ? 0 : 1,
                child: MoneyText(
                  amountMinorUnits: balance ?? 0,
                  style: theme.textTheme.headlineMedium,
                ),
              );
            },
          ),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.add_card),
            label: Text(l10n.topUp),
            onPressed: () =>
                unawaited(showTopUpSheet(context, user: widget.user)),
          ),
        ],
      ),
    );
  }
}

/// The big avatar, opening a menu to change the emoji or the colour without
/// going through the full edit dialog.
///
/// Deliberately not behind `allowUserEditing`: emoji and colour are cosmetic.
class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu({required this.user});

  final UserRow user;

  Future<void> _changeEmoji(BuildContext context) async {
    final dao = Database.of(context).usersDao;
    final picked = await showEmojiPickerDialog(context);
    if (picked == null) return;
    await dao.updateUserAppearance(id: user.id, avatarEmoji: picked);
  }

  Future<void> _changeColor(BuildContext context) async {
    final dao = Database.of(context).usersDao;
    final picked = await showColorPickerDialog(
      context,
      selected: Color(user.seedColorArgb),
    );
    if (picked == null) return;
    await dao.updateUserAppearance(
      id: user.id,
      seedColorArgb: picked.toARGB32(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Taller than the default 48, for wet fingers.
    final itemStyle = MenuItemButton.styleFrom(minimumSize: const Size(0, 56));

    // Each item uses this widget's context for its dialog, not its own: the
    // menu closes on the tap, taking the items' contexts with it.
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          style: itemStyle,
          leadingIcon: const Icon(Icons.emoji_emotions_outlined),
          onPressed: () => unawaited(_changeEmoji(context)),
          child: Text(l10n.changeEmoji),
        ),
        MenuItemButton(
          style: itemStyle,
          leadingIcon: const Icon(Icons.palette_outlined),
          onPressed: () => unawaited(_changeColor(context)),
          child: Text(l10n.changeColor),
        ),
      ],
      // AvatarCircle, not UserAvatar: this page is already inside the user's
      // theme, so the circle only has to read it.
      builder: (context, controller, _) => AvatarCircle(
        emoji: user.avatarEmoji,
        size: 88,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
