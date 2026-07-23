import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../domain/fuel/fuel_economy.dart';

/// The economy trend: l/100km against odometer. Below two points there is no
/// line to draw, so it shows guidance instead of an empty axis.
class EconomyChart extends StatelessWidget {
  const EconomyChart({required this.points, super.key});

  final List<EconomyPoint> points;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;

    if (points.length < 2) {
      return Padding(
        padding: const EdgeInsets.all(GarageTokens.space6),
        child: Text(
          // With one point the gauge above already shows a figure, so "log two
          // fills to see economy" would contradict what the user is looking at.
          points.isEmpty ? l10n.vehicleNoEconomyYet : l10n.vehicleTrendNeedsMore,
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.muted),
        ),
      );
    }

    final spots = [
      for (final point in points)
        FlSpot(point.odometerKm.toDouble(), point.litersPer100Km),
    ];
    final axisStyle = GarageTheme.numeric(
      Theme.of(context).textTheme.labelSmall!,
    ).copyWith(color: tokens.muted);

    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: tokens.border, strokeWidth: 1),
              getDrawingVerticalLine: (_) =>
                  FlLine(color: tokens.border, strokeWidth: 1),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: tokens.border),
            ),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (value, _) => Text(
                    value.toStringAsFixed(0),
                    style: axisStyle,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, _) => Text(
                    (value / 1000).toStringAsFixed(0),
                    style: axisStyle,
                  ),
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: tokens.accent,
                barWidth: 2,
                dotData: const FlDotData(show: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
