import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../providers/stats_providers.dart';

/// The odometer over time, with every point coloured by what recorded it.
///
/// The line is the story — a flat stretch is a car that sat, a steep one is a
/// summer of driving — and the colours answer the question the line raises,
/// which is where the app is getting its numbers from. A household that sees
/// only fuel-coloured points knows its maintenance projection rests entirely
/// on remembering to log fill-ups.
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

    final axisStyle = GarageTheme.numeric(
      Theme.of(context).textTheme.labelSmall!,
    ).copyWith(color: tokens.muted);

    Color colorOf(OdometerSource source) => switch (source) {
      OdometerSource.fuel => tokens.accent,
      OdometerSource.service => tokens.warn,
      OdometerSource.cost => tokens.danger,
      OdometerSource.reading => tokens.success,
      OdometerSource.trip => tokens.fg,
      OdometerSource.income => tokens.muted,
    };

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
                          getDotPainter: (spot, _, _, index) =>
                              FlDotCirclePainter(
                                radius: 3,
                                color: colorOf(line[index].source),
                                strokeWidth: 0,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: GarageTokens.space3),
            Wrap(
              spacing: GarageTokens.space4,
              runSpacing: GarageTokens.space2,
              children: [
                for (final (source, label) in [
                  (OdometerSource.fuel, l10n.fuelTitle),
                  (OdometerSource.service, l10n.maintenanceTitle),
                  (OdometerSource.cost, l10n.costsTitle),
                  (OdometerSource.reading, l10n.odometerTitle),
                  (OdometerSource.trip, l10n.tripsTitle),
                  (OdometerSource.income, l10n.incomeTitle),
                ])
                  ChartLegendDot(color: colorOf(source), label: label),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A colour swatch with its label. Shared by every chart on the screen so one
/// legend never renders subtly differently from the next.
class ChartLegendDot extends StatelessWidget {
  const ChartLegendDot({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(GarageTokens.radiusSm),
          ),
        ),
        const SizedBox(width: GarageTokens.space2),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
