import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../screens/camera_screen.dart';
import '../settings/app_settings.dart';
import '../utils/avatar_photo.dart';
import '../utils/camera_support.dart';
import 'emoji_picker_dialog.dart';
import 'money_text.dart';
import 'palette_picker.dart';
import 'top_up_sheet.dart';
import 'user_avatar.dart';
import 'user_theme_scope.dart';

/// Who this is, what they are up or down, a warning when that is too low, the
/// way to add money, and the way to their other page.
///
/// Shared by the consumption screen and the user's own page, which show the
/// same things and must not drift apart. Owns its balance query rather than
/// taking one, so a page drops it in and nothing else has to know.
///
/// Belongs inside a `UserThemeScope` — both callers are one.
class UserHeader extends StatefulWidget {
  const UserHeader({super.key, required this.user, required this.otherPage});

  final UserRow user;

  /// The button to the user's other page, beside Top up. Built by the caller,
  /// which knows where it is and so where the other page is.
  final Widget otherPage;

  @override
  State<UserHeader> createState() => _UserHeaderState();
}

class _UserHeaderState extends State<UserHeader> {
  late final Stream<int> _balance = Database.of(context).usersDao
      .watchBalance(widget.user.id);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        spacing: 8,
        children: [
          // AvatarCircle, not UserAvatar: this page is already inside the
          // user's theme, so the circle only has to read it.
          AvatarCircle(
            emoji: widget.user.avatarEmoji,
            image: widget.user.avatarImage,
            size: 88,
            onTap: () => unawaited(
              showDialog<void>(
                context: context,
                builder: (_) => _AvatarDialog(user: widget.user),
              ),
            ),
          ),
          Text(widget.user.name, style: theme.textTheme.headlineSmall),
          StreamBuilder<int>(
            stream: _balance,
            builder: (context, snapshot) {
              final balance = snapshot.data;
              // Strict, so a threshold of zero warns on a debt and not on a
              // settled tab. Warns, never blocks: the fridge cannot take
              // payment, so a recorded debt beats a drink left unlogged.
              final low =
                  settings.lowBalanceWarningEnabled &&
                  balance != null &&
                  balance < settings.lowBalanceThresholdMinorUnits;

              return Column(
                spacing: 8,
                children: [
                  // The query takes a frame or two to come back, and a zero
                  // shown in the meantime is a wrong number, not a missing one
                  // — someone reads it as their balance. Hidden rather than
                  // absent so the header does not resize underneath the
                  // button when it lands.
                  Opacity(
                    opacity: balance == null ? 0 : 1,
                    child: MoneyText(
                      amountMinorUnits: balance ?? 0,
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  if (low) const _LowBalanceStrip(),
                ],
              );
            },
          ),
          // A Wrap, so a phone too narrow for both puts one under the other.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add_card),
                label: Text(l10n.topUp),
                onPressed: () =>
                    unawaited(showTopUpSheet(context, user: widget.user)),
              ),
              widget.otherPage,
            ],
          ),
        ],
      ),
    );
  }
}

/// Tells a user under the threshold to top up. The amount is the large number
/// right above it, so it is not repeated.
class _LowBalanceStrip extends StatelessWidget {
  const _LowBalanceStrip();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        // Hugs its text, centred under the balance; wraps only when the line
        // is wider than the screen.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.onErrorContainer),
            Flexible(
              child: Text(
                AppLocalizations.of(context).lowBalanceBanner,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The avatar large, with the ways to change the face or the colour without
/// the full edit dialog. Stays open through every change and watches the user,
/// so each one shows straight away.
///
/// Deliberately not behind `allowUserEditing`: emoji, photo and colour are
/// cosmetic. Taking a photo is behind `allowProfilePhotos`, though.
class _AvatarDialog extends StatefulWidget {
  const _AvatarDialog({required this.user});

  final UserRow user;

  @override
  State<_AvatarDialog> createState() => _AvatarDialogState();
}

class _AvatarDialogState extends State<_AvatarDialog> {
  late final _dao = Database.of(context).usersDao;
  late final Stream<UserRow?> _user = _dao.watchUser(widget.user.id);

  /// Also how a photo is dropped: picking an emoji clears it in the same
  /// write, and backing out of the picker keeps it.
  Future<void> _changeEmoji(UserRow user) async {
    final picked = await showEmojiPickerDialog(context);
    if (picked == null) return;
    await _dao.updateUserAppearance(
      id: user.id,
      avatarEmoji: picked,
      avatarImage: const Value(null),
    );
  }

  Future<void> _takePhoto(UserRow user) async {
    final photo = await showCameraScreen(
      context,
      seedColorArgb: user.seedColorArgb,
    );
    if (photo == null) return;
    await _dao.updateUserAppearance(id: user.id, avatarImage: Value(photo));
  }

  Future<void> _changeColor(UserRow user) async {
    final picked = await showColorPickerDialog(
      context,
      selected: Color(user.seedColorArgb),
    );
    if (picked == null) return;
    await _dao.updateUserAppearance(
      id: user.id,
      seedColorArgb: picked.toARGB32(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final photos = canTakePhotos(AppSettings.of(context));
    // No more than twice the stored photo's pixels, which is about as far as
    // it upscales before it looks soft. Applies to an emoji too, so switching
    // between the two does not resize the dialog.
    final size = min(
      MediaQuery.sizeOf(context).width * 0.6,
      avatarPhotoSize * 2 / MediaQuery.devicePixelRatioOf(context),
    );
    // Taller than the default 40, for wet fingers.
    const style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size.fromHeight(56)),
    );

    return StreamBuilder<UserRow?>(
      stream: _user,
      builder: (context, snapshot) {
        final user = snapshot.data ?? widget.user;
        final hasPhoto = user.avatarImage != null;

        // A dialog route sits on the app's theme, not the page's.
        return UserThemeScope(
          seedColorArgb: user.seedColorArgb,
          child: AlertDialog(
            // Scrolls rather than overflows on a short screen.
            scrollable: true,
            content: SizedBox(
              width: size,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 12,
                children: [
                  AvatarCircle(
                    emoji: user.avatarEmoji,
                    image: user.avatarImage,
                    size: size,
                    onTap: () => Navigator.pop(context),
                  ),
                  OutlinedButton.icon(
                    style: style,
                    icon: const Icon(Icons.emoji_emotions_outlined),
                    label: Text(hasPhoto ? l10n.useEmoji : l10n.changeEmoji),
                    onPressed: () => unawaited(_changeEmoji(user)),
                  ),
                  if (photos)
                    OutlinedButton.icon(
                      style: style,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(hasPhoto ? l10n.retakePhoto : l10n.takePhoto),
                      onPressed: () => unawaited(_takePhoto(user)),
                    ),
                  OutlinedButton.icon(
                    style: style,
                    icon: const Icon(Icons.palette_outlined),
                    label: Text(l10n.changeColor),
                    onPressed: () => unawaited(_changeColor(user)),
                  ),
                  FilledButton(
                    style: style,
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.ok),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
