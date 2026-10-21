import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:paats_dranklijst/utils/avatar_photo.dart';

void main() {
  /// A landscape frame, white with a red block near its left edge.
  Uint8List capture() {
    final frame = img.Image(width: 640, height: 480)
      ..clear(img.ColorRgb8(255, 255, 255));
    img.fillRect(
      frame,
      x1: 100,
      y1: 200,
      x2: 180,
      y2: 280,
      color: img.ColorRgb8(255, 0, 0),
    );
    return img.encodeJpg(frame);
  }

  bool isRed(img.Pixel p) => p.r > 200 && p.g < 80 && p.b < 80;

  test('a frame becomes a square JPEG of the stored size', () {
    final photo = img.decodeJpg(processAvatarPhoto(capture()))!;

    expect(photo.width, avatarPhotoSize);
    expect(photo.height, avatarPhotoSize);
  });

  test('the centre square is kept', () {
    final photo = img.decodeJpg(processAvatarPhoto(capture()))!;

    // The crop starts at x = 80, so the block lands at 20..100 of 480,
    // which is 16..80 of 384.
    expect(isRed(photo.getPixel(48, 192)), isTrue);
    expect(isRed(photo.getPixel(336, 192)), isFalse);
  });

  test('anything that is not an image is refused', () {
    expect(
      () => processAvatarPhoto(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
}
