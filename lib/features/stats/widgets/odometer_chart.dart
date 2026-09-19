import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../providers/stats_providers.dart';
import '../time_axis.dart';

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
    final axis = TimeAxis(first: firstDay, last: lastDay);
    if (axis.maxX <= axis.minX) {
      return const SizedBox.shrink();
    }

    double x(DateTime date) => TimeAxis.x(date);
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

    // Ticks where the calendar turns — "Oct · 2026 · Apr · Jul" — rather
    // than at the first reading, the last and the day between them, which
    // read as three dates picked at random. The year goes where the year
    // changes; every other tick is its month. A span too short to cross a
    // boundary is labelled by its two ends instead.
    final monthName = DateFormat.MMM(format.locale);
    String tickLabel(DateTime month) =>
        month.month == 1 || axis.unitMonths >= 12
        ? '${month.year}'
        : monthName.format(month);
    const hairline = 1e-6;
    final bottomTitles = axis.ticks.isEmpty
        ? SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: axis.maxX - axis.minX,
            getTitlesWidget: (value, _) {
              // The library also offers a point of its own between the two
              // ends, at a multiple of the interval counted from zero, and
              // that one is the random date this replaced.
              if ((value - axis.minX).abs() < hairline) {
                return Text(format.formatMonthDay(firstDay), style: axisStyle);
              }
              if ((value - axis.maxX).abs() < hairline) {
                return Text(format.formatMonthDay(lastDay), style: axisStyle);
              }
              return const SizedBox.shrink();
            },
          )
        : SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: axis.unitMonths.toDouble(),
            minIncluded: false,
            maxIncluded: false,
            getTitlesWidget: (value, _) =>
                Text(tickLabel(axis.monthAt(value)), style: axisStyle),
          );

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
                  minX: axis.minX,
                  maxX: axis.maxX,
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
                    bottomTitles: AxisTitles(sideTitles: bottomTitles),
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
