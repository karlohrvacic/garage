import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../domain/entities/fuel_entry.dart';
import '../../../domain/fuel/energy_type.dart';
import '../../../domain/fuel/economy_deviation.dart';
import '../../../domain/fuel/fuel_economy.dart';

/// One fill-up as a row: date and odometer, what went in and what it cost,
/// and the economy that tankful worked out to, coloured against this car's
/// own best and worst.
///
/// Shared by the fuel log and the vehicle's Economy tab, so a fill-up reads
/// the same wherever it is met. It was the log's private row until the
/// seventh critique found the per-tank figure a screen away from the tab
/// named for it.
class FuelEntryRow extends StatelessWidget {
  const FuelEntryRow({
    super.key,
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
