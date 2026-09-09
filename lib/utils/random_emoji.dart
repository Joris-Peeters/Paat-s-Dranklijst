import 'dart:math';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

/// Categories a randomly assigned avatar is drawn from. Animals read at a
/// glance and stay distinct; a face handed out at random is a face nobody
/// chose. The picker itself still offers every category.
const avatarEmojiCategories = <Category>[Category.ANIMALS];

final _random = Random();

final _avatarEmojis = <String>[
  for (final category in defaultEmojiSet)
    if (avatarEmojiCategories.contains(category.category))
      for (final emoji in category.emoji) emoji.emoji,
];

/// A random emoji for a new member.
///
/// Uniform over the flattened pool rather than category-then-emoji, so a second
/// category could not quietly over-weight the smaller one.
String randomAvatarEmoji([Random? random]) =>
    _avatarEmojis[(random ?? _random).nextInt(_avatarEmojis.length)];
