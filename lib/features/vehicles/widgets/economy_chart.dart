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
    // Whole kilometres. An odometer with three decimals on it — "44,011.364"
    // — is a tick that landed on a fractional value, and it reads as a
    // rendering fault on the one axis whose numbers a driver recognises.
    final xFormat = intl.NumberFormat.decimalPattern(locale)
      ..maximumFractionDigits = 0;
    final xs = spots.map((s) => s.x);
    // Exactly three labels — first reading, halfway, last — on an axis that
    // starts and ends on one of them.
    //
    // fl_chart labels the axis minimum as well as every multiple of the
    // interval above it, so an interval that does not divide the range put
    // two labels a few hundred metres apart: "43,245" printed over
    // "44,011.364" on a device. Whole kilometres for the same reason — a
    // fractional tick is what produced those decimals.
    final minX = xs.reduce(math.min).floorToDouble();
    final xInterval = math
        .max(1.0, (xs.reduce(math.max) - minX) / 2)
        .ceilToDouble();
    final maxX = minX + xInterval * 2;
    final axisStyle = GarageTheme.numeric(
      Theme.of(context).textTheme.labelSmall!,
    ).copyWith(color: tokens.muted);

    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: LineChart(
          LineChartData(
            minX: minX,
            maxX: maxX,
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
                  getTitlesWidget: (value, meta) {
                    // fl_chart labels both ends of the scale as well as every
                    // multiple of the interval, and the multiples are counted
                    // from zero rather than from the bottom of the scale — so
                    // a tick can land a fraction above the minimum and print
                    // on top of it. Seen on a device as "5.2" over "5.1".
                    if (_crowded(value, minY, maxY, yInterval)) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(yFormat.format(value), style: axisStyle),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: xInterval,
                  // The reading itself: in thousands, three fills a fortnight
                  // apart all printed "121".
                  getTitlesWidget: (value, meta) {
                    // The same crowding as the scale above: "43,245" printed
                    // over "44,011.364" on a device.
                    if (_crowded(value, minX, maxX, xInterval)) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(xFormat.format(value), style: axisStyle),
                    );
                  },
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

/// Whether a tick would print on top of one of the axis's end labels.
///
/// Both ends are always labelled, and the ticks between them are multiples of
/// [interval] counted from zero — so nothing stops one landing a hair away
/// from an end. A tick *equal* to an end is the end's own label and stays.
bool _crowded(double value, double min, double max, double interval) {
  if (value == min || value == max) {
    return false;
  }
  return (value - min).abs() < interval * 0.35 ||
      (max - value).abs() < interval * 0.35;
}
