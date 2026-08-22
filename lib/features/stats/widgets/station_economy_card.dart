import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../domain/stats/station_economy.dart';

/// Economy grouped by where the fuel was bought, best first.
///
/// Presented as an **observation and not advice**, which is the whole reason
/// this is careful. Fuel brand is a small effect; how, where and when the car
/// was driven are large ones. Two stations differing by a few percent is far
/// more likely to be a motorway month against a city one than anything that
/// came out of the pump, and an app that says otherwise is teaching its reader
/// something false about their own car.
///
/// So: the note is not fine print to be trimmed, the tank counts are shown
/// rather than hidden, and [StationEconomy.worthShowing] keeps the card away
/// entirely unless there is a real gap between at least two measured stations.
class StationEconomyCard extends StatelessWidget {
  const StationEconomyCard({
    super.key,
    required this.samples,
    required this.format,
  });

  final List<StationEconomySample> samples;
  final UnitFormat format;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;

    return Card(
      margin: const EdgeInsets.only(bottom: GarageTokens.space3),
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.statsEconomyByStation.toUpperCase(),
              style: GarageTheme.eyebrow(context),
            ),
            const SizedBox(height: GarageTokens.space3),
            for (final sample in samples)
              Padding(
                padding: const EdgeInsets.only(bottom: GarageTokens.space2),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sample.station),
                          Text(
                            l10n.statsEconomyTanks(sample.tanks),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: tokens.muted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      format.formatEconomy(sample.litersPer100Km),
                      style: GarageTheme.numeric(
                        Theme.of(context).textTheme.bodyMedium!,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: GarageTokens.space2),
            Text(
              l10n.statsEconomyByStationNote,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: tokens.muted),
            ),
          ],
        ),
      ),
    );
  }
}
