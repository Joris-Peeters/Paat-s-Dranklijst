import 'dart:async';
import 'dart:math';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'user_avatar.dart';

/// Asks for an emoji. Resolves to the chosen glyph, or null if dismissed.
Future<String?> showEmojiPickerDialog(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (_) => const EmojiPickerDialog(),
    );

// AlertDialog's own default horizontal inset, so the grid can never ask to be
// wider than the dialog is allowed to be.
const _dialogInset = 40.0;
const _maxWidth = 420.0;
const _maxHeight = 400.0;

// 7 rather than the package's 10: at _maxWidth that is a ~60px target per
// emoji, the same order as the 56px colour swatches, which is what cold wet
// fingers on a fridge door need.
const _columns = 7;
const _emojiSizeMax = 32.0;

/// The package's emoji grid in a dialog, popping the tapped emoji — no confirm
/// button, like `ColorPickerDialog`.
///
/// The package paints from explicit `Color`s and ignores the ambient theme, so
/// every colour below has to be threaded in by hand.
class EmojiPickerDialog extends StatelessWidget {
  const EmojiPickerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final screen = MediaQuery.sizeOf(context);

    return AlertDialog(
      title: Text(l10n.chooseEmoji),
      // The grid brings its own padding; the dialog's would only narrow it.
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        // The grid measures itself off `constraints.maxWidth`, and an
        // AlertDialog only offers a loose width. Give it a definite one.
        width: min(screen.width - _dialogInset * 2, _maxWidth),
        child: EmojiPicker(
          onEmojiSelected: (_, emoji) => Navigator.pop(context, emoji.emoji),
          config: Config(
            // The package wraps itself in a SizedBox of this height.
            height: min(screen.height * 0.5, _maxHeight),
            // The check renders every emoji once at startup to drop the ones
            // the platform font lacks — too slow on a cheap tablet. Android
            // and iOS always ship a font, and a Linux kiosk image is expected
            // to have one installed.
            checkPlatformCompatibility: false,
            // No fontSize: this is merged over a style that already carries the
            // responsive per-cell size, and setting one would freeze it.
            emojiTextStyle: TextStyle(color: colors.onSurface, height: 1.0),
            emojiViewConfig: const EmojiViewConfig(
              columns: _columns,
              emojiSizeMax: _emojiSizeMax,
              // Transparent so the dialog's own rounded surface shows through
              // instead of a square panel clipped by its corners.
              backgroundColor: Colors.transparent,
              gridPadding: EdgeInsets.symmetric(horizontal: 8),
              loadingIndicator: Center(child: CircularProgressIndicator()),
            ),
            categoryViewConfig: CategoryViewConfig(
              // No "recently used" list.
              recentTabBehavior: RecentTabBehavior.NONE,
              // Must be set: the package's default is the tab just removed.
              initCategory: Category.SMILEYS,
              backgroundColor: Colors.transparent,
              iconColor: colors.onSurfaceVariant,
              iconColorSelected: colors.primary,
              indicatorColor: colors.primary,
              dividerColor: colors.outlineVariant,
            ),
            // Drops the backspace and search buttons, and the bar itself.
            bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
            // Long-press is a poor kiosk gesture, and one tone per avatar is
            // enough — the grid's base glyphs stay tappable.
            skinToneConfig: const SkinToneConfig(enabled: false),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

/// A circle showing the current emoji that opens the picker when tapped.
///
/// Clearing is left to the caller: group emoji are nullable but member and item
/// emoji are not, so a built-in clear affordance would be wrong half the time.
class EmojiPickerButton extends StatelessWidget {
  const EmojiPickerButton({
    super.key,
    required this.emoji,
    required this.onPicked,
    this.size = 56,
  });

  /// Null renders the placeholder rather than a glyph.
  final String? emoji;

  /// Not called when the picker is dismissed.
  final ValueChanged<String> onPicked;

  final double size;

  Future<void> _pick(BuildContext context) async {
    final picked = await showEmojiPickerDialog(context);
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final emoji = this.emoji;
    void onTap() => unawaited(_pick(context));

    return Tooltip(
      message: l10n.chooseEmoji,
      // The glyph case reuses the avatar circle rather than restyling an emoji
      // here: the leading and colour it needs are fiddly and belong in one
      // place. The placeholder is an Icon, which takes its colour from
      // IconTheme and needs none of that care.
      child: emoji != null
          ? AvatarCircle(emoji: emoji, size: size, onTap: onTap)
          : _EmojiPlaceholder(size: size, onTap: onTap),
    );
  }
}

class _EmojiPlaceholder extends StatelessWidget {
  const _EmojiPlaceholder({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerHighest,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Icon(
              Icons.add_reaction_outlined,
              size: size * 0.5,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
