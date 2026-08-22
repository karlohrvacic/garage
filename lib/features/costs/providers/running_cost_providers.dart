import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/costs/prorated_spend.dart';
import '../../../domain/costs/running_cost.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import 'cost_providers.dart';

/// What one vehicle has cost since the household started tracking it.
///
/// Reads all three spending tables plus the odometer, because the question
/// "what does this car cost me" has no single table behind it. Distance and
/// span both run from the vehicle's baseline, which is precisely what that
/// field records: the point from which this household has been paying.
final runningCostProvider = FutureProvider.family<RunningCost?, String>((
  ref,
  vehicleId,
) async {
  final vehicle = await ref.watch(vehicleProvider(vehicleId).future);
  if (vehicle == null) {
    return null;
  }

  final fuel = await ref.watch(rawFuelEntriesProvider(vehicleId).future);
  final services = await ref.watch(serviceEntriesProvider(vehicleId).future);
  final costs = await ref.watch(costEntriesProvider(vehicleId).future);
  final currentOdometer = await ref.watch(
    currentOdometerProvider(vehicleId).future,
  );

  var fuelSpend = 0.0;
  for (final entry in fuel) {
    fuelSpend += entry.total ?? 0;
  }
  var serviceSpend = 0.0;
  for (final entry in services) {
    serviceSpend += entry.cost ?? 0;
  }
  final until = DateTime.now().toUtc();
  final otherSpend = proratedSpend(
    costs,
    since: vehicle.baselineDate,
    until: until,
  );

  return RunningCost.of(
    fuel: fuelSpend,
    service: serviceSpend,
    other: otherSpend,
    distanceKm:
        (currentOdometer ?? vehicle.baselineOdometerKm) -
        vehicle.baselineOdometerKm,
    since: vehicle.baselineDate,
    until: until,
  );
});
