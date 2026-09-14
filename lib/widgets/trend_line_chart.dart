import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'count_bar_chart.dart';

/// A line of counts over time: a user's consumptions per week.
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
    required this.counts,
    required this.labelOf,
    this.height = 180,
  });

  final List<int> counts;
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: max(1, (maxCount / interval).ceil() * interval).toDouble(),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < counts.length; i++)
                    FlSpot(i.toDouble(), counts[i].toDouble()),
                ],
                color: colors.primary,
                barWidth: 3,
                // Curves would overshoot below zero between a quiet week and a
                // busy one.
                preventCurveOverShooting: true,
                isCurved: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: colors.primary.withValues(alpha: 0.15),
                ),
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
                  // Every third week: twelve dates would collide on a phone.
                  interval: 3,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(labelOf(value.toInt()), style: axisStyle),
                  ),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => colors.inverseSurface,
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    LineTooltipItem(
                      '${labelOf(spot.x.toInt())}\n${spot.y.toInt()}',
                      theme.textTheme.labelMedium!.copyWith(
                        color: colors.onInverseSurface,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
