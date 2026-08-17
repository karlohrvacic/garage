import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';

/// A month's spend split into fuel and everything else.
class MonthSpend {
  const MonthSpend({
    required this.month,
    required this.fuel,
    required this.other,
  });

  final DateTime month;
  final double fuel;
  final double other;

  double get total => fuel + other;
}

/// Spend per month as stacked fuel/other bars.
class MonthlySpendBars extends StatelessWidget {
  const MonthlySpendBars({
    super.key,
    required this.months,
    required this.format,
  });

  final List<MonthSpend> months;
  final UnitFormat format;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final axisStyle = GarageTheme.numeric(
      Theme.of(context).textTheme.labelSmall!,
    ).copyWith(color: tokens.muted);
    final maxTotal = months.fold<double>(
      0,
      (m, s) => s.total > m ? s.total : m,
    );
    if (maxTotal <= 0) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: GarageTokens.space3),
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maxTotal * 1.1,
                  gridData: FlGridData(
                    drawVerticalLine: false,
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
                        reservedSize: 40,
                        getTitlesWidget: (value, _) =>
                            Text(value.toStringAsFixed(0), style: axisStyle),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index < 0 || index >= months.length) {
                            return const SizedBox.shrink();
                          }
                          // Label every other month to keep the axis legible.
                          if (index.isOdd) {
                            return const SizedBox.shrink();
                          }
                          final month = months[index].month;
                          return Text(
                            '${month.month}/${month.year % 100}',
                            style: axisStyle,
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < months.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: months[i].total,
                            width: 12,
                            borderRadius: BorderRadius.circular(3),
                            rodStackItems: [
                              BarChartRodStackItem(
                                0,
                                months[i].fuel,
                                tokens.accent,
                              ),
                              BarChartRodStackItem(
                                months[i].fuel,
                                months[i].total,
                                tokens.muted,
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: GarageTokens.space3),
            Row(
              children: [
                _LegendDot(color: tokens.accent, label: l10n.statsFuelOnly),
                const SizedBox(width: GarageTokens.space4),
                _LegendDot(
                  color: tokens.muted,
                  label: l10n.statsTotalWithoutFuel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

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
