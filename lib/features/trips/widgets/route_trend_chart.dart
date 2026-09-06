import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../domain/trips/route_trend.dart';

/// One box per period: the middle half of the journeys, with the median
/// marked across it.
///
/// A bare line of medians would be the same chart with the uncertainty
/// deleted — and the uncertainty is most of the answer when the question is
/// whether a commute really got slower.
class RouteTrendChart extends StatelessWidget {
  const RouteTrendChart({super.key, required this.buckets});

  final List<RouteBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final axisStyle = GarageTheme.numeric(
      Theme.of(context).textTheme.labelSmall!,
    ).copyWith(color: tokens.muted);
    final ceiling = buckets.fold<double>(0, (m, b) => b.high > m ? b.high : m);
    if (ceiling <= 0) {
      return const SizedBox.shrink();
    }
    // Label every nth period, so a two-year history does not overprint itself.
    final every = (buckets.length / 5).ceil().clamp(1, buckets.length);
    // Whole minutes, and never the same number twice. Left to itself fl_chart
    // picks an interval from the range, and a chart topping out at one minute
    // drew an axis reading "1, 1, 1, 0" — which looks like a rendering fault
    // rather than a small number.
    final step = (ceiling / 4).ceilToDouble().clamp(1.0, double.infinity);

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          // From zero, not from the lowest bucket. A trend drawn on a cropped
          // axis makes four minutes look like a catastrophe, and this chart
          // exists to answer whether a change is real.
          minY: 0,
          maxY: ceiling * 1.15,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: step,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: tokens.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: const BarTouchData(enabled: false),
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
                reservedSize: 34,
                interval: step,
                getTitlesWidget: (value, meta) {
                  // The top tick often lands above the tallest box, where a
                  // label is a number pointing at nothing.
                  if (value > ceiling) {
                    return const SizedBox.shrink();
                  }
                  return Text(value.toStringAsFixed(0), style: axisStyle);
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  if (index < 0 || index >= buckets.length) {
                    return const SizedBox.shrink();
                  }
                  if (index % every != 0) {
                    return const SizedBox.shrink();
                  }
                  return Text(buckets[index].label, style: axisStyle);
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < buckets.length; i++)
              BarChartGroupData(x: i, barRods: [_rod(buckets[i], tokens)]),
          ],
        ),
      ),
    );
  }
}

BarChartRodData _rod(RouteBucket bucket, GarageTokens tokens) {
  // A period where every journey took the same time has no box to draw. Half
  // a minute either way keeps it visible without pretending to a spread.
  final low = bucket.high - bucket.low < 1 ? bucket.median - 0.5 : bucket.low;
  final high = bucket.high - bucket.low < 1 ? bucket.median + 0.5 : bucket.high;

  return BarChartRodData(
    fromY: low,
    toY: high,
    width: 16,
    borderRadius: BorderRadius.circular(2),
    // Thin data looks thin. The colour is the only warning that survives
    // somebody reading the chart and not the sentence under it.
    color: bucket.sparse ? tokens.border : tokens.muted,
    rodStackItems: [
      // The median, drawn across the box rather than as a separate series.
      BarChartRodStackItem(
        bucket.median - 0.4,
        bucket.median + 0.4,
        bucket.sparse ? tokens.muted : tokens.accent,
      ),
    ],
  );
}
