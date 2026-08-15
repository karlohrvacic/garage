import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';

enum TimelineKind { fuel, service, cost }

/// One event in the household's history, newest first in [timelineProvider].
class TimelineItem {
  const TimelineItem({
    required this.kind,
    required this.date,
    required this.vehicleId,
    required this.amount,
    required this.createdBy,
    this.serviceTypeKeys = const [],
    this.costCategory,
    this.odometerKm,
  });

  final TimelineKind kind;
  final DateTime date;
  final String vehicleId;
  final double? amount;

  /// Who logged it. Shown on the row so a household can see who has been
  /// keeping the records — and who paid.
  final String createdBy;
  final List<String> serviceTypeKeys;
  final String? costCategory;
  final int? odometerKm;
}

/// Every fill-up, service, and cost across the fleet, newest first.
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

        items.addAll([
          for (final entry in fuel)
            TimelineItem(
              kind: TimelineKind.fuel,
              date: entry.date,
              vehicleId: vehicle.id,
              amount: entry.total,
              createdBy: entry.createdBy,
              odometerKm: entry.odometerKm,
            ),
          for (final entry in services)
            TimelineItem(
              kind: TimelineKind.service,
              date: entry.date,
              vehicleId: vehicle.id,
              amount: entry.cost,
              createdBy: entry.createdBy,
              serviceTypeKeys: entry.serviceTypeKeys,
              odometerKm: entry.odometerKm,
            ),
          for (final entry in costs)
            TimelineItem(
              kind: TimelineKind.cost,
              date: entry.date,
              vehicleId: vehicle.id,
              amount: entry.amount,
              createdBy: entry.createdBy,
              costCategory: entry.category,
              odometerKm: entry.odometerKm,
            ),
        ]);
      }),
  ]);

  items.sort((a, b) => b.date.compareTo(a.date));
  return items;
});
