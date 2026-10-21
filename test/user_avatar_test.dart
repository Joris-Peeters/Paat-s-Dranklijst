import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:paats_dranklijst/widgets/user_avatar.dart';

void main() {
  final photo = img.encodeJpg(img.Image(width: 8, height: 8));

  Widget harness(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('without a photo the emoji is drawn', (tester) async {
    await tester.pumpWidget(
      harness(const UserAvatar(emoji: '🦊', seedColorArgb: 0xFFE91E63)),
    );

    expect(find.text('🦊'), findsOneWidget);
    expect(find.byType(Ink), findsNothing);
  });

  testWidgets('a photo replaces the emoji, ringed in primary', (tester) async {
    await tester.pumpWidget(
      harness(
        UserAvatar(emoji: '🦊', seedColorArgb: 0xFFE91E63, image: photo),
      ),
    );

    expect(find.text('🦊'), findsNothing);
    final decoration =
        tester.widget<Ink>(find.byType(Ink)).decoration! as ShapeDecoration;
    expect(decoration.image, isNotNull);
    final context = tester.element(find.byType(Ink));
    final ring = (decoration.shape as CircleBorder).side;
    expect(ring.color, Theme.of(context).colorScheme.primary);
  });

  test('equal bytes make an equal image, so the cache is hit', () {
    final a = AvatarPhotoImage(Uint8List.fromList(photo));
    final b = AvatarPhotoImage(Uint8List.fromList(photo));
    final other = AvatarPhotoImage(Uint8List.fromList([...photo, 0]));

    expect(identical(a.bytes, b.bytes), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(other));
  });
}
