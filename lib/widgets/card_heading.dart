import 'package:flutter/material.dart';

/// The label across the top of a card.
///
/// Material's overline treatment — small, letter-spaced and upper case — so it
/// names the card without competing with whatever is inside it. Shared so the
/// cards on the Start page and a user's own page stay identical.
class CardHeading extends StatelessWidget {
  const CardHeading({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        spacing: 8,
        children: [
          Icon(icon, size: 18, color: color),
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
