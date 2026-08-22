import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../providers/stats_providers.dart';

/// The odometer over time: one line per vehicle, one colour.
///
/// The line is the whole story — a flat stretch is a car that sat, a steep one
/// is a summer of driving.
///
/// It used to colour every point by which table the reading came out of, with
/// a six-item key underneath naming fuel, service, costs, odometer, trips and
/// income. The idea was that a household seeing only fuel-coloured dots would
/// learn its projection rests on remembering to log fill-ups. In use that did
/// not pay: it is a question nobody asks while looking at a mileage curve, the
/// six colours were indistinguishable at a 3px radius, and the key took more
/// of the card than the chart. See decision 57 in docs/decisions/decision-log.md.
class OdometerChart extends StatelessWidget {
  const OdometerChart({
    super.key,
    required this.readingsPerVehicle,
    required this.format,
  });

  /// Grouped per vehicle: one line each, because two cars' odometers are not
  /// points on the same series.
  final List<List<OdometerReading>> readingsPerVehicle;

  final UnitFormat format;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final series = [
      for (final readings in readingsPerVehicle)
        if (readings.length >= 2)
          ([...readings]..sort((a, b) => a.date.compareTo(b.date))),
    ];
    if (series.isEmpty) {
      return const SizedBox.shrink();
    }

    final all = [for (final line in series) ...line];
    final firstDay = all
        .map((r) => r.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final lastDay = all
        .map((r) => r.date)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final span = lastDay.difference(firstDay).inDays;
    if (span <= 0) {
      return const SizedBox.shrink();
    }

    double x(DateTime date) => date.difference(firstDay).inDays.toDouble();
    double y(int km) => format.preferences.kmToDisplay(km.toDouble());

    // The axis is bounded and stepped here rather than left to the chart
    // library, which put its lowest label a hair under the first gridline and
    // printed "19k" on top of "20k". Four steps across the data, rounded up to
    // a whole thousand so the labels read as odometer numbers.
    final values = [
      for (final line in series)
        for (final r in line) y(r.km),
    ];
    final lowest = values.reduce((a, b) => a < b ? a : b);
    final highest = values.reduce((a, b) => a > b ? a : b);
    final step = (((highest - lowest) / 4) / 1000).ceilToDouble() * 1000;
    final interval = step <= 0 ? 1000.0 : step;

    final axisStyle = GarageTheme.numeric(
      Theme.of(context).textTheme.labelSmall!,
    ).copyWith(color: tokens.muted);

    return Card(
      margin: const EdgeInsets.only(bottom: GarageTokens.space3),
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.statsOdometerChart.toUpperCase(),
              style: GarageTheme.eyebrow(context),
            ),
            const SizedBox(height: GarageTokens.space3),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: span.toDouble(),
                  minY: (lowest / interval).floorToDouble() * interval,
                  maxY: (highest / interval).ceilToDouble() * interval,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: tokens.border, strokeWidth: 1),
                  ),
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
                        reservedSize: 52,
                        interval: interval,
                        getTitlesWidget: (value, _) => Text(
                          // Thousands, so a six-figure odometer does not eat
                          // half the chart's width in axis labels.
                          '${(value / 1000).toStringAsFixed(0)}k',
                          style: axisStyle,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: span / 2,
                        getTitlesWidget: (value, _) {
                          final date = firstDay.add(
                            Duration(days: value.round()),
                          );
                          return Text(
                            '${date.month}/${date.year % 100}',
                            style: axisStyle,
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    for (final line in series)
                      LineChartBarData(
                        spots: [
                          for (final reading in line)
                            FlSpot(x(reading.date), y(reading.km)),
                        ],
                        isCurved: false,
                        barWidth: 2,
                        color: tokens.muted,
                        dotData: FlDotData(
                          getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                            radius: 3,
                            color: tokens.accent,
                            strokeWidth: 0,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
