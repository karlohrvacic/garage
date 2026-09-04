import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../domain/fuel/fuel_economy.dart';

/// The economy trend: l/100km against odometer. Below two points there is no
/// line to draw, so it shows guidance instead of an empty axis.
class EconomyChart extends StatelessWidget {
  const EconomyChart({
    required this.points,
    required this.formatEconomy,
    super.key,
  });

  final List<EconomyPoint> points;

  /// Formats a l/100km value in the household's units for the tooltip.
  final String Function(double?) formatEconomy;

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
          points.isEmpty
              ? l10n.vehicleNoEconomyYet
              : l10n.vehicleTrendNeedsMore,
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.muted),
        ),
      );
    }

    final spots = [
      for (final point in points)
        FlSpot(point.odometerKm.toDouble(), point.litersPer100Km),
    ];
    // The scale floors at half a litre: a 0.02 l/100km wobble drawn full
    // height, with "6.3" printed at every tick, was a chart that lied.
    final ys = spots.map((s) => s.y);
    final lowest = ys.reduce(math.min);
    final highest = ys.reduce(math.max);
    final span = math.max(0.5, highest - lowest);
    // Rounded to a tenth so the ticks land on printable values; a floating
    // drift printed the same label twice.
    double tenth(double v) => (v * 10).round() / 10;
    final minY = tenth((lowest - span / 4).clamp(0.0, double.infinity));
    // From the padded range, not the raw span: derived from the span alone
    // the top landed below the highest point and the worst tanks were drawn
    // outside the border, over the axis labels.
    final top = tenth(highest + span / 4);
    final yInterval = tenth(math.max(0.1, (top - minY) / 5));
    final maxY = minY + yInterval * 5;
    final locale = Localizations.localeOf(context).languageCode;
    final yFormat = intl.NumberFormat('0.0', locale);
    final xFormat = intl.NumberFormat.decimalPattern(locale);
    final xs = spots.map((s) => s.x);
    // Three gaps at most, and never so fine that two labels share a place:
    // the rightmost pair used to overlap into one unreadable smear.
    final xInterval = math.max(
      1.0,
      (xs.reduce(math.max) - xs.reduce(math.min)) / 2.2,
    );
    final axisStyle = GarageTheme.numeric(
      Theme.of(context).textTheme.labelSmall!,
    ).copyWith(color: tokens.muted);

    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => tokens.surface,
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    LineTooltipItem(
                      formatEconomy(spot.y),
                      GarageTheme.numeric(
                        Theme.of(context).textTheme.labelMedium!,
                      ).copyWith(color: tokens.accent),
                    ),
                ],
              ),
            ),
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
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: yInterval,
                  // One decimal, in the household's own numerals. Through
                  // SideTitleWidget so the lowest label is not clipped by
                  // the axis it sits on.
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(yFormat.format(value), style: axisStyle),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: xInterval,
                  // The reading itself: in thousands, three fills a fortnight
                  // apart all printed "121".
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(xFormat.format(value), style: axisStyle),
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
