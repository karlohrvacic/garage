import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/cost_entry.dart';
import '../../../domain/entities/fuel_entry.dart';
import '../../../domain/entities/income_entry.dart';
import '../../../domain/entities/odometer_entry.dart';
import '../../../domain/entities/trip_entry.dart';
import '../../../domain/entities/service_entry.dart';
import '../../../domain/fuel/fuel_economy.dart';
import '../../../domain/stats/stats_period.dart';
import '../../costs/providers/cost_providers.dart';
import '../../income/providers/income_providers.dart';
import '../../trips/providers/trip_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../maintenance/providers/service_entry_providers.dart';
import '../../odometer/providers/odometer_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';

/// What put a reading on the odometer. The line chart colours by this, which
/// is the whole reason it is carried rather than merged away: a chart of
/// distance is more useful when it also says how the app came to know it.
enum OdometerSource { fuel, service, cost, reading, trip, income }

class OdometerReading {
  const OdometerReading({
    required this.date,
    required this.km,
    required this.source,
  });

  final DateTime date;
  final int km;
  final OdometerSource source;
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
    required this.readings,
    required this.trips,
    required this.income,
    required this.economy,
    required this.readingsPerVehicle,
  });

  final List<FuelEntry> fuel;
  final List<ServiceEntry> services;
  final List<CostEntry> costs;
  final List<OdometerEntry> readings;
  final List<TripEntry> trips;
  final List<IncomeEntry> income;
  final List<EconomyPoint> economy;
  final List<List<OdometerReading>> readingsPerVehicle;

  /// The same data with everything outside [range] removed.
  ///
  /// Filtering here rather than in each card is what keeps the period honest:
  /// a card that forgot to filter would quietly report the whole log under a
  /// heading that says "this month".
  StatsData within(DateRange range) {
    return StatsData(
      fuel: [
        for (final entry in fuel)
          if (range.contains(entry.date)) entry,
      ],
      services: [
        for (final entry in services)
          if (range.contains(entry.date)) entry,
      ],
      costs: [
        for (final entry in costs)
          if (range.contains(entry.date)) entry,
      ],
      readings: [
        for (final entry in readings)
          if (range.contains(entry.date)) entry,
      ],
      trips: [
        for (final entry in trips)
          if (range.contains(entry.date)) entry,
      ],
      income: [
        for (final entry in income)
          if (range.contains(entry.date)) entry,
      ],
      economy: [
        for (final point in economy)
          if (range.contains(point.date)) point,
      ],
      readingsPerVehicle: [
        for (final list in readingsPerVehicle)
          [
            for (final reading in list)
              if (range.contains(reading.date)) reading,
          ],
      ],
    );
  }

  bool get isEmpty =>
      fuel.isEmpty &&
      services.isEmpty &&
      costs.isEmpty &&
      readings.isEmpty &&
      trips.isEmpty &&
      income.isEmpty;

  /// The first and last day anything was logged, or null on an empty garage.
  ///
  /// What "all time" actually means. Without it a per-day rate over the
  /// unbounded range divides by three centuries.
  (DateTime, DateTime)? get span {
    DateTime? first;
    DateTime? last;
    void see(DateTime date) {
      if (first == null || date.isBefore(first!)) {
        first = date;
      }
      if (last == null || date.isAfter(last!)) {
        last = date;
      }
    }

    for (final entry in fuel) {
      see(entry.date);
    }
    for (final entry in services) {
      see(entry.date);
    }
    for (final entry in costs) {
      see(entry.date);
    }
    for (final entry in readings) {
      see(entry.date);
    }
    for (final entry in trips) {
      see(entry.date);
    }
    for (final entry in income) {
      see(entry.date);
    }
    return first == null ? null : (first!, last!);
  }

  /// Everything the period holds, however it was recorded. Shown beside the
  /// period so an empty screen explains itself.
  int get entryCount =>
      fuel.length +
      services.length +
      costs.length +
      readings.length +
      trips.length +
      income.length;
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
  final readings = <OdometerEntry>[];
  final trips = <TripEntry>[];
  final income = <IncomeEntry>[];
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
        final vehicleReadings = await ref.watch(
          odometerEntriesProvider(vehicle.id).future,
        );
        final vehicleTrips = await ref.watch(
          tripEntriesProvider(vehicle.id).future,
        );
        final vehicleIncome = await ref.watch(
          incomeEntriesProvider(vehicle.id).future,
        );
        final vehicleEconomy = await ref.watch(
          economyPointsProvider(vehicle.id).future,
        );

        fuel.addAll(vehicleFuel);
        services.addAll(vehicleServices);
        costs.addAll(vehicleCosts);
        readings.addAll(vehicleReadings);
        trips.addAll(vehicleTrips);
        income.addAll(vehicleIncome);
        economy.addAll(vehicleEconomy);
        readingsPerVehicle.add([
          for (final entry in vehicleFuel)
            OdometerReading(
              date: entry.date,
              km: entry.odometerKm,
              source: OdometerSource.fuel,
            ),
          for (final entry in vehicleServices)
            OdometerReading(
              date: entry.date,
              km: entry.odometerKm,
              source: OdometerSource.service,
            ),
          for (final entry in vehicleCosts)
            if (entry.odometerKm != null)
              OdometerReading(
                date: entry.date,
                km: entry.odometerKm!,
                source: OdometerSource.cost,
              ),
          for (final entry in vehicleReadings)
            OdometerReading(
              date: entry.date,
              km: entry.odometerKm,
              source: OdometerSource.reading,
            ),
          for (final entry in vehicleTrips)
            if (entry.endOdometerKm != null)
              OdometerReading(
                date: entry.date,
                km: entry.endOdometerKm!,
                source: OdometerSource.trip,
              ),
          for (final entry in vehicleIncome)
            if (entry.odometerKm != null)
              OdometerReading(
                date: entry.date,
                km: entry.odometerKm!,
                source: OdometerSource.income,
              ),
        ]);
      }),
  ]);

  return StatsData(
    fuel: fuel,
    services: services,
    costs: costs,
    readings: readings,
    trips: trips,
    income: income,
    economy: economy,
    readingsPerVehicle: readingsPerVehicle,
  );
});
