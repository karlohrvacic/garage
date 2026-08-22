import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../income/providers/income_providers.dart';
import '../../odometer/providers/odometer_providers.dart';
import '../../trips/providers/trip_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';

enum TimelineKind { fuel, service, cost, odometer, trip, income }

/// One event in the household's history, newest first in [timelineProvider].
class TimelineItem {
  const TimelineItem({
    required this.kind,
    required this.entryId,
    required this.date,
    required this.vehicleId,
    required this.amount,
    required this.createdBy,
    this.serviceTypeKeys = const [],
    this.costCategory,
    this.odometerKm,
    this.distanceKm,
    this.isIncome = false,
    this.notes,
    this.createdAt,
  });

  final TimelineKind kind;

  /// The id of the row this came from, so a tap can open that entry rather
  /// than the list it lives in.
  final String entryId;
  final DateTime date;
  final String vehicleId;
  final double? amount;

  /// Who logged it. Shown on the row so a household can see who has been
  /// keeping the records — and who paid.
  final String createdBy;
  final List<String> serviceTypeKeys;

  /// A cost category key, or an income category key — whichever kind this is.
  final String? costCategory;

  final int? odometerKm;

  /// Set on a trip: how far it went, so the row can say something other than
  /// an amount it does not have.
  final double? distanceKm;

  /// Money in rather than out. The timeline shows one column of amounts, and a
  /// refund that read like a bill would be worse than no figure at all.
  final bool isIncome;

  /// What somebody typed on the entry.
  ///
  /// Carried here so the history can be searched by it. The note is often the
  /// only place the distinguishing detail lives — the garage's name, the part
  /// that was fitted, why this fill-up was odd — and searching everything
  /// *except* the free-text field finds the one thing a person is least likely
  /// to remember and misses the thing they wrote down.
  final String? notes;

  /// When the entry was logged, not [date] (when it happened). Breaks ties
  /// between same-day entries so the one typed in more recently sorts first
  /// — [date] alone can't distinguish them, and two entries added minutes
  /// apart on the same calendar day is the ordinary case, not an edge one.
  final DateTime? createdAt;
}

/// Every entry of every kind across the fleet, newest first.
final timelineProvider = FutureProvider<List<TimelineItem>>((ref) async {
  final vehicles = await ref.watch(vehiclesProvider.future);
  final items = <TimelineItem>[];

  await Future.wait([
    for (final vehicle in vehicles)
      Future(() async {
        final fuel = await ref.watch(rawFuelEntriesProvider(vehicle.id).future);
        final services = await ref.watch(
          serviceEntriesProvider(vehicle.id).future,
        );
        final costs = await ref.watch(costEntriesProvider(vehicle.id).future);
        final readings = await ref.watch(
          odometerEntriesProvider(vehicle.id).future,
        );
        final trips = await ref.watch(tripEntriesProvider(vehicle.id).future);
        final income = await ref.watch(
          incomeEntriesProvider(vehicle.id).future,
        );

        items.addAll([
          for (final entry in fuel)
            TimelineItem(
              kind: TimelineKind.fuel,
              entryId: entry.id,
              date: entry.date,
              vehicleId: vehicle.id,
              amount: entry.total,
              createdBy: entry.createdBy,
              notes: entry.notes,
              odometerKm: entry.odometerKm,
              createdAt: entry.createdAt,
            ),
          for (final entry in services)
            TimelineItem(
              kind: TimelineKind.service,
              entryId: entry.id,
              date: entry.date,
              vehicleId: vehicle.id,
              amount: entry.cost,
              createdBy: entry.createdBy,
              notes: entry.notes,
              serviceTypeKeys: entry.serviceTypeKeys,
              odometerKm: entry.odometerKm,
              createdAt: entry.createdAt,
            ),
          for (final entry in costs)
            TimelineItem(
              kind: TimelineKind.cost,
              entryId: entry.id,
              date: entry.date,
              vehicleId: vehicle.id,
              amount: entry.amount,
              createdBy: entry.createdBy,
              notes: entry.notes,
              costCategory: entry.category,
              odometerKm: entry.odometerKm,
              createdAt: entry.createdAt,
            ),
          for (final entry in readings)
            TimelineItem(
              kind: TimelineKind.odometer,
              entryId: entry.id,
              date: entry.date,
              vehicleId: vehicle.id,
              amount: null,
              createdBy: entry.createdBy,
              notes: entry.notes,
              odometerKm: entry.odometerKm,
              createdAt: entry.createdAt,
            ),
          for (final entry in trips)
            TimelineItem(
              kind: TimelineKind.trip,
              entryId: entry.id,
              date: entry.date,
              vehicleId: vehicle.id,
              amount: null,
              createdBy: entry.createdBy,
              notes: entry.notes,
              odometerKm: entry.endOdometerKm,
              distanceKm: entry.distanceKm,
              createdAt: entry.createdAt,
            ),
          for (final entry in income)
            TimelineItem(
              kind: TimelineKind.income,
              entryId: entry.id,
              date: entry.date,
              vehicleId: vehicle.id,
              amount: entry.amount,
              createdBy: entry.createdBy,
              notes: entry.notes,
              costCategory: entry.category,
              odometerKm: entry.odometerKm,
              isIncome: true,
              createdAt: entry.createdAt,
            ),
        ]);
      }),
  ]);

  // Two entries on the same calendar date break the tie by when they were
  // logged, newest first. `List.sort` is not guaranteed stable, so sorting a
  // list of indices — falling back to original order rather than `0` — keeps
  // a genuine tie (createdAt missing, or equal) deterministic instead of
  // reordering on every rebuild.
  final order = List<int>.generate(items.length, (i) => i)
    ..sort((ia, ib) {
      final a = items[ia];
      final b = items[ib];
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) {
        return byDate;
      }
      final aCreatedAt = a.createdAt;
      final bCreatedAt = b.createdAt;
      if (aCreatedAt != null && bCreatedAt != null) {
        final byCreatedAt = bCreatedAt.compareTo(aCreatedAt);
        if (byCreatedAt != 0) {
          return byCreatedAt;
        }
      }
      return ia.compareTo(ib);
    });
  return [for (final i in order) items[i]];
});
