import 'package:flutter/material.dart';

/// A ranking drawn as rows: who or what, a bar scaled to the leader, and the
/// value.
///
/// Takes the ranked rows as they are and asks the caller how to draw each part
/// of one. Plain widgets rather than a chart, so the avatars and names sit right
/// beside their bars.
class RankedBarList<T> extends StatelessWidget {
  const RankedBarList({
    super.key,
    required this.entries,
    required this.leading,
    required this.label,
    required this.value,
    this.valueLabel,
    this.detail,
    this.outOf,
  });

  /// Already in rank order.
  final List<T> entries;

  /// An avatar or an emoji circle.
  final Widget Function(T entry) leading;
  final String Function(T entry) label;

  /// Sizes the bar, and is printed unless [valueLabel] is given.
  final num Function(T entry) value;
  final String Function(T entry)? valueLabel;

  /// Drawn after the label in a quieter style: a date, or an emoji.
  final String? Function(T entry)? detail;

  /// The value a full bar stands for; the leader's when null.
  final num? outOf;

  static TextStyle? _valueStyle(ThemeData theme) => theme.textTheme.titleMedium
      ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  @override
  Widget build(BuildContext context) {
    final values = [for (final entry in entries) value(entry)];
    final texts = [
      for (final (i, entry) in entries.indexed)
        valueLabel?.call(entry) ?? '${values[i]}',
    ];
    final max = outOf ?? values.fold<num>(0, (m, v) => v > m ? v : m);

    // Every value gets the widest one's width, so all bars share one length.
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    final style = _valueStyle(Theme.of(context));
    var valueWidth = 0.0;
    for (final text in texts) {
      painter
        ..text = TextSpan(text: text, style: style)
        ..layout();
      if (painter.width > valueWidth) valueWidth = painter.width;
    }
    valueWidth = valueWidth.ceilToDouble();
    painter.dispose();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        spacing: 12,
        children: [
          for (final (i, entry) in entries.indexed)
            _RankedRow(
              leading: leading(entry),
              label: label(entry),
              detail: detail?.call(entry),
              fraction: max == 0 ? 0 : (values[i] / max).clamp(0.0, 1.0),
              value: texts[i],
              valueWidth: valueWidth,
            ),
        ],
      ),
    );
  }
}

class _RankedRow extends StatelessWidget {
  const _RankedRow({
    required this.leading,
    required this.label,
    required this.detail,
    required this.fraction,
    required this.value,
    required this.valueWidth,
  });

  final Widget leading;
  final String label;
  final String? detail;
  final double fraction;
  final String value;
  final double valueWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final detailStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return Row(
      spacing: 12,
      children: [
        leading,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              // The detail takes at most half the width, the name whatever it
              // leaves.
              LayoutBuilder(
                builder: (context, constraints) => Row(
                  spacing: 6,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    if (detail case final detail?) ...[
                      Text('·', style: detailStyle),
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
                    widthFactor: fraction,
                    heightFactor: 1,
                    child: ColoredBox(color: colors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: valueWidth,
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            style: RankedBarList._valueStyle(theme),
          ),
        ),
      ],
    );
  }
}
