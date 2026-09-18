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
    // A flat fortnight still needs a band with height, or the line has nowhere
    // to be drawn. Otherwise the axis runs from the lowest price to the
    // highest and says so.
    final flat = highest - lowest <= 0;

    final axisStyle = GarageTheme.numeric(
      Theme.of(context).textTheme.labelSmall!,
    ).copyWith(color: tokens.muted);

    return SizedBox(
      height: 120,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: span.toDouble(),
          // Exactly the range the fortnight covered.
          //
          // These were padded by a tenth, which put the axis bounds a little
          // outside the real ones — and fl_chart walks its labels up from
          // `minY` by `interval`, so a padded band emitted a third label a
          // few pixels from the second and the two printed on top of each
          // other. Two labels, at the two prices that mean something.
          minY: flat ? lowest - 0.05 : lowest,
          maxY: flat ? highest + 0.05 : highest,
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
                // A price's own width plus the gap to the line; see _inside.
                reservedSize: 48 + _priceGap,
                interval: flat ? 0.1 : (highest - lowest),
                // The *widget* decides, not the interval.
                //
                // fl_chart offers title positions of its own as well as the
                // ones the interval walks to, and on a 120-pixel band two of
                // them landed a few pixels apart and printed on top of each
                // other — seen on the live Croatian feed. Anything that is
                // not one of the two ends renders as nothing, so no
                // arithmetic here has to be exactly right for the axis to be
                // readable.
                getTitlesWidget: (value, meta) {
                  final ends = [lowest, highest];
                  final tolerance = flat ? 0.001 : (highest - lowest) / 100;
                  final end = ends.where(
                    (price) => (value - price).abs() <= tolerance,
                  );
                  if (end.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return _inside(
                    meta,
                    Text(format.formatMoney(end.first), style: axisStyle),
                    space: _priceGap,
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: span / 2,
                getTitlesWidget: (value, meta) {
                  final date = firstDay.add(Duration(days: value.round()));
                  return _inside(
                    meta,
                    Text('${date.day}/${date.month}', style: axisStyle),
                  );
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

/// Between a price and the line it labels.
const double _priceGap = 6;

/// [label], kept inside the chart along its axis. The lowest price sits on the
/// bottom edge and the first date on the left one, so centred on their ends
/// the two met in the corner and read as one number, "€1.7510/7", and the last
/// date hung half off the right.
///
/// [space] is taken out of the label's own box, which fl_chart otherwise
/// makes eight pixels: a date was cut to 12 of its 16, and "1,75 €" wrapped.
Widget _inside(TitleMeta meta, Widget label, {double space = 0}) =>
    SideTitleWidget(
      meta: meta,
      space: space,
      fitInside: SideTitleFitInsideData.fromTitleMeta(
        meta,
        distanceFromEdge: 0,
      ),
      child: label,
    );
