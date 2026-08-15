import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/links/url_opener.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../domain/stations/fuel_station.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/station_providers.dart';

Future<void> showStationDetailSheet(BuildContext context, FuelStation station) {
  return showAdaptiveEntrySheet<void>(
    context,
    (_) => StationDetailSheet(station: station),
  );
}

class StationDetailSheet extends ConsumerWidget {
  const StationDetailSheet({required this.station, super.key});

  final FuelStation station;

  Future<void> _openMap(WidgetRef ref) {
    return ref.read(urlOpenerProvider)(
      GarageLinks.mapSearch(lat: station.lat, lng: station.lng),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final favourites = ref.watch(favouriteStationsProvider);
    final isFavourite = favourites.contains(station.id);
    final prices = [...station.prices]
      ..sort((a, b) => a.fuelTypeId.compareTo(b.fuelTypeId));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(GarageTokens.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (station.brand != null &&
                          station.brand!.trim().length > 1)
                        Text(
                          station.brand!.toUpperCase(),
                          style: GarageTheme.eyebrow(context),
                        ),
                      Text(
                        station.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        [
                          if (station.address != null) station.address,
                          if (station.place != null) station.place,
                        ].whereType<String>().join(', '),
                        style: TextStyle(color: context.tokens.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.stationsFavourite,
                  icon: Icon(
                    isFavourite ? Icons.star : Icons.star_border,
                    color: isFavourite ? context.tokens.accent : null,
                  ),
                  onPressed: () => ref
                      .read(favouriteStationsProvider.notifier)
                      .toggle(station.id),
                ),
              ],
            ),
            const SizedBox(height: GarageTokens.space4),
            for (final price in prices)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: GarageTokens.space1,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(price.fuelName)),
                    Text(
                      format.formatMoney(price.price),
                      style: GarageTheme.numeric(
                        Theme.of(context).textTheme.bodyMedium!,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: GarageTokens.space5),
            FilledButton.icon(
              onPressed: () => _openMap(ref),
              icon: const Icon(Icons.map_outlined),
              label: Text(l10n.stationsOpenMap),
            ),
          ],
        ),
      ),
    );
  }
}
