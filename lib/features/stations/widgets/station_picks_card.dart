import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../domain/stations/station_picks.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import 'station_detail_sheet.dart';

/// Three stations worth naming out of the hundreds below.
///
/// The one that matters is **best value**: the cheapest fill once the fuel
/// burned getting there and back is paid for. Fuelio's "best price" pick will
/// happily send somebody twenty kilometres to save three cents a litre, which
/// is a loss dressed up as a saving.
class StationPicksCard extends ConsumerWidget {
  const StationPicksCard({
    super.key,
    required this.stations,
    required this.fuelTypeId,
  });

  final List<RankedStation> stations;
  final int fuelTypeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );

    // The car's own tank and its own measured consumption: the two numbers
    // that turn a price comparison into a cost comparison. Absent for a
    // household that has not logged enough yet, and the pick falls back to
    // plain cheapest rather than guessing.
    final vehicles = ref.watch(vehiclesProvider).value ?? const [];
    final vehicle = vehicles.isEmpty ? null : vehicles.first;
    final litres = vehicle?.tankCapacityL;
    final consumption = vehicle == null
        ? null
        : ref.watch(averageEconomyProvider(vehicle.id)).value;

    final picks = StationPicks.from(
      stations,
      fuelTypeId: fuelTypeId,
      litres: litres,
      litersPer100Km: consumption,
    );
    if (picks.cheapest == null) {
      return const SizedBox.shrink();
    }

    final showsValue =
        litres != null &&
        consumption != null &&
        picks.bestValue?.station.id != picks.cheapest?.station.id;

    return Card(
      key: const Key('station-picks'),
      margin: const EdgeInsets.fromLTRB(
        GarageTokens.space4,
        0,
        GarageTokens.space4,
        GarageTokens.space3,
      ),
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (picks.nearest case final pick?)
                  _Pick(
                    label: l10n.stationsPickNearest,
                    pick: pick,
                    fuelTypeId: fuelTypeId,
                    format: format,
                  ),
                if (picks.cheapest case final pick?)
                  _Pick(
                    label: l10n.stationsPickCheapest,
                    pick: pick,
                    fuelTypeId: fuelTypeId,
                    format: format,
                  ),
                if (showsValue && picks.bestValue != null)
                  _Pick(
                    label: l10n.stationsPickBestValue,
                    pick: picks.bestValue!,
                    fuelTypeId: fuelTypeId,
                    format: format,
                  ),
              ],
            ),
            if (showsValue) ...[
              const SizedBox(height: GarageTokens.space2),
              Text(
                l10n.stationsBestValueHint,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: context.tokens.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pick extends StatelessWidget {
  const _Pick({
    required this.label,
    required this.pick,
    required this.fuelTypeId,
    required this.format,
  });

  final String label;
  final RankedStation pick;
  final int fuelTypeId;
  final UnitFormat format;

  @override
  Widget build(BuildContext context) {
    final price = pick.station.cheapestFor(fuelTypeId);
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: InkWell(
        onTap: () => showStationDetailSheet(context, pick.station),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: GarageTokens.space1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: GarageTheme.eyebrow(context)),
              const SizedBox(height: GarageTokens.space1),
              Text(
                format.formatMoney(price, decimals: 2),
                style: GarageTheme.numeric(textTheme.titleMedium!),
              ),
              // The station's own name, not its brand: two INA forecourts a
              // kilometre apart are the case this card exists to tell apart.
              Text(
                pick.station.name.isNotEmpty
                    ? pick.station.name
                    : pick.station.brand ?? '',
                style: textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (pick.distanceKm case final km?)
                Text(
                  format.formatDistance(km, decimals: 1),
                  style: textTheme.labelSmall?.copyWith(
                    color: context.tokens.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What each grade costs around here.
///
/// By grade rather than by coarse fuel type: 95 and 100 are different fuels at
/// different prices, and one figure covering both is a number nobody can act
/// on. The station count is shown because an average over two stations and one
/// over forty are different kinds of claim.
class AreaAveragesCard extends ConsumerWidget {
  const AreaAveragesCard({super.key, required this.stations});

  final List<RankedStation> stations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final averages = StationPicks.areaAverages(stations).take(5).toList();
    if (averages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      key: const Key('station-area-averages'),
      margin: const EdgeInsets.fromLTRB(
        GarageTokens.space4,
        0,
        GarageTokens.space4,
        GarageTokens.space3,
      ),
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.stationsGradeAverages.toUpperCase(),
              style: GarageTheme.eyebrow(context),
            ),
            const SizedBox(height: GarageTokens.space2),
            for (final average in averages)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: GarageTokens.space1,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(average.fuelName)),
                    Text(
                      l10n.stationsGradeStations(average.stations),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.tokens.muted,
                      ),
                    ),
                    const SizedBox(width: GarageTokens.space3),
                    Text(
                      format.formatMoney(average.averagePrice, decimals: 2),
                      style: GarageTheme.numeric(
                        Theme.of(context).textTheme.bodyMedium!,
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
