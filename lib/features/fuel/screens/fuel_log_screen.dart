import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/empty_state_art.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/lazy_month_list.dart';
import '../../../core/widgets/month_header.dart';
import '../../../domain/format/month_grouping.dart';
import '../../../domain/entities/fuel_entry.dart';
import '../../../domain/fuel/fuel_economy.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/fuel_providers.dart';
import '../widgets/fuel_entry_row.dart';
import '../widgets/fuel_entry_sheet.dart';
import '../../../domain/entities/attachment.dart';
import '../../vehicles/car_title.dart';

class FuelLogScreen extends ConsumerWidget {
  const FuelLogScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(locale: locale, preferences: prefs);

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
    // One query for the whole history rather than one per visible row, and the
    // same provider the timeline reads. Empty while it loads, so the markers
    // appear a moment later instead of the list waiting on them.
    final withAttachments =
        ref.watch(entriesWithAttachmentsProvider).value ?? const <String>{};

    final carName = ref.watch(vehicleProvider(vehicleId)).value?.nickname;
    return GaragePageScaffold(
      // With two cars a log headed "Fuel" was anybody's.
      title: carTitle(carName, l10n.fuelTitle),
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
              empty: () => EmptyState(
                motif: EmptyStateMotif.fuel,
                message: l10n.fuelEmpty,
              ),
              data: (list) => LazyMonthList<FuelEntry>(
                padding: const EdgeInsets.only(
                  bottom: GarageTokens.fabClearance,
                ),
                groups: MonthGrouping.of(list, (e) => e.date),
                header: (context, group) =>
                    MonthHeader(month: group.month, locale: locale),
                row: (context, entry) => Padding(
                  padding: const EdgeInsets.fromLTRB(
                    GarageTokens.space4,
                    0,
                    GarageTokens.space4,
                    GarageTokens.space2,
                  ),
                  child: Dismissible(
                    key: ValueKey(entry.id),
                    direction: DismissDirection.endToStart,
                    background: const DeleteSwipeBackground(),
                    confirmDismiss: (_) => confirmDelete(context),
                    onDismissed: (_) => deleteSwipedEntry(
                      context,
                      delete: () async {
                        await ref.read(fuelRepositoryProvider).delete(entry.id);
                        await sweepAttachments(
                          ref.read(attachmentRepositoryProvider),
                          kind: AttachmentEntryKind.fuel,
                          entryId: entry.id,
                        );
                      },
                      refresh: () =>
                          ref.invalidate(rawFuelEntriesProvider(vehicleId)),
                    ),
                    child: FuelEntryRow(
                      entry: entry,
                      point: pointsByEntry[entry.id],
                      allPoints: points,
                      range: range,
                      format: format,
                      energy: energy,
                      hasAttachment: withAttachments.contains(entry.id),
                      onTap: () => showFuelEntrySheet(
                        context,
                        vehicleId,
                        existing: entry,
                      ),
                    ),
                  ),
                ),
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
