import 'package:flutter/material.dart';

import 'user_theme_scope.dart';

/// An emoji in a circle, tinted from the ambient theme.
///
/// Use this where the page is already inside the member's own
/// [UserThemeScope]; use [UserAvatar] anywhere else. Splitting the two keeps a
/// member's own page from installing their theme twice for one circle.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.emoji,
    this.size = 56,
    this.onTap,
  });

  final String emoji;

  /// Diameter. The glyph is sized from it, so the two cannot desync.
  final double size;

  /// Null leaves the circle inert, so display-only use needs no other widget.
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

/// A member's avatar on a page that is not theirs: brings their palette with
/// it, so a list on the app's theme still shows each member in their own
/// colour.
///
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
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => UserThemeScope(
    seedColorArgb: seedColorArgb,
    child: AvatarCircle(emoji: emoji, size: size, onTap: onTap),
  );
}
