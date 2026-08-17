import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/station_providers.dart';
import '../widgets/station_detail_sheet.dart';
import '../widgets/station_picks_card.dart';

/// How far from a station the price list is still worth showing.
///
/// Croatia is roughly 500 km end to end, so a station a couple of hundred
/// kilometres off is a real answer in a thin part of the country, while
/// anything past that means the reader is somewhere this dataset does not
/// cover.
const _coveredRadiusKm = 300.0;

/// MZOE coarse fuel type ids.
const _petrol = 1;
const _diesel = 2;
const _lpg = 3;

class StationsScreen extends ConsumerStatefulWidget {
  const StationsScreen({super.key});

  @override
  ConsumerState<StationsScreen> createState() => _StationsScreenState();
}

class _StationsScreenState extends ConsumerState<StationsScreen> {
  int _fuelTypeId = _petrol;

  /// The stations close enough to be worth summarising, or null while they are
  /// still loading. A station with no distance counts as covered: without a
  /// position there is nothing to place the reader outside the country by.
  List<NearbyStation>? _covered(List<NearbyStation>? stations) {
    if (stations == null) {
      return null;
    }
    return [
      for (final entry in stations)
        if (entry.distanceKm == null || entry.distanceKm! <= _coveredRadiusKm)
          entry,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final nearby = ref.watch(nearbyStationsProvider);

    return GaragePageScaffold(
      title: l10n.stationsTitle,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(GarageTokens.space4),
            child: Row(
              children: [
                for (final (typeId, label) in [
                  (_petrol, l10n.stationsFuelPetrol),
                  (_diesel, l10n.stationsFuelDiesel),
                  (_lpg, l10n.stationsFuelLpg),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: GarageTokens.space2),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _fuelTypeId == typeId,
                      onSelected: (_) => setState(() => _fuelTypeId = typeId),
                    ),
                  ),
              ],
            ),
          ),
          _PriceContext(fuelTypeId: _fuelTypeId),
          // Only ever over stations this dataset actually covers. Opened from
          // outside Croatia the whole country is "nearby", and a pick card
          // naming a station a continent away is worse than none.
          if (_covered(nearby.value) case final list? when list.isNotEmpty) ...[
            StationPicksCard(stations: list, fuelTypeId: _fuelTypeId),
            AreaAveragesCard(stations: list),
          ],
          Expanded(
            child: AsyncValueView<List<NearbyStation>>(
              value: nearby,
              onRetry: () {
                ref
                  ..invalidate(positionProvider)
                  ..invalidate(stationsProvider);
              },
              data: (stations) {
                final favourites = ref.watch(favouriteStationsProvider);
                final hasLocation = stations.any(
                  (entry) => entry.distanceKm != null,
                );
                final selling = [
                  for (final entry in stations)
                    if (entry.station.cheapestFor(_fuelTypeId) != null) entry,
                ];
                int byFavourite(NearbyStation a, NearbyStation b) {
                  final aFav = favourites.contains(a.station.id) ? 0 : 1;
                  final bFav = favourites.contains(b.station.id) ? 0 : 1;
                  return aFav.compareTo(bFav);
                }

                if (hasLocation) {
                  selling.sort((a, b) {
                    final fav = byFavourite(a, b);
                    return fav != 0
                        ? fav
                        : a.distanceKm!.compareTo(b.distanceKm!);
                  });
                } else {
                  selling.sort((a, b) {
                    final fav = byFavourite(a, b);
                    return fav != 0
                        ? fav
                        : a.station
                              .cheapestFor(_fuelTypeId)!
                              .compareTo(b.station.cheapestFor(_fuelTypeId)!);
                  });
                }
                final visible = selling.take(50).toList(growable: false);
                if (visible.isEmpty) {
                  return EmptyState(message: l10n.stationsEmpty);
                }
                // Every price here is Croatian. Opened from elsewhere the
                // screen listed the whole country nearest-first, which put a
                // station most of the way around the world under the heading
                // "average nearby". Where the data stops is the useful thing
                // to say.
                if (hasLocation) {
                  final nearest = selling
                      .map((entry) => entry.distanceKm!)
                      .reduce(math.min);
                  if (nearest > _coveredRadiusKm) {
                    return EmptyState(
                      message: l10n.stationsOutOfRange(
                        format.formatDistance(nearest, decimals: 0),
                      ),
                    );
                  }
                }
                return ListView.separated(
                  key: const Key('station-list'),
                  padding: const EdgeInsets.fromLTRB(
                    GarageTokens.space4,
                    0,
                    GarageTokens.space4,
                    GarageTokens.space4,
                  ),
                  itemCount: visible.length + (hasLocation ? 1 : 2),
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: GarageTokens.space2),
                  itemBuilder: (context, index) {
                    if (!hasLocation && index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: GarageTokens.space2,
                        ),
                        child: Text(
                          l10n.stationsNoLocation,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    }
                    final offset = hasLocation ? 0 : 1;
                    if (index - offset == visible.length) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          top: GarageTokens.space2,
                        ),
                        child: Text(
                          l10n.stationsAttribution,
                          style: Theme.of(context).textTheme.labelSmall,
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    final entry = visible[index - offset];
                    final station = entry.station;
                    final price = station.cheapestFor(_fuelTypeId)!;
                    return Card(
                      child: ListTile(
                        title: Row(
                          children: [
                            if (favourites.contains(station.id)) ...[
                              Icon(
                                Icons.star,
                                size: 14,
                                color: context.tokens.accent,
                              ),
                              const SizedBox(width: GarageTokens.space1),
                            ],
                            Expanded(
                              child: Text(
                                [
                                  if (station.brand != null &&
                                      station.brand!.trim().length > 1)
                                    station.brand,
                                  station.name,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          [
                            if (station.address != null) station.address,
                            if (station.place != null) station.place,
                          ].whereType<String>().join(', '),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              format.formatMoney(price),
                              style: GarageTheme.numeric(
                                Theme.of(context).textTheme.titleSmall!,
                              ).copyWith(color: context.tokens.accent),
                            ),
                            if (entry.distanceKm != null)
                              Text(
                                format.formatDistance(
                                  entry.distanceKm!,
                                  decimals: 1,
                                ),
                                style: GarageTheme.numeric(
                                  Theme.of(context).textTheme.labelSmall!,
                                ),
                              ),
                          ],
                        ),
                        onTap: () => showStationDetailSheet(context, station),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Average of the nearby (or filtered) prices plus the ministry's national
/// average for the selected fuel type.
class _PriceContext extends ConsumerWidget {
  const _PriceContext({required this.fuelTypeId});

  final int fuelTypeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final stations = ref.watch(nearbyStationsProvider).value;
    final trend = ref.watch(priceTrendProvider).value;

    double? nearbyAvg;
    if (stations != null) {
      final sorted = [...stations]
        ..sort((a, b) {
          if (a.distanceKm == null || b.distanceKm == null) {
            return 0;
          }
          return a.distanceKm!.compareTo(b.distanceKm!);
        });
      final prices = [
        for (final entry in sorted.take(20))
          // Beyond the covered radius nothing is "nearby": from outside
          // Croatia this averaged the whole country and printed it as a local
          // price. The national figure below it is still true from anywhere.
          if (entry.distanceKm == null || entry.distanceKm! <= _coveredRadiusKm)
            if (entry.station.cheapestFor(fuelTypeId) case final double price)
              price,
      ];
      if (prices.isNotEmpty) {
        nearbyAvg = prices.reduce((a, b) => a + b) / prices.length;
      }
    }

    double? nationalAvg;
    if (trend != null) {
      final series = [
        for (final point in trend)
          if (point.fuelTypeId == fuelTypeId) point,
      ];
      if (series.isNotEmpty) {
        nationalAvg = series.last.avgPrice;
      }
    }

    if (nearbyAvg == null && nationalAvg == null) {
      return const SizedBox.shrink();
    }

    Widget metric(String label, double value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: GarageTheme.eyebrow(context)),
          Text(
            format.formatMoney(value),
            style: GarageTheme.numeric(
              Theme.of(context).textTheme.titleMedium!,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GarageTokens.space4,
        0,
        GarageTokens.space4,
        GarageTokens.space3,
      ),
      child: Row(
        children: [
          if (nearbyAvg != null) metric(l10n.stationsAvgNearby, nearbyAvg),
          if (nationalAvg != null)
            metric(l10n.stationsNationalAvg, nationalAvg),
        ],
      ),
    );
  }
}
