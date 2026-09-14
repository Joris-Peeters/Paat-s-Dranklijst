import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Vertical bars of counts: consumptions per day, week, month or hour.
class CountBarChart extends StatelessWidget {
  const CountBarChart({
    super.key,
    required this.counts,
    required this.labelOf,
    this.height = 200,
  });

  final List<int> counts;

  /// The axis and tooltip label of the bar at an index.
  final String Function(int index) labelOf;

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final axisStyle = theme.textTheme.labelSmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final maxCount = counts.fold(0, max);
    final interval = gridInterval(maxCount);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Room for roughly one label per 64 px, however many bars there are.
          final labelEvery = max(
            1,
            (counts.length / max(1, constraints.maxWidth / 64)).ceil(),
          );
          final barWidth = max(
            2.0,
            (constraints.maxWidth - 40) / max(1, counts.length) * 0.6,
          );

          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: BarChart(
              BarChartData(
                maxY: max(
                  1,
                  (maxCount / interval).ceil() * interval,
                ).toDouble(),
                barGroups: [
                  for (var i = 0; i < counts.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: counts[i].toDouble(),
                          color: colors.primary,
                          width: barWidth,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(min(4, barWidth / 2)),
                          ),
                        ),
                      ],
                    ),
                ],
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: interval.toDouble(),
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: colors.outlineVariant, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: interval.toDouble(),
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text('${value.toInt()}', style: axisStyle),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index % labelEvery != 0) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(labelOf(index), style: axisStyle),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => colors.inverseSurface,
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      '${labelOf(group.x)}\n${rod.toY.toInt()}',
                      theme.textTheme.labelMedium!.copyWith(
                        color: colors.onInverseSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A whole-number step giving about four grid lines up to [maxCount], so the
/// axis never labels half a drink.
int gridInterval(int maxCount) => max(1, (maxCount / 4).ceil());
