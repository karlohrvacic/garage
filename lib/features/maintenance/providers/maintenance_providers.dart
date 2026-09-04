import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';

// The clock moved to core/ so the odometer providers could reach it without
// an import cycle; re-exported so every existing importer is unaffected.
export '../../../core/clock.dart' show todayProvider;

import '../../../domain/entities/reminder_rule.dart';
import '../../../domain/entities/tyre_set.dart';
import '../../../domain/fuel/odometer_history.dart';
import '../../../domain/maintenance/reminder_projection.dart';
import '../../../domain/maintenance/winter_tyre_period.dart';
import '../../household/providers/household_providers.dart';
import '../../odometer/providers/odometer_providers.dart';
import '../../tyres/providers/tyre_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../data/maintenance_repository.dart';
import 'service_entry_providers.dart';

export 'service_entry_providers.dart'
    show maintenanceRepositoryProvider, serviceEntriesProvider;

final serviceTypesProvider = FutureProvider<List<ServiceType>>((ref) async {
  return ref.watch(maintenanceRepositoryProvider).serviceTypes();
});

final reminderRulesProvider = FutureProvider.family<List<ReminderRule>, String>(
  (ref, vehicleId) async {
    return ref.watch(maintenanceRepositoryProvider).rulesForVehicle(vehicleId);
  },
);

/// The service types this vehicle should be offered: everything universal,
/// the statutory items of the household's country, and nothing that its fuel
/// makes meaningless.
///
/// Registration and inspection cycles are national. Offering another country's
/// is worse than offering none: it looks authoritative and is wrong. The same
/// goes for "Fuel filter" on an electric car, which would be prefilled with a
/// number and look like advice.
///
/// A vehicle the provider cannot resolve gets the full list; a shorter one
/// would hide things for no reason anyone could see.
final availableServiceTypesProvider =
    FutureProvider.family<List<ServiceType>, String>((ref, vehicleId) async {
      final types = await ref.watch(serviceTypesProvider.future);
      final household = await ref.watch(currentHouseholdProvider.future);
      final vehicle = await ref.watch(vehicleProvider(vehicleId).future);
      final country = (household?.countryCode ?? 'HR').toUpperCase();
      final hidden = {
        ..._hiddenForFuel(vehicle?.fuelTypeKey),
        if (vehicle != null)
          ..._hiddenForKind(vehicle.kind, vehicle.finalDrive),
      };

      return [
        for (final type in types)
          // Only a type that names a *different* country is hidden. A
          // statutory item with no country is a household's own addition,
          // and hiding someone's own service type would be worse than
          // showing it.
          if ((!type.isStatutory ||
                  type.countryCode == null ||
                  type.countryCode!.toUpperCase() == country) &&
              !hidden.contains(type.key))
            type,
      ];
    });

const _dieselOnly = {
  'service_glow_plugs',
  'service_fuel_filter',
  'service_dpf',
  'service_adblue',
};
const _combustionOnly = {
  'service_oil_change',
  'service_oil_filter',
  'service_timing_belt',
  'service_spark_plugs',
  'service_fuel_filter',
  'service_glow_plugs',
  'service_dpf',
  'service_adblue',
};

/// Types that are not a thing on this fuel. A hybrid is a petrol car with
/// extras, so it keeps the petrol set.
///
/// The petrol family is enumerated rather than left as the fallback: the
/// column is only regex-constrained, so a newer build can record a key this
/// one has no case for (`fuel_hvo`, say), and guessing it is petrol would
/// hide the diesel types from a car that may need them. Unknown hides nothing.
Set<String> _hiddenForFuel(String? fuelTypeKey) {
  return switch (fuelTypeKey) {
    'fuel_diesel' => const {'service_spark_plugs'},
    'fuel_electric' => _combustionOnly,
    'fuel_petrol' ||
    'fuel_petrol_midgrade' ||
    'fuel_petrol_premium' ||
    'fuel_lpg' ||
    'fuel_cng' ||
    'fuel_ethanol' ||
    'fuel_hybrid' => _dieselOnly,
    _ => const {},
  };
}

const _motorcycleOnly = {
  'service_chain_lube',
  'service_chain_sprockets',
  'service_fork_oil',
  'service_valve_clearance',
};
const _chainOnly = {'service_chain_lube', 'service_chain_sprockets'};
const _carOnly = {
  'service_cabin_filter',
  'service_wheel_alignment',
  'service_tire_rotation',
  'service_tire_swap_seasonal',
  'service_serpentine_belt',
  'service_ac_service',
  'service_wipers',
  'service_glow_plugs',
  'service_dpf',
  'service_adblue',
};

/// Types that are not a thing on this kind of vehicle. A van is a car with
/// a bigger box; a motorcycle has no cabin, no wheels to align in pairs, and
/// — with a belt or a shaft — no chain. Unknown hides nothing, for the same
/// reason as an unknown fuel.
Set<String> _hiddenForKind(String kind, String? finalDrive) {
  return switch (kind) {
    'car' || 'van' => _motorcycleOnly,
    'motorcycle' => switch (finalDrive) {
      'belt' || 'shaft' => {..._carOnly, ..._chainOnly},
      _ => _carOnly,
    },
    _ => const {},
  };
}

/// The daily distance every distance-based projection on this vehicle rests
/// on, or null when there is not enough odometer history to measure one.
///
/// Exposed rather than kept inside the projector because a projection built on
/// the assumed rate looked exactly like one built on measured history: a date
/// that was months out had nothing on screen to account for it.
final drivingRateProvider = FutureProvider.family<double?, String>((
  ref,
  vehicleId,
) async {
  final samples = await ref.watch(odometerSamplesProvider(vehicleId).future);
  return OdometerHistory.kmPerDay(samples);
});

/// The rate with the span of readings it came from, for the sentence that
/// explains a projection: "over 38 days of readings", not a window the
/// measurement never used.
final drivingRateMeasurementProvider =
    FutureProvider.family<({double kmPerDay, int days})?, String>((
      ref,
      vehicleId,
    ) async {
      final samples = await ref.watch(
        odometerSamplesProvider(vehicleId).future,
      );
      return OdometerHistory.rateMeasurement(samples);
    });

/// Resolves every active rule on a vehicle into a dated due point.
///
/// The driving rate comes from the vehicle's own odometer history, so a car
/// that sits all winter projects its distance-based items further out than one
/// doing a motorway commute — which is the whole reason the projection is
/// dated rather than quoted purely in kilometres.
final vehicleProjectionsProvider =
    FutureProvider.family<List<ReminderProjection>, String>((
      ref,
      vehicleId,
    ) async {
      final rules = await ref.watch(reminderRulesProvider(vehicleId).future);
      if (rules.isEmpty) {
        return const [];
      }

      final services = await ref.watch(
        serviceEntriesProvider(vehicleId).future,
      );
      final samples = await ref.watch(
        odometerSamplesProvider(vehicleId).future,
      );
      final vehicle = await ref.watch(vehicleProvider(vehicleId).future);
      final household = await ref.watch(currentHouseholdProvider.future);
      final today = ref.watch(todayProvider);

      // Where the car stands now, and how fast it is getting there, are read
      // from every source that records an odometer rather than from fill-ups
      // alone: an owner who logs services but pays cash at the pump used to
      // get the assumed rate for every projection.
      final currentOdometerKm = OdometerHistory.currentKm(
        baselineKm: vehicle?.baselineOdometerKm ?? 0,
        samples: samples,
      );
      // Null when unmeasured: the projector then goes by the calendar, and
      // assumes a rate only for a rule that has nothing else.
      final rate = OdometerHistory.kmPerDay(samples);

      final projections = <ReminderProjection>[];
      for (final rule in rules) {
        // A visit that covered several items anchors every one of them, which is
        // what makes a completed bundle reset all its members at once.
        final matching = services
            .where((s) => s.serviceTypeKeys.contains(rule.serviceTypeKey))
            .toList();
        final last = matching.isEmpty ? null : matching.first;

        final projection = ReminderProjector.project(
          rule: rule,
          lastServiceDate: last?.date,
          lastServiceOdometerKm: last?.odometerKm,
          currentOdometerKm: currentOdometerKm,
          kmPerDay: rate,
          today: today,
          baselineDate: last == null ? (vehicle?.baselineDate ?? today) : null,
          baselineOdometerKm: last == null
              ? (vehicle?.baselineOdometerKm ?? currentOdometerKm)
              : null,
        );
        if (projection != null) {
          projections.add(projection);
        }
      }

      // A car on all-season tyres has no seasonal swap to do, and the reminder
      // would return twice a year with nothing behind it. Suppressed only when
      // the household has actually recorded its tyres: an empty list means
      // "not tracked", never "all-season".
      //
      // The tyre sets are read only when there is such a rule to judge, so a
      // vehicle without one costs no extra query.
      final hasSeasonalSwap = projections.any(
        (projection) =>
            projection.serviceTypeKey == 'service_tire_swap_seasonal',
      );
      if (hasSeasonalSwap) {
        final tyres = await ref.watch(tyreSetsProvider(vehicleId).future);
        if (!TyreSeasons.swapsSeasonally(tyres)) {
          projections.removeWhere(
            (projection) =>
                projection.serviceTypeKey == 'service_tire_swap_seasonal',
          );
        }
      }

      // The swap ships as a six-month interval anchored on whenever the last
      // one was logged, so it drifts: a swap done in late June puts the next
      // one just before Christmas. Where the country has a verified statutory
      // window the date is not a matter of habit, so the projection is moved
      // onto it. A country the app has not checked keeps the interval —
      // inventing a date would look authoritative and be wrong.
      final country = (household?.countryCode ?? 'HR');
      for (var i = 0; i < projections.length; i++) {
        if (projections[i].serviceTypeKey != 'service_tire_swap_seasonal') {
          continue;
        }
        final swap = nextSeasonalSwap(countryCode: country, today: today);
        if (swap != null) {
          projections[i] = ReminderProjector.pinToSeasonalSwap(
            projection: projections[i],
            swap: swap,
            today: today,
          );
        }
      }

      return projections
        ..sort((a, b) => a.projectedDueDate.compareTo(b.projectedDueDate));
    });

/// Every vehicle's projections in one list — what the dashboard's
/// "due soonest across the fleet" view and the planner both read.
final householdProjectionsProvider = FutureProvider<List<ReminderProjection>>((
  ref,
) async {
  final vehicles = await ref.watch(vehiclesProvider.future);
  // Project each vehicle concurrently; wall-clock is the slowest single
  // vehicle rather than the sum across the fleet.
  final perVehicle = await Future.wait([
    for (final vehicle in vehicles)
      ref.watch(vehicleProjectionsProvider(vehicle.id).future),
  ]);
  return [for (final list in perVehicle) ...list]
    ..sort((a, b) => a.projectedDueDate.compareTo(b.projectedDueDate));
});
