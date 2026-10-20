import 'package:flutter/material.dart';

/// One row of a [RankedBarList].
class RankedBar {
  const RankedBar({
    required this.leading,
    required this.label,
    required this.count,
    this.detail,
    this.countLabel,
  });

  /// An avatar or an emoji circle.
  final Widget leading;
  final String label;
  final int count;

  /// Drawn after the label in a quieter style: a date, or an emoji.
  final String? detail;

  /// Printed in place of [count], which then only sizes the bar.
  final String? countLabel;

  String get _countText => countLabel ?? '$count';
}

/// A ranking drawn as rows: who or what, a bar scaled to the leader, and the
/// count.
///
/// Plain widgets rather than a chart, so the avatars and names sit right beside
/// their bars.
class RankedBarList extends StatelessWidget {
  const RankedBarList({super.key, required this.entries, this.outOf});

  /// Already in rank order.
  final List<RankedBar> entries;

  /// The count a full bar stands for; the leader's when null.
  final int? outOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final max =
        outOf ?? entries.fold<int>(0, (m, e) => e.count > m ? e.count : m);
    final countStyle = theme.textTheme.titleMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final detailStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );

    // Every count gets the widest one's width, so all bars share one length.
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    var countWidth = 0.0;
    for (final entry in entries) {
      painter
        ..text = TextSpan(text: entry._countText, style: countStyle)
        ..layout();
      if (painter.width > countWidth) countWidth = painter.width;
    }
    countWidth = countWidth.ceilToDouble();
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
                      // The detail takes at most half the width, the name
                      // whatever it leaves.
                      LayoutBuilder(
                        builder: (context, constraints) => Row(
                          spacing: 6,
                          children: [
                            Flexible(
                              child: Text(
                                entry.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                            if (entry.detail != null)
                              Text('·', style: detailStyle),
                            if (entry.detail case final detail?)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth / 2,
                                ),
                                child: Text(
                                  detail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: detailStyle,
                                ),
                              ),
                          ],
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 12,
                          color: colors.surfaceContainerHighest,
                          alignment: AlignmentDirectional.centerStart,
                          child: FractionallySizedBox(
                            widthFactor: max == 0
                                ? 0
                                : (entry.count / max).clamp(0.0, 1.0),
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
                    entry._countText,
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
