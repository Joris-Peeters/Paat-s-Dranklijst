import 'dart:math';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/utils/random_emoji.dart';

void main() {
  // Rebuilt here from the package rather than reusing the private list, so a
  // category filter that silently matches nothing is caught.
  final pool = {
    for (final category in defaultEmojiSet)
      if (avatarEmojiCategories.contains(category.category))
        for (final emoji in category.emoji) emoji.emoji,
  };

  group('randomAvatarEmoji', () {
    test('the pool is not empty', () {
      expect(pool, isNotEmpty);
    });

    test('always returns an emoji from the configured categories', () {
      for (var i = 0; i < 200; i++) {
        expect(pool, contains(randomAvatarEmoji()));
      }
    });

    test('does not keep returning the same emoji', () {
      final drawn = {for (var i = 0; i < 200; i++) randomAvatarEmoji()};
      expect(drawn.length, greaterThan(1));
    });

    test('a seeded Random makes the pick reproducible', () {
      // Asserts the injection seam without pinning a glyph the package could
      // change in a patch release.
      expect(randomAvatarEmoji(Random(7)), randomAvatarEmoji(Random(7)));
    });
  });
}
