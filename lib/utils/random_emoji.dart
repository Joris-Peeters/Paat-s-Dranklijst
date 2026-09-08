import 'dart:math';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

/// Categories a randomly assigned avatar is drawn from. Animals and plants read
/// at a glance on a fridge and stay distinct from one another; a face handed out
/// at random is a face nobody chose.
///
/// The picker itself offers every category — only the random pick is narrowed.
const avatarEmojiCategories = <Category>[Category.ANIMALS];

final _random = Random();

/// Flattened once — a top-level `final` initializes lazily, on first read.
final _avatarEmojis = <String>[
  for (final category in defaultEmojiSet)
    if (avatarEmojiCategories.contains(category.category))
      for (final emoji in category.emoji) emoji.emoji,
];

/// A random emoji for a new member (rule 6).
///
/// Uniform over the flattened pool rather than category-then-emoji, so adding a
/// second category later cannot quietly over-weight the smaller one. [random] is
/// injectable so a test can seed it.
String randomAvatarEmoji([Random? random]) =>
    _avatarEmojis[(random ?? _random).nextInt(_avatarEmojis.length)];
