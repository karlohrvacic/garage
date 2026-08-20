import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../domain/entities/fuel_entry.dart';
import '../../../domain/fuel/energy_type.dart';
import '../../../domain/fuel/fuel_economy.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
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

    final energy = ref.watch(vehicleEnergyProvider(vehicleId));
    final entries = ref.watch(fuelEntriesProvider(vehicleId));
    final points =
        ref.watch(economyPointsProvider(vehicleId)).value ?? const [];
    final average = ref.watch(averageEconomyProvider(vehicleId)).value;
    final pointsByEntry = {for (final p in points) p.entryId: p};
    final latestCostPerKm = points.isEmpty ? null : points.last.costPerKm;
    // Null until the car has two figures far enough apart to have a range;
    // without one there is no basis for calling a tank good or bad.
    final range = EconomyRange.of(points);

    return GaragePageScaffold(
      title: l10n.fuelTitle,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFuelEntrySheet(context, vehicleId),
        icon: const Icon(Icons.local_gas_station),
        label: Text(l10n.fuelAdd),
      ),
      body: Column(
        children: [
          _EconomyHeader(
            average: format.formatEconomy(average, energy),
            costPerDistance: format.formatCostPerDistance(latestCostPerKm),
          ),
          Expanded(
            child: AsyncValueView<List<FuelEntry>>(
              value: entries,
              onRetry: () => ref.invalidate(rawFuelEntriesProvider(vehicleId)),
              empty: () => EmptyState(message: l10n.fuelEmpty),
              data: (list) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  GarageTokens.space4,
                  0,
                  GarageTokens.space4,
                  GarageTokens.fabClearance,
                ),
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: GarageTokens.space2),
                itemBuilder: (context, index) {
                  final entry = list[index];
                  final point = pointsByEntry[entry.id];
                  return Dismissible(
                    key: ValueKey(entry.id),
                    direction: DismissDirection.endToStart,
                    background: const DeleteSwipeBackground(),
                    confirmDismiss: (_) => confirmDelete(context),
                    onDismissed: (_) => deleteSwipedEntry(
                      context,
                      delete: () =>
                          ref.read(fuelRepositoryProvider).delete(entry.id),
                      refresh: () =>
                          ref.invalidate(rawFuelEntriesProvider(vehicleId)),
                    ),
                    child: _FuelRow(
                      entry: entry,
                      point: point,
                      range: range,
                      format: format,
                      energy: energy,
                      onTap: () => showFuelEntrySheet(
                        context,
                        vehicleId,
                        existing: entry,
                      ),
                    ),
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
  const _EconomyHeader({required this.average, required this.costPerDistance});

  final String average;

  /// Already carrying its own unit, which is why the label beside it does not
  /// name one: a household reading miles was shown a per-kilometre figure
  /// under a heading assembled as "Price per unit / km".
  final String costPerDistance;

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
                  l10n.fuelCostPerDistance,
                  style: TextStyle(color: context.tokens.muted),
                ),
                Text(costPerDistance, style: numeric),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FuelRow extends StatelessWidget {
  const _FuelRow({
    required this.entry,
    required this.point,
    required this.range,
    required this.format,
    required this.energy,
    required this.onTap,
  });

  final FuelEntry entry;
  final EconomyPoint? point;

  /// This car's own best and worst, or null when its history is too short or
  /// too flat to place a tank in.
  final EconomyRange? range;

  final UnitFormat format;
  final EnergyType energy;
  final VoidCallback onTap;

  /// Green at this car's frugal end, red at its thirsty one.
  ///
  /// Against the car's own history rather than a fixed band: a van at 9 l/100km
  /// is doing well and a city car at 9 is not, and the app has no idea which it
  /// is looking at. Null leaves the figure in the ordinary text colour, which
  /// is what a car with nothing to compare against deserves.
  Color? _verdict(BuildContext context) {
    final span = range;
    final economy = point?.litersPer100Km;
    if (span == null || economy == null) {
      return null;
    }
    final position = span.fractionFor(economy);
    final tokens = context.tokens;
    if (position >= 0.66) {
      return tokens.success;
    }
    if (position >= 0.33) {
      return tokens.warn;
    }
    return tokens.danger;
  }

  @override
  Widget build(BuildContext context) {
    final numeric = GarageTheme.numeric(
      Theme.of(context).textTheme.bodyMedium!,
    );

    // Rows without a computable span get the compact placeholder; the long
    // "not enough fills" explanation is header-sized and would crush the
    // ListTile title into a one-character-per-line column.
    final economyLabel = point != null
        ? format.formatEconomy(point!.litersPer100Km, energy)
        : UnitFormat.emptyValue;

    return Card(
      child: ListTile(
        title: Text(
          '${format.formatShortDate(entry.date)} · '
          '${format.formatDistance(entry.odometerKm.toDouble(), decimals: 0)}',
        ),
        subtitle: Text(
          '${format.formatEnergy(entry.volumeL, energy)} · '
          '${format.formatMoney(entry.total)}',
        ),
        trailing: Text(
          economyLabel,
          style: numeric.copyWith(color: _verdict(context)),
        ),
        onTap: onTap,
      ),
    );
  }
}
