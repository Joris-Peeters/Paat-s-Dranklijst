import 'package:flutter/material.dart';

/// One row of a [RankedBarList].
class RankedBar {
  const RankedBar({
    required this.leading,
    required this.label,
    required this.count,
  });

  /// An avatar or an emoji circle.
  final Widget leading;
  final String label;
  final int count;
}

/// A ranking drawn as rows: who or what, a bar scaled to the leader, and the
/// count.
///
/// Plain widgets rather than a chart, so the avatars and names sit right beside
/// their bars.
class RankedBarList extends StatelessWidget {
  const RankedBarList({super.key, required this.entries});

  /// Already in rank order.
  final List<RankedBar> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final max = entries.fold(0, (m, e) => e.count > m ? e.count : m);
    final countStyle = theme.textTheme.titleMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // Every count gets the widest one's width, so all bars share one length.
    // Tabular figures make the largest count the widest.
    final painter = TextPainter(
      text: TextSpan(text: '$max', style: countStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final countWidth = painter.width.ceilToDouble();
    painter.dispose();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        spacing: 12,
        children: [
          for (final entry in entries)
            Row(
              spacing: 12,
              children: [
                entry.leading,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      Text(
                        entry.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge,
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 12,
                          color: colors.surfaceContainerHighest,
                          alignment: AlignmentDirectional.centerStart,
                          child: FractionallySizedBox(
                            widthFactor: max == 0 ? 0 : entry.count / max,
                            heightFactor: 1,
                            child: ColoredBox(color: colors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: countWidth,
                  child: Text(
                    '${entry.count}',
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    style: countStyle,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
