import 'package:flutter/material.dart';

import '../data/daos/stats_dao.dart';
import '../data/database.dart';
import '../l10n/app_localizations.dart';
import 'card_heading.dart';
import 'user_avatar.dart';

/// Today's top three, laid out as a podium: second, first, third.
class Podium extends StatelessWidget {
  const Podium({super.key, required this.entries, this.onUserTap});

  /// Exactly three, in rank order.
  final List<PodiumEntry> entries;

  /// A tap anywhere on a place. Never called for an archived user, who has
  /// nothing left to open.
  final ValueChanged<UserRow>? onUserTap;

  @override
  Widget build(BuildContext context) {
    assert(entries.length == 3, 'a podium has three places');
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardHeading(icon: Icons.emoji_events, label: l10n.podiumTitle),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 8,
                children: [
                  for (final place in const [1, 0, 2])
                    Expanded(
                      child: _Place(
                        rank: place + 1,
                        entry: entries[place],
                        onTap: _tapFor(entries[place].user),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  VoidCallback? _tapFor(UserRow user) {
    final onUserTap = this.onUserTap;
    if (onUserTap == null || user.archivedAt != null) return null;
    return () => onUserTap(user);
  }
}

class _Place extends StatelessWidget {
  const _Place({required this.rank, required this.entry, this.onTap});

  final int rank;
  final PodiumEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // The whole place is the target, not just the avatar: wet fingers.
    return Card.filled(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // The winner stands a step higher than the other two.
          padding: EdgeInsets.fromLTRB(4, rank == 1 ? 20 : 8, 4, 8),
          child: Column(
            spacing: 4,
            children: [
              Text('$rank', style: theme.textTheme.labelLarge),
              UserAvatar(
                emoji: entry.user.avatarEmoji,
                seedColorArgb: entry.user.seedColorArgb,
                size: rank == 1 ? 56 : 44,
              ),
              Text(
                entry.user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                l10n.itemWithQuantity(entry.item.emoji, entry.count),
                maxLines: 1,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
