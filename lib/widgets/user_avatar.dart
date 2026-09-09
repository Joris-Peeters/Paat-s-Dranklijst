import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A member's emoji in a circle tinted from their own seed colour.
///
/// The colour is never painted raw: wrapping the circle in a `Theme` means
/// everything inside, the ink splash included, picks up the member's palette.
/// Takes the emoji and colour loose rather than a `UserRow`, so the create
/// screen can use it before a row exists.
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
            // `height: 1.0` drops the font's generous leading, without which
            // Center visibly misses. The colour only shows where the platform
            // has no colour emoji font and draws an outline.
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
