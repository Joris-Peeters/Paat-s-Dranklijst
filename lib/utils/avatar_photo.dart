import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Edge length of a stored profile photo, in pixels.
///
/// Covers the largest avatar on screen at a phone's pixel density, while a
/// JPEG of it stays a few tens of kilobytes in the database.
const avatarPhotoSize = 384;

/// Turns a camera capture into the square JPEG a user row stores.
///
/// Keeps the centre square, which is what the circular preview showed.
/// Throws a [FormatException] when [captured] is not an image.
Uint8List processAvatarPhoto(Uint8List captured) {
  final decoded = img.decodeImage(captured);
  if (decoded == null) {
    throw const FormatException('Not a decodable image');
  }
  // Phone cameras store pixels sideways and record the rotation in EXIF.
  final upright = img.bakeOrientation(decoded);

  final side = min(upright.width, upright.height);
  final square = img.copyCrop(
    upright,
    x: (upright.width - side) ~/ 2,
    y: (upright.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final photo = side > avatarPhotoSize
      ? img.copyResize(
          square,
          width: avatarPhotoSize,
          height: avatarPhotoSize,
          interpolation: img.Interpolation.average,
        )
      : square;
  return img.encodeJpg(photo, quality: 85);
}

/// [processAvatarPhoto] off the UI thread: decoding a camera frame in pure
/// Dart takes long enough to freeze the screen.
Future<Uint8List> processAvatarPhotoInBackground(Uint8List captured) =>
    Isolate.run(() => processAvatarPhoto(captured));
