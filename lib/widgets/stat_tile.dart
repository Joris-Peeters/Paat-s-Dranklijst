import 'package:flutter/material.dart';

/// A figure over its label, with an optional change underneath.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.child,
    this.ready = true,
    this.delta,
  });

  final String label;

  /// The figure itself: a count, or a `MoneyText`.
  final Widget child;

  /// False while the query is out. The tile keeps its size rather than
  /// collapsing, so the page does not move under a finger when it lands.
  final bool ready;

  /// An already formatted change, or null for a tile that shows none.
  final String? delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          spacing: 4,
          children: [
            Opacity(
              opacity: ready ? 1 : 0,
              child: FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: muted),
            ),
            if (delta != null)
              Opacity(
                opacity: ready ? 1 : 0,
                // Neutral on purpose: more spending is neither good nor bad.
                child: Text(
                  delta!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
