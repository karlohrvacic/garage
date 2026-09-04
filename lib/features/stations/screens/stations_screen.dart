import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../domain/stations/price_trend.dart';
import '../widgets/price_trend_chart.dart';
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

  /// Asks for location, and says so when the answer is no.
  ///
  /// A refusal is not an error the app can retry its way out of, and a button
  /// that quietly does nothing is worse than one that explains itself.
  Future<void> _askForLocation(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final granted = await ref.read(requestLocationProvider)();
    if (!context.mounted) {
      return;
    }
    if (!granted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsPumpAutofillDenied)));
      return;
    }
    ref
      ..invalidate(positionProvider)
      ..invalidate(nearbyStationsProvider);
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
      // One scroll for the whole page. The header used to be pinned above an
      // Expanded list, so the picks, the averages and the chart left about
      // two and a half rows of the list on a phone — and fewer on a desktop
      // window, where the list is the reason the screen exists.
      // The fuel chips sit above the async view, not inside it: an errored
      // feed used to replace the whole screen with one message, taking the
      // only control on it — the reader could not even switch fuel to see
      // whether the other tab had loaded.
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(GarageTokens.space4),
            // A Wrap, not a Row: at a large font scale three chips are wider
            // than a phone, and a Row cannot break the line.
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: GarageTokens.space2,
                runSpacing: GarageTokens.space2,
                children: [
                  for (final (typeId, label) in [
                    (_petrol, l10n.stationsFuelPetrol),
                    (_diesel, l10n.stationsFuelDiesel),
                    (_lpg, l10n.stationsFuelLpg),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _fuelTypeId == typeId,
                      onSelected: (_) => setState(() => _fuelTypeId = typeId),
                    ),
                ],
              ),
            ),
          ),
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
                final covered = _covered(stations) ?? const <NearbyStation>[];

                // Every price here is Croatian. Opened from elsewhere the screen
                // listed the whole country nearest-first, which put a station most
                // of the way around the world under the heading "average nearby".
                // Where the data stops is the useful thing to say.
                String? outOfRange;
                if (hasLocation && selling.isNotEmpty) {
                  final nearest = selling
                      .map((entry) => entry.distanceKm!)
                      .reduce(math.min);
                  if (nearest > _coveredRadiusKm) {
                    outOfRange = l10n.stationsOutOfRange(
                      format.formatDistance(nearest, decimals: 0),
                    );
                  }
                }

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _PriceContext(fuelTypeId: _fuelTypeId),
                    ),
                    if (covered.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: StationPicksCard(
                          stations: covered,
                          fuelTypeId: _fuelTypeId,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: AreaAveragesCard(
                          stations: covered,
                          fuelTypeId: _fuelTypeId,
                        ),
                      ),
                    ],
                    // What the list is, when it is not what the screen promises.
                    // "Location unavailable — sorted by price" left out the part
                    // that matters: without a position this is the cheapest fifty
                    // in the country, and the top one may be a hundred kilometres
                    // away.
                    if (!hasLocation && visible.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            GarageTokens.space4,
                            0,
                            GarageTokens.space4,
                            GarageTokens.space3,
                          ),
                          child: Card(
                            key: const Key('stations-no-location'),
                            child: Padding(
                              padding: const EdgeInsets.all(
                                GarageTokens.space4,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.stationsNoLocationTitle,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: GarageTokens.space1),
                                  Text(
                                    l10n.stationsNoLocationBody,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: context.tokens.muted),
                                  ),
                                  Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: TextButton(
                                      // Through the permission gate, not by
                                      // invalidating the position: the position
                                      // provider swallows a refusal and returns
                                      // null, so a second denial left this button
                                      // doing nothing visible at all.
                                      onPressed: () =>
                                          _askForLocation(context, ref),
                                      child: Text(l10n.stationsUseLocation),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (visible.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(message: l10n.stationsEmpty),
                      )
                    else if (outOfRange != null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(message: outOfRange),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          GarageTokens.space4,
                          0,
                          GarageTokens.space4,
                          GarageTokens.space4,
                        ),
                        sliver: SliverList.separated(
                          key: const Key('station-list'),
                          itemCount: visible.length + 1,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: GarageTokens.space2),
                          itemBuilder: (context, index) {
                            if (index == visible.length) {
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
                            final entry = visible[index];
                            final station = entry.station;
                            final price = station.cheapestFor(_fuelTypeId)!;
                            final operator = station.operatorName;
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
                                      const SizedBox(
                                        width: GarageTokens.space1,
                                      ),
                                    ],
                                    // The station's own name first: it is what is on
                                    // the sign being driven towards. Two rows of one
                                    // operator read identically when the holding
                                    // company led and the name was what got cut.
                                    Expanded(
                                      child: Text(
                                        station.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  // Address first: at one line with an ellipsis,
                                  // whatever leads is what survives, and where the
                                  // station is beats who owns it.
                                  [
                                    ?station.address,
                                    ?station.place,
                                    ?operator,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                          Theme.of(
                                            context,
                                          ).textTheme.labelSmall!,
                                        ),
                                      ),
                                  ],
                                ),
                                onTap: () =>
                                    showStationDetailSheet(context, station),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
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

    // The same test the list uses: with no position every station in the
    // country is "nearby", which is not a claim to print.
    final located = stations?.any((entry) => entry.distanceKm != null) ?? false;
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

    // Sorted and smoothed rather than taken off the end of whatever the feed
    // sent: single days in this series swing by tens of cents depending on how
    // many stations reported, and the raw last point was reporting that wobble
    // as the national average.
    final series = trend == null
        ? const <TrendPoint>[]
        : PriceTrend.forFuel(trend, fuelTypeId);
    final smoothed = PriceTrend.smoothed(series);
    final double? nationalAvg = smoothed.isEmpty
        ? null
        : smoothed.last.avgPrice;
    final change = PriceTrend.change(series);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Only with a position. Unlocated, "nearby" averaged the first
              // twenty rows the feed happened to send — one town or one brand —
              // and calling that the country was a second claim with no basis,
              // beside the ministry's real national figure.
              if (located && nearbyAvg != null)
                metric(l10n.stationsAvgNearby, nearbyAvg),
              if (nationalAvg != null)
                metric(l10n.stationsNationalAvg, nationalAvg),
            ],
          ),
          if (change != null) ...[
            const SizedBox(height: GarageTokens.space2),
            Text(
              switch (change) {
                final c when c.steady => l10n.stationsTrendSteady,
                final c when c.rising => l10n.stationsTrendUp(
                  format.formatMoney(c.delta.abs()),
                ),
                final c => l10n.stationsTrendDown(
                  format.formatMoney(c.delta.abs()),
                ),
              },
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: change.steady
                    ? context.tokens.muted
                    : change.rising
                    ? context.tokens.danger
                    : context.tokens.success,
              ),
            ),
          ],
          if (smoothed.length >= PriceTrend.minimumReadings) ...[
            const SizedBox(height: GarageTokens.space3),
            PriceTrendChart(series: smoothed, format: format),
          ],
        ],
      ),
    );
  }
}
