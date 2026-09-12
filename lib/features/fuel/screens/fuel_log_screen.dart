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
import '../../../domain/fuel/energy_type.dart';
import '../../../domain/fuel/economy_deviation.dart';
import '../../../domain/fuel/fuel_economy.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/fuel_providers.dart';
import '../widgets/fuel_entry_sheet.dart';
import '../../../domain/entities/attachment.dart';

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
      title: carName == null ? l10n.fuelTitle : '$carName · ${l10n.fuelTitle}',
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
                    child: _FuelRow(
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

class _FuelRow extends StatelessWidget {
  const _FuelRow({
    required this.entry,
    required this.point,
    required this.allPoints,
    required this.range,
    required this.format,
    required this.energy,
    required this.hasAttachment,
    required this.onTap,
  });

  final FuelEntry entry;
  final EconomyPoint? point;

  /// Every closed tank on this car, so one can be measured against the rest.
  final List<EconomyPoint> allPoints;

  /// This car's own best and worst, or null when its history is too short or
  /// too flat to place a tank in.
  final EconomyRange? range;

  final UnitFormat format;
  final EnergyType energy;

  /// Whether a receipt hangs off this fill-up.
  final bool hasAttachment;

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

    final l10n = AppLocalizations.of(context)!;
    final station = (entry.station ?? '').trim();
    // Assembled from the parts that exist rather than interpolated, so a
    // fill-up with no station does not leave a dangling separator where one
    // would have been.
    final details = [
      format.formatEnergy(entry.volumeL, energy),
      format.formatMoney(entry.total),
      if (station.isNotEmpty) station,
    ].join(' · ');

    // A note and a receipt were invisible from this list, exactly as they once
    // were on the timeline: the only way to learn a fill-up had either was to
    // open it. Same icons and same meaning as the timeline's markers — two
    // lists marking the same thing two different ways would be worse than
    // neither.
    final markers = <Widget>[
      if ((entry.notes ?? '').trim().isNotEmpty)
        Icon(
          Icons.sticky_note_2_outlined,
          size: 16,
          color: context.tokens.muted,
          semanticLabel: l10n.timelineHasNote,
        ),
      if (hasAttachment)
        Icon(
          Icons.attach_file,
          size: 16,
          color: context.tokens.muted,
          semanticLabel: l10n.timelineHasAttachment,
        ),
    ];

    final economy = Text(
      economyLabel,
      style: numeric.copyWith(color: _verdict(context)),
    );

    /// What the cheapest station in reach charged the day this was logged, or
    /// null when nothing was recorded or the driver already had the best
    /// price.
    ///
    /// Deliberately not a warning: under a price cap the gap is usually nil,
    /// and a red flag on a fill-up nobody can now undo would be nagging about
    /// the past.
    String? priceNote() {
      final snapshot = entry.priceContext;
      if (snapshot == null) {
        return null;
      }
      final over = snapshot.overpaidPerUnit(entry.pricePerL);
      if (over == null) {
        return null;
      }
      // A cent either way is the dataset's own rounding, not a decision
      // anyone made differently.
      if (over <= 0.01) {
        return l10n.fuelCheapestNearby;
      }
      return l10n.fuelCheaperNearby(
        format.formatMoney(over),
        format.formatDistance(snapshot.distanceKm),
        snapshot.station,
      );
    }

    /// By how much this tank differed from the car's usual.
    ///
    /// The number behind the colour the economy figure already carries: green
    /// and red say where a tank sits between best and worst, never by how
    /// much. Stated flatly, in muted type, with no warning styling — a tank
    /// already burned is not something anyone can act on.
    String? economyNote() {
      final deviation = deviationFor(entry.id, allPoints);
      if (!worthMentioning(deviation)) {
        return null;
      }
      final percent = '${(deviation!.abs() * 100).round()}%';
      return deviation > 0
          ? l10n.fuelWorseThanUsual(percent)
          : l10n.fuelBetterThanUsual(percent);
    }

    return Card(
      child: ListTile(
        title: Text(
          '${format.formatShortDate(entry.date)} · '
          '${format.formatDistance(entry.odometerKm.toDouble(), decimals: 0)}',
        ),
        // Extra lines only when there is something to say. A row that always
        // carries one stops being read, which is why the tyre screen hides its
        // age note the same way.
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(details),
            for (final note in [economyNote(), priceNote()])
              if (note != null)
                Text(
                  note,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: context.tokens.muted),
                ),
          ],
        ),
        // The markers share the trailing slot with the number this screen
        // exists for, and must not push it out.
        trailing: markers.isEmpty
            ? economy
            : Row(
                mainAxisSize: MainAxisSize.min,
                spacing: GarageTokens.space2,
                children: [...markers, economy],
              ),
        onTap: onTap,
      ),
    );
  }
}
