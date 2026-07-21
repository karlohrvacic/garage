import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../domain/entities/fuel_entry.dart';
import '../../../domain/fuel/fuel_economy.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/fuel_providers.dart';
import '../widgets/fuel_entry_sheet.dart';

class FuelLogScreen extends ConsumerWidget {
  const FuelLogScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );

    final entries = ref.watch(fuelEntriesProvider(vehicleId));
    final points = ref.watch(economyPointsProvider(vehicleId)).value ?? const [];
    final average = ref.watch(averageEconomyProvider(vehicleId)).value;
    final pointsByEntry = {for (final p in points) p.entryId: p};
    final latestCostPerKm = points.isEmpty ? null : points.last.costPerKm;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.fuelTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFuelEntrySheet(context, vehicleId),
        icon: const Icon(Icons.local_gas_station),
        label: Text(l10n.fuelAdd),
      ),
      body: Column(
        children: [
          _EconomyHeader(
            average: format.formatEconomy(average),
            costPerKm: latestCostPerKm == null
                ? UnitFormat.emptyValue
                : format.formatMoney(latestCostPerKm),
          ),
          Expanded(
            child: AsyncValueView<List<FuelEntry>>(
              value: entries,
              onRetry: () => ref.invalidate(rawFuelEntriesProvider(vehicleId)),
              empty: () => EmptyState(message: l10n.fuelEmpty),
              data: (list) => ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: GarageTokens.space4,
                ),
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: GarageTokens.space2),
                itemBuilder: (context, index) {
                  final entry = list[index];
                  final point = pointsByEntry[entry.id];
                  return _FuelRow(
                    entry: entry,
                    point: point,
                    format: format,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EconomyHeader extends StatelessWidget {
  const _EconomyHeader({required this.average, required this.costPerKm});

  final String average;
  final String costPerKm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final numeric = GarageTheme.numeric(
      Theme.of(context).textTheme.titleLarge!,
    );
    return Padding(
      padding: const EdgeInsets.all(GarageTokens.space4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.fuelAverage,
                  style: TextStyle(color: context.tokens.muted),
                ),
                Text(average, style: numeric),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.fuelPricePerUnit} / km',
                  style: TextStyle(color: context.tokens.muted),
                ),
                Text(costPerKm, style: numeric),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FuelRow extends StatelessWidget {
  const _FuelRow({required this.entry, required this.point, required this.format});

  final FuelEntry entry;
  final EconomyPoint? point;
  final UnitFormat format;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final numeric = GarageTheme.numeric(
      Theme.of(context).textTheme.bodyMedium!,
    );

    final String economyLabel;
    if (point != null) {
      economyLabel = format.formatEconomy(point!.litersPer100Km);
    } else if (entry.fullTank) {
      economyLabel = l10n.fuelEconomyUnavailable;
    } else {
      economyLabel = UnitFormat.emptyValue;
    }

    return Card(
      child: ListTile(
        title: Text(
          '${format.formatShortDate(entry.date)} · '
          '${format.formatDistance(entry.odometerKm.toDouble(), decimals: 0)}',
        ),
        subtitle: Text(
          '${format.formatVolume(entry.volumeL)} · '
          '${format.formatMoney(entry.total)}',
        ),
        trailing: Text(economyLabel, style: numeric),
      ),
    );
  }
}
