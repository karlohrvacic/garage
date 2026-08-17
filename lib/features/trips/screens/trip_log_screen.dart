import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/entities/trip_entry.dart';
import '../../../domain/trips/trip_log.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../../vehicles/vehicle_choice.dart';
import '../providers/fleet_trip_providers.dart';
import '../providers/trip_providers.dart';
import '../widgets/trip_entry_sheet.dart';

/// A mileage logbook: what was driven, where, and whether it was work.
///
/// Separate from the timeline because it answers a different question. The
/// timeline is "what happened to this car"; this is "what did I drive, and how
/// much of it can I claim".
class TripLogScreen extends ConsumerStatefulWidget {
  const TripLogScreen({super.key});

  @override
  ConsumerState<TripLogScreen> createState() => _TripLogScreenState();
}

class _TripLogScreenState extends ConsumerState<TripLogScreen> {
  String? _vehicleId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vehicles = ref.watch(vehiclesProvider).value ?? const [];
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final chosen = chosenVehicleId(vehicles, _vehicleId);
    final trips = chosen == null
        ? ref.watch(allTripsProvider)
        : ref.watch(tripEntriesProvider(chosen));
    final vehicleNames = {for (final v in vehicles) v.id: v.nickname};

    return GaragePageScaffold(
      title: l10n.tripsTitle,
      contentWidth: ContentWidth.wide,
      actions: [
        DropdownButton<String?>(
          value: chosen,
          underline: const SizedBox.shrink(),
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.statsAllVehicles)),
            for (final vehicle in vehicles)
              DropdownMenuItem(
                value: vehicle.id,
                child: Text(vehicle.nickname),
              ),
          ],
          onChanged: (value) => setState(() => _vehicleId = value),
        ),
        const SizedBox(width: GarageTokens.space2),
      ],
      floatingActionButton: vehicles.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  showTripEntrySheet(context, chosen ?? vehicles.first.id),
              icon: const Icon(Icons.add),
              label: Text(l10n.tripAdd),
            ),
      body: AsyncValueView<List<TripEntry>>(
        value: trips,
        onRetry: () => ref
          ..invalidate(allTripsProvider)
          ..invalidate(tripEntriesProvider),
        empty: () => EmptyState(message: l10n.tripsEmpty),
        data: (list) => ListView(
          padding: const EdgeInsets.only(bottom: GarageTokens.space8),
          children: [
            Padding(
              padding: const EdgeInsets.all(GarageTokens.space4),
              child: _TripSummaryCard(
                summary: TripLog.summarise(list),
                format: format,
              ),
            ),
            for (final trip in list)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: GarageTokens.space4,
                  vertical: GarageTokens.space1,
                ),
                child: _TripRow(
                  trip: trip,
                  vehicleName: vehicleNames[trip.vehicleId] ?? '',
                  format: format,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard({required this.summary, required this.format});

  final TripSummary summary;
  final UnitFormat format;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    Widget cell(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: GarageTheme.numeric(textTheme.titleMedium!)),
          Text(label, style: textTheme.labelSmall),
        ],
      ),
    );

    final speed = summary.kmPerHour;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                cell(l10n.tripTotalTrips, '${summary.trips}'),
                cell(
                  l10n.tripTotalDistance,
                  format.formatDistance(summary.distanceKm, decimals: 0),
                ),
              ],
            ),
            const SizedBox(height: GarageTokens.space3),
            Row(
              children: [
                cell(
                  l10n.tripTotalTime,
                  summary.minutes <= 0
                      ? UnitFormat.emptyValue
                      : l10n.tripHoursMinutes(
                          summary.minutes ~/ 60,
                          summary.minutes % 60,
                        ),
                ),
                cell(
                  l10n.tripAverageSpeed,
                  speed == null
                      ? UnitFormat.emptyValue
                      : '${format.formatDistance(speed, decimals: 0)}/h',
                ),
              ],
            ),
            const Divider(height: GarageTokens.space5),
            // The split is the reason a logbook exists, so it gets its own row
            // rather than being one figure among four.
            Row(
              children: [
                cell(
                  l10n.tripPurposeBusiness,
                  format.formatDistance(summary.businessKm, decimals: 0),
                ),
                cell(
                  l10n.tripPurposePrivate,
                  format.formatDistance(summary.privateKm, decimals: 0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TripRow extends ConsumerWidget {
  const _TripRow({
    required this.trip,
    required this.vehicleName,
    required this.format,
  });

  final TripEntry trip;
  final String vehicleName;
  final UnitFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final route = [
      trip.fromPlace,
      trip.toPlace,
    ].where((part) => part != null && part.isNotEmpty).join(' → ');
    final details = [
      format.formatShortDate(trip.date),
      vehicleName,
      if (route.isNotEmpty) route,
    ].where((part) => part.isNotEmpty).join(' · ');

    return Dismissible(
      key: ValueKey(trip.id),
      direction: DismissDirection.endToStart,
      background: const DeleteSwipeBackground(),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) => deleteSwipedEntry(
        context,
        delete: () => ref.read(tripRepositoryProvider).delete(trip.id),
        refresh: () => ref
          ..invalidate(tripEntriesProvider(trip.vehicleId))
          ..invalidate(allTripsProvider),
      ),
      child: Card(
        child: ListTile(
          leading: Icon(Icons.route_outlined, color: context.tokens.muted),
          onTap: () =>
              showTripEntrySheet(context, trip.vehicleId, existing: trip),
          title: Text(
            trip.title?.isNotEmpty == true ? trip.title! : l10n.tripsTitle,
          ),
          subtitle: Text(details),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                format.formatDistance(trip.distanceKm, decimals: 0),
                style: GarageTheme.numeric(
                  Theme.of(context).textTheme.labelMedium!,
                ),
              ),
              Text(
                trip.purpose == TripPurpose.business
                    ? l10n.tripPurposeBusiness
                    : l10n.tripPurposePrivate,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
