import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A member's emoji in a circle tinted from *their* seed colour.
///
/// The colour is never painted raw: it goes through a `ColorScheme`, applied by
/// wrapping the circle in a `Theme` so everything inside — the ink splash
/// included — picks up the member's palette. See rule 4.
///
/// Takes the emoji and colour loose rather than a `UserRow`: the create screen
/// picks both before a row exists (rule 6).
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.emoji,
    required this.seedColorArgb,
    this.size = 56,
    this.onTap,
  });

  final String emoji;
  final int seedColorArgb;

  /// Diameter. The glyph is sized from it, so the two cannot desync.
  final double size;

  /// Null leaves the circle inert, so display-only use needs no other widget.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Theme(
    // Memoized, so a screen full of avatars is one map lookup each.
    data: appTheme(seedColorArgb, Theme.of(context).brightness),
    child: _AvatarCircle(emoji: emoji, size: size, onTap: onTap),
  );
}

/// Below the [Theme], so `Theme.of` here is the *member's* scheme.
class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.emoji,
    required this.size,
    required this.onTap,
  });

  final String emoji;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Material rather than a Container: it clips the ink splash to the circle.
    return Material(
      color: colors.primaryContainer,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            // `height: 1.0` drops the font's leading so the glyph box is the
            // font size and Center really centres it. The colour only shows
            // where the platform has no colour emoji font and draws an outline.
            child: Text(
              emoji,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: size * 0.55,
                color: colors.onPrimaryContainer,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
