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

    final textTheme = Theme.of(context).textTheme;
    final amountStyle = GarageTheme.numeric(textTheme.bodyMedium!);
    // The share as well as the amount: a legend of figures makes the reader
    // do the division the chart was drawn to save them.
    final shareStyle = GarageTheme.numeric(
      textTheme.labelSmall!,
    ).copyWith(color: tokens.muted);
    final amounts = [
      for (final slice in slices) format.formatMoney(slice.amount),
    ];
    final shares = [
      for (final slice in slices) '${(slice.amount / total * 100).round()}%',
    ];

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
            // The amount is never cut short. It is the figure the legend is
            // for, and giving it a share of the row — a quarter, whatever it
            // said — printed "€1,229.…" on a phone with the cents replaced by
            // dots. Every amount gets the width of the widest one, measured
            // in the style it is drawn in, so the column still ends flush;
            // the label takes what is left and is the one to give. When even
            // the swatch, the share and the amount would not fit the row —
            // every fixed part scales with the text — the share goes first.
            LayoutBuilder(
              builder: (context, constraints) {
                final amountWidth = _widest(context, amounts, amountStyle);
                final shareWidth = _widest(context, shares, shareStyle);
                const fixed =
                    _swatch + GarageTokens.space2 + GarageTokens.space3;
                final showsShare =
                    fixed + shareWidth + amountWidth <= constraints.maxWidth;
                return Column(
                  children: [
                    for (var i = 0; i < slices.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: GarageTokens.space1,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: _swatch,
                              height: _swatch,
                              decoration: BoxDecoration(
                                color: palette[i % palette.length],
                                borderRadius: BorderRadius.circular(
                                  GarageTokens.radiusSm,
                                ),
                              ),
                            ),
                            const SizedBox(width: GarageTokens.space2),
                            Expanded(
                              child: Text(
                                labelOf(slices[i]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (showsShare) ...[
                              Text(shares[i], style: shareStyle),
                              const SizedBox(width: GarageTokens.space3),
                            ],
                            SizedBox(
                              width: amountWidth,
                              child: Text(
                                amounts[i],
                                textAlign: TextAlign.right,
                                style: amountStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static const _swatch = 10.0;

  /// The widest of [texts] as [style] draws it here — the same font, scale
  /// and direction the row's own `Text` will use, so the measurement is the
  /// width and not an estimate of it.
  static double _widest(
    BuildContext context,
    List<String> texts,
    TextStyle style,
  ) {
    final merged = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var widest = 0.0;
    for (final text in texts) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: merged),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) {
        widest = painter.width;
      }
      painter.dispose();
    }
    return widest.ceilToDouble();
  }
}
