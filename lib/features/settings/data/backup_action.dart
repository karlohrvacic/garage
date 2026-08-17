import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/reminder_rule.dart';
import '../../../domain/entities/vehicle.dart';
import '../../../domain/export/garage_backup.dart';
import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../income/providers/income_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../odometer/providers/odometer_providers.dart';
import '../../trips/providers/fleet_trip_providers.dart';
import '../../trips/providers/trip_providers.dart';
import '../../tyres/providers/tyre_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';

/// Reads the whole garage into a backup file.
///
/// Archived vehicles included: a car that has left the household is exactly
/// the history somebody would be upset to lose, and leaving it out of a file
/// called "everything" would be a lie.
Future<String> buildBackup({
  required WidgetRef ref,
  required String householdName,
}) async {
  final vehicles = await ref.read(allVehiclesProvider.future);
  final contents = <VehicleBackup>[];

  for (final vehicle in vehicles) {
    contents.add(
      VehicleBackup(
        vehicle: vehicle,
        fuel: await ref.read(fuelRepositoryProvider).forVehicle(vehicle.id),
        services: await ref
            .read(maintenanceRepositoryProvider)
            .serviceEntriesForVehicle(vehicle.id),
        costs: await ref.read(costRepositoryProvider).forVehicle(vehicle.id),
        readings: await ref
            .read(odometerRepositoryProvider)
            .forVehicle(vehicle.id),
        trips: await ref.read(tripRepositoryProvider).forVehicle(vehicle.id),
        income: await ref.read(incomeRepositoryProvider).forVehicle(vehicle.id),
        rules: await ref
            .read(maintenanceRepositoryProvider)
            .rulesForVehicle(vehicle.id),
        tyres: await ref.read(tyreRepositoryProvider).forVehicle(vehicle.id),
      ),
    );
  }

  return GarageBackup.encode(contents, householdName: householdName);
}

class RestoreResult {
  const RestoreResult({
    required this.vehiclesCreated,
    required this.vehiclesMatched,
    required this.entriesWritten,
    required this.entriesSkipped,
  });

  final int vehiclesCreated;
  final int vehiclesMatched;
  final int entriesWritten;
  final int entriesSkipped;
}

/// Writes a backup back into the current household.
///
/// **Additive, never destructive.** Nothing is deleted, and an entry already
/// present is left alone rather than written again. Restoring is the thing
/// people do when they are already worried about their data, and a restore
/// that could remove something would be the worst possible moment to be wrong.
///
/// A vehicle is matched by nickname rather than by id, because a backup
/// restored into a different household carries ids that mean nothing there.
/// Matching by name is what a person would do, and its failure mode — a second
/// car called "Golf" — is visible rather than silent.
Future<RestoreResult> restoreBackup({
  required WidgetRef ref,
  required String householdId,
  required RestoredBackup backup,
}) async {
  final vehicleRepository = ref.read(vehicleRepositoryProvider);
  final existingVehicles = await ref.read(allVehiclesProvider.future);
  final byName = {
    for (final vehicle in existingVehicles)
      vehicle.nickname.toLowerCase(): vehicle,
  };

  var created = 0;
  var matched = 0;
  var written = 0;
  var skipped = 0;

  for (final entry in backup.vehicles) {
    var vehicle = byName[entry.vehicle.nickname.toLowerCase()];
    if (vehicle == null) {
      vehicle = await vehicleRepository.create(
        Vehicle(
          id: '',
          householdId: householdId,
          nickname: entry.vehicle.nickname,
          fuelTypeKey: entry.vehicle.fuelTypeKey,
          secondaryFuelTypeKey: entry.vehicle.secondaryFuelTypeKey,
          baselineOdometerKm: entry.vehicle.baselineOdometerKm,
          baselineDate: entry.vehicle.baselineDate,
          make: entry.vehicle.make,
          model: entry.vehicle.model,
          year: entry.vehicle.year,
          trim: entry.vehicle.trim,
          vin: entry.vehicle.vin,
          plate: entry.vehicle.plate,
          tankCapacityL: entry.vehicle.tankCapacityL,
          archived: entry.vehicle.archived,
        ),
      );
      // Remembered, so a backup carrying two cars with the same nickname
      // creates one and matches the second against it rather than creating a
      // duplicate the restore itself made.
      byName[vehicle.nickname.toLowerCase()] = vehicle;
      created++;
    } else {
      matched++;
    }
    final vehicleId = vehicle.id;

    Future<void> write<T>({
      required List<T> incoming,
      required Set<String> existing,
      required String Function(T) key,
      required Future<void> Function(T) add,
    }) async {
      for (final item in incoming) {
        final natural = key(item);
        if (existing.contains(natural)) {
          skipped++;
          continue;
        }
        existing.add(natural);
        await add(item);
        written++;
      }
    }

    final fuel = ref.read(fuelRepositoryProvider);
    await write(
      incoming: entry.fuel,
      existing: {
        for (final e in await fuel.forVehicle(vehicleId))
          '${e.date}|${e.odometerKm}',
      },
      key: (e) => '${e.date}|${e.odometerKm}',
      add: (e) => fuel.add(e.copyWith(vehicleId: vehicleId)),
    );

    final maintenance = ref.read(maintenanceRepositoryProvider);
    await write(
      incoming: entry.services,
      existing: {
        for (final e in await maintenance.serviceEntriesForVehicle(vehicleId))
          '${e.date}|${e.odometerKm}',
      },
      key: (e) => '${e.date}|${e.odometerKm}',
      add: (e) => maintenance.addServiceEntry(e.copyWith(vehicleId: vehicleId)),
    );

    final costs = ref.read(costRepositoryProvider);
    await write(
      incoming: entry.costs,
      existing: {
        for (final e in await costs.forVehicle(vehicleId))
          '${e.date}|${e.category}|${e.amount}',
      },
      key: (e) => '${e.date}|${e.category}|${e.amount}',
      add: (e) => costs.add(e.copyWith(vehicleId: vehicleId)),
    );

    final readings = ref.read(odometerRepositoryProvider);
    await write(
      incoming: entry.readings,
      existing: {
        for (final e in await readings.forVehicle(vehicleId))
          '${e.date}|${e.odometerKm}',
      },
      key: (e) => '${e.date}|${e.odometerKm}',
      add: (e) => readings.add(e.copyWith(vehicleId: vehicleId)),
    );

    final trips = ref.read(tripRepositoryProvider);
    await write(
      incoming: entry.trips,
      existing: {
        for (final e in await trips.forVehicle(vehicleId))
          '${e.date}|${e.distanceKm}',
      },
      key: (e) => '${e.date}|${e.distanceKm}',
      add: (e) => trips.add(e.copyWith(vehicleId: vehicleId)),
    );

    final income = ref.read(incomeRepositoryProvider);
    await write(
      incoming: entry.income,
      existing: {
        for (final e in await income.forVehicle(vehicleId))
          '${e.date}|${e.category}|${e.amount}',
      },
      key: (e) => '${e.date}|${e.category}|${e.amount}',
      add: (e) => income.add(e.copyWith(vehicleId: vehicleId)),
    );

    // A rule is identified by what it reminds about, not by its id: one
    // recurring rule per service type is what the schema allows, and a
    // household that has since changed an interval keeps its own choice.
    await write(
      incoming: entry.rules,
      existing: {
        for (final e in await maintenance.rulesForVehicle(vehicleId))
          _ruleKey(e),
      },
      key: _ruleKey,
      add: (e) => maintenance.upsertRule(e.copyWith(vehicleId: vehicleId)),
    );

    // Tyres restore in two steps because a set is created before it has an
    // id: add what is missing, read back what the ids turned out to be, then
    // fill in the readings and put the fitted set back on the car.
    final tyres = ref.read(tyreRepositoryProvider);
    final existingSets = await tyres.forVehicle(vehicleId);
    final setsByName = {
      for (final set in existingSets) set.name.toLowerCase(): set,
    };
    for (final set in entry.tyres) {
      if (setsByName.containsKey(set.name.toLowerCase())) {
        skipped++;
        continue;
      }
      await tyres.addSet(
        vehicleId: vehicleId,
        name: set.name,
        season: set.season,
        size: set.size,
        storageLocation: set.storageLocation,
      );
      written++;
    }

    final storedSets = {
      for (final set in await tyres.forVehicle(vehicleId))
        set.name.toLowerCase(): set,
    };
    for (final set in entry.tyres) {
      final stored = storedSets[set.name.toLowerCase()];
      if (stored == null) {
        continue;
      }
      final seen = {for (final reading in stored.readings) reading.date};
      for (final reading in set.readings) {
        if (!seen.add(reading.date)) {
          skipped++;
          continue;
        }
        await tyres.addReading(
          tyreSetId: stored.id,
          date: reading.date,
          odometerKm: reading.odometerKm,
          frontLeftMm: reading.frontLeftMm,
          frontRightMm: reading.frontRightMm,
          rearLeftMm: reading.rearLeftMm,
          rearRightMm: reading.rearRightMm,
        );
        written++;
      }
      // Only a set the restore created is put back on the car or retired: a
      // household that has swapped tyres since the backup was taken knows
      // better than the file does.
      if (existingSets.any(
        (e) => e.name.toLowerCase() == set.name.toLowerCase(),
      )) {
        continue;
      }
      if (set.retiredAt != null) {
        await tyres.retireSet(stored.id);
      } else if (set.fitted) {
        await tyres.fitSet(vehicleId: vehicleId, setId: stored.id);
      }
    }

    ref
      ..invalidate(tyreSetsProvider(vehicleId))
      ..invalidate(rawFuelEntriesProvider(vehicleId))
      ..invalidate(reminderRulesProvider(vehicleId))
      ..invalidate(serviceEntriesProvider(vehicleId))
      ..invalidate(costEntriesProvider(vehicleId))
      ..invalidate(odometerEntriesProvider(vehicleId))
      ..invalidate(tripEntriesProvider(vehicleId))
      ..invalidate(incomeEntriesProvider(vehicleId));
  }

  ref
    ..invalidate(allVehiclesProvider)
    ..invalidate(allTripsProvider);

  return RestoreResult(
    vehiclesCreated: created,
    vehiclesMatched: matched,
    entriesWritten: written,
    entriesSkipped: skipped,
  );
}

/// What makes two reminders the same reminder. A recurring rule is unique per
/// service type; one-off items are not, so those carry what they are due at.
String _ruleKey(ReminderRule rule) => rule.oneTime
    ? 'one|${rule.serviceTypeKey}|${rule.dueDate}|${rule.dueOdometerKm}'
    : 'every|${rule.serviceTypeKey}';
