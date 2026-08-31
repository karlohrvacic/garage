import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../domain/stations/price_trend.dart';

/// The national average over the weeks the feed still remembers.
///
/// Fed a smoothed series, never the raw one: individual days in this feed
/// swing by tens of cents with how many stations reported, and drawn straight
/// it shows cliffs that never happened.
class PriceTrendChart extends StatelessWidget {
  const PriceTrendChart({
    super.key,
    required this.series,
    required this.format,
  });

  final List<TrendPoint> series;
  final UnitFormat format;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final firstDay = series.first.date;
    final span = series.last.date.difference(firstDay).inDays;
    // Everything on one day is a dot, not a trend, and fl_chart cannot draw an
    // axis of zero width.
    if (span <= 0) {
      return const SizedBox.shrink();
    }

    final values = [for (final point in series) point.avgPrice];
    final lowest = values.reduce((a, b) => a < b ? a : b);
    final highest = values.reduce((a, b) => a > b ? a : b);
    // Padded by a tenth of the range so the line does not run along the frame,
    // and never to a zero-height band when the fortnight was flat.
    final pad = (highest - lowest) / 10;
    final headroom = pad <= 0 ? 0.05 : pad;

    final axisStyle = GarageTheme.numeric(
      Theme.of(context).textTheme.labelSmall!,
    ).copyWith(color: tokens.muted);

    return SizedBox(
      height: 120,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: span.toDouble(),
          minY: lowest - headroom,
          maxY: highest + headroom,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: highest - lowest <= 0 ? 1 : (highest - lowest),
                getTitlesWidget: (value, _) =>
                    Text(format.formatMoney(value), style: axisStyle),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: span / 2,
                getTitlesWidget: (value, _) {
                  final date = firstDay.add(Duration(days: value.round()));
                  return Text('${date.day}/${date.month}', style: axisStyle);
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (final point in series)
                  FlSpot(
                    point.date.difference(firstDay).inDays.toDouble(),
                    point.avgPrice,
                  ),
              ],
              isCurved: true,
              barWidth: 2,
              color: tokens.accent,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
