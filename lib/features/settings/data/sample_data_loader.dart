import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/demo/sample_garage.dart';
import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../income/providers/income_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../odometer/providers/odometer_providers.dart';
import '../../trips/providers/trip_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';

/// Writes the sample garage into a real household.
///
/// Every kind, not the three it started with: a demo that leaves the trip log,
/// the balance and the odometer chart as empty states is demonstrating an app
/// that is smaller than the one being shipped.
///
/// Deliberately ordinary data rather than a separate demo mode: it goes
/// through the same repositories as anything typed by hand, so what a new
/// arrival explores is the actual app, and Settings' delete-all removes it
/// like any other car.
Future<void> loadSampleData({
  required WidgetRef ref,
  required String householdId,
  DateTime? today,
}) async {
  final when = today ?? DateTime.now().toUtc();

  // Built twice rather than copied: the sample is deterministic, so the second
  // build is the same garage with the real vehicle id threaded through. Not
  // every entity carries a copyWith, and adding one for a demo would be the
  // tail wagging the dog.
  final draft = SampleGarage.build(today: when, householdId: householdId);
  final vehicle = await ref
      .read(vehicleRepositoryProvider)
      .create(draft.vehicle);

  final sample = SampleGarage.build(
    today: when,
    householdId: householdId,
    vehicleId: vehicle.id,
  );

  final fuelRepository = ref.read(fuelRepositoryProvider);
  for (final entry in sample.fuel) {
    await fuelRepository.add(entry);
  }

  final maintenance = ref.read(maintenanceRepositoryProvider);
  for (final entry in sample.services) {
    await maintenance.addServiceEntry(entry);
  }
  for (final rule in sample.rules) {
    await maintenance.upsertRule(rule);
  }

  final costRepository = ref.read(costRepositoryProvider);
  for (final entry in sample.costs) {
    await costRepository.add(entry);
  }

  final odometerRepository = ref.read(odometerRepositoryProvider);
  for (final entry in sample.readings) {
    await odometerRepository.add(entry);
  }

  final tripRepository = ref.read(tripRepositoryProvider);
  for (final entry in sample.trips) {
    await tripRepository.add(entry);
  }

  final incomeRepository = ref.read(incomeRepositoryProvider);
  for (final entry in sample.income) {
    await incomeRepository.add(entry);
  }

  ref
    ..invalidate(allVehiclesProvider)
    ..invalidate(vehiclesProvider);
}
