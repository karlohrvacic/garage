import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/cost_entry.dart';
import '../../../domain/entities/fuel_entry.dart';
import '../../../domain/entities/service_entry.dart';
import '../../../domain/fuel/fuel_economy.dart';
import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';

class OdometerReading {
  const OdometerReading({required this.date, required this.km});

  final DateTime date;
  final int km;
}

/// Everything the Stats screen aggregates, already merged across the selected
/// vehicles. Odometer readings stay grouped per vehicle: a fleet-level
/// distance is the sum of per-vehicle spans, never a span across different
/// odometers.
class StatsData {
  const StatsData({
    required this.fuel,
    required this.services,
    required this.costs,
    required this.economy,
    required this.readingsPerVehicle,
  });

  final List<FuelEntry> fuel;
  final List<ServiceEntry> services;
  final List<CostEntry> costs;
  final List<EconomyPoint> economy;
  final List<List<OdometerReading>> readingsPerVehicle;
}

/// Data for the Stats screen. A null vehicle id means the whole fleet.
final statsDataProvider = FutureProvider.family<StatsData, String?>((
  ref,
  vehicleId,
) async {
  final vehicles = await ref.watch(vehiclesProvider.future);
  final selected = vehicleId == null
      ? vehicles
      : vehicles.where((v) => v.id == vehicleId).toList(growable: false);

  final fuel = <FuelEntry>[];
  final services = <ServiceEntry>[];
  final costs = <CostEntry>[];
  final economy = <EconomyPoint>[];
  final readingsPerVehicle = <List<OdometerReading>>[];

  await Future.wait([
    for (final vehicle in selected)
      Future(() async {
        final vehicleFuel = await ref.watch(
          rawFuelEntriesProvider(vehicle.id).future,
        );
        final vehicleServices = await ref.watch(
          serviceEntriesProvider(vehicle.id).future,
        );
        final vehicleCosts = await ref.watch(
          costEntriesProvider(vehicle.id).future,
        );
        final vehicleEconomy = await ref.watch(
          economyPointsProvider(vehicle.id).future,
        );

        fuel.addAll(vehicleFuel);
        services.addAll(vehicleServices);
        costs.addAll(vehicleCosts);
        economy.addAll(vehicleEconomy);
        readingsPerVehicle.add([
          for (final entry in vehicleFuel)
            OdometerReading(date: entry.date, km: entry.odometerKm),
          for (final entry in vehicleServices)
            OdometerReading(date: entry.date, km: entry.odometerKm),
          for (final entry in vehicleCosts)
            if (entry.odometerKm != null)
              OdometerReading(date: entry.date, km: entry.odometerKm!),
        ]);
      }),
  ]);

  return StatsData(
    fuel: fuel,
    services: services,
    costs: costs,
    economy: economy,
    readingsPerVehicle: readingsPerVehicle,
  );
});
