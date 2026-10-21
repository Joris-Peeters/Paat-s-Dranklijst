import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'user_theme_scope.dart';

/// Width of the coloured ring around a photo of [size].
double avatarRingWidth(double size) => max(2, size / 24);

/// An emoji in a circle, tinted from the ambient theme, or a photo ringed in
/// the theme's primary colour when [image] is set.
///
/// Use this where the page is already inside the user's own
/// [UserThemeScope]; use [UserAvatar] anywhere else. Splitting the two keeps a
/// user's own page from installing their theme twice for one circle.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.emoji,
    this.image,
    this.size = 56,
    this.onTap,
  });

  final String emoji;

  /// An encoded photo, drawn instead of [emoji].
  final Uint8List? image;

  /// Diameter. The glyph is sized from it, so the two cannot desync.
  final double size;

  /// Null leaves the circle inert, so display-only use needs no other widget.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final image = this.image;

    // Material rather than a Container: it clips the ink splash to the circle.
    return Material(
      color: image == null ? colors.primaryContainer : colors.primary,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: image == null
          ? InkWell(
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Center(
                  // `height: 1.0` drops the font's generous leading, without
                  // which Center visibly misses. The colour only shows where
                  // the platform has no colour emoji font and draws an
                  // outline.
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
            )
          // Ink rather than an Image child: it paints on the Material, so the
          // splash still shows on top of the photo.
          : Ink(
              width: size,
              height: size,
              decoration: ShapeDecoration(
                shape: CircleBorder(
                  side: BorderSide(
                    color: colors.primary,
                    width: avatarRingWidth(size),
                  ),
                ),
                image: DecorationImage(
                  fit: BoxFit.cover,
                  // Decoded at the size it is drawn, so a list of small
                  // avatars does not hold full-size bitmaps.
                  image: ResizeImage.resizeIfNeeded(
                    (size * MediaQuery.devicePixelRatioOf(context)).round(),
                    null,
                    AvatarPhotoImage(image),
                  ),
                ),
              ),
              child: InkWell(onTap: onTap, customBorder: const CircleBorder()),
            ),
    );
  }
}

/// A [MemoryImage] that compares by content rather than by identity.
///
/// User lists re-emit on every ledger write, each time with fresh byte
/// arrays. By identity, every avatar on screen would miss the image cache and
/// be decoded again on every tap at the fridge.
@immutable
class AvatarPhotoImage extends MemoryImage {
  AvatarPhotoImage(super.bytes) : _hash = _sampleHash(bytes);

  final int _hash;

  /// Length and an even spread of bytes: cheap, and equal for equal content.
  static int _sampleHash(Uint8List bytes) {
    const samples = 32;
    final step = max(1, bytes.length ~/ samples);
    return Object.hash(
      bytes.length,
      Object.hashAll([for (var i = 0; i < bytes.length; i += step) bytes[i]]),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarPhotoImage &&
      other._hash == _hash &&
      other.scale == scale &&
      listEquals(other.bytes, bytes);

  @override
  int get hashCode => Object.hash(_hash, scale);
}

/// A user's avatar on a page that is not theirs: brings their palette with
/// it, so a list on the app's theme still shows each user in their own
/// colour.
///
/// Takes the emoji, photo and colour loose rather than a `UserRow`, so the
/// create screen can use it before a row exists.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.emoji,
    required this.seedColorArgb,
    this.image,
    this.size = 56,
    this.onTap,
  });

  final String emoji;
  final int seedColorArgb;
  final Uint8List? image;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => UserThemeScope(
    seedColorArgb: seedColorArgb,
    child: AvatarCircle(emoji: emoji, image: image, size: size, onTap: onTap),
  );
}
