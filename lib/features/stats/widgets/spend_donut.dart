import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../domain/stats/spend_breakdown.dart';

/// A donut of labelled amounts with a legend of the amounts beneath it.
///
/// A donut on its own answers "roughly what share"; the legend answers "how
/// much", which is the question somebody looking at their own spending is
/// actually asking. Both, or neither — a chart without the figures is
/// decoration.
class SpendDonut extends StatelessWidget {
  const SpendDonut({
    super.key,
    required this.title,
    required this.slices,
    required this.format,
  });

  final String title;
  final List<SpendSlice> slices;
  final UnitFormat format;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final palette = GarageTheme.chartPalette(tokens);
    if (slices.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = slices.fold<double>(0, (sum, slice) => sum + slice.amount);

    String labelOf(SpendSlice slice) {
      if (slice.label != null) {
        return slice.label!;
      }
      // "Others" and "nobody typed a name" look identical in a legend and are
      // different facts, so they get different words.
      return slice.isOthers ? l10n.statsOthers : l10n.statsUnlabelled;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: GarageTokens.space3),
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: GarageTheme.eyebrow(context)),
            const SizedBox(height: GarageTokens.space3),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 48,
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                  sections: [
                    for (var i = 0; i < slices.length; i++)
                      PieChartSectionData(
                        value: slices[i].amount,
                        color: palette[i % palette.length],
                        showTitle: false,
                        radius: 34,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: GarageTokens.space4),
            for (var i = 0; i < slices.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: GarageTokens.space1,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: palette[i % palette.length],
                        borderRadius: BorderRadius.circular(
                          GarageTokens.radiusSm,
                        ),
                      ),
                    ),
                    const SizedBox(width: GarageTokens.space2),
                    Expanded(
                      flex: 3,
                      child: Text(
                        labelOf(slices[i]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      // The share as well as the amount: a legend of figures
                      // makes the reader do the division the chart was drawn
                      // to save them.
                      '${(slices[i].amount / total * 100).round()}%',
                      style: GarageTheme.numeric(
                        Theme.of(context).textTheme.labelSmall!,
                      ).copyWith(color: tokens.muted),
                    ),
                    const SizedBox(width: GarageTokens.space3),
                    // The amount takes a share of the row rather than its
                    // natural width, and right-aligns inside it. Two reasons,
                    // and the second was learned by getting it wrong: the
                    // swatch, percentage and amount are fixed widths that
                    // scale with the text, so at 1.5x on a 320px phone they
                    // overflowed the row by themselves with nothing left for
                    // the label to give — and a plain `Flexible` here fixes
                    // that by *under-filling* its slot, which leaves the
                    // leftover after the amount and un-aligns a column of
                    // figures that used to end flush at the card's edge.
                    Expanded(
                      flex: 1,
                      child: Text(
                        format.formatMoney(slices[i].amount),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: GarageTheme.numeric(
                          Theme.of(context).textTheme.bodyMedium!,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
