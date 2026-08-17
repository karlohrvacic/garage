import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/reminder_rule.dart';
import '../../../domain/entities/tyre_set.dart';
import '../../../domain/fuel/odometer_history.dart';
import '../../../domain/maintenance/reminder_projection.dart';
import '../../household/providers/household_providers.dart';
import '../../odometer/providers/odometer_providers.dart';
import '../../tyres/providers/tyre_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../data/maintenance_repository.dart';
import 'service_entry_providers.dart';

export 'service_entry_providers.dart'
    show maintenanceRepositoryProvider, serviceEntriesProvider;

/// Today's date, injected so projections are deterministic under test.
///
/// Re-evaluates itself at the next local midnight: a session left open for
/// days (a pinned browser tab) would otherwise keep judging due/overdue
/// against the day the app was opened.
final todayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  final nextMidnight = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(nextMidnight.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return now;
});

final serviceTypesProvider = FutureProvider<List<ServiceType>>((ref) async {
  return ref.watch(maintenanceRepositoryProvider).serviceTypes();
});

final reminderRulesProvider = FutureProvider.family<List<ReminderRule>, String>(
  (ref, vehicleId) async {
    return ref.watch(maintenanceRepositoryProvider).rulesForVehicle(vehicleId);
  },
);

/// The service types this household should be offered: everything universal,
/// plus the statutory items of its own country.
///
/// Registration and inspection cycles are national. Offering another country's
/// is worse than offering none: it looks authoritative and is wrong.
final availableServiceTypesProvider = FutureProvider<List<ServiceType>>((
  ref,
) async {
  final types = await ref.watch(serviceTypesProvider.future);
  final household = await ref.watch(currentHouseholdProvider.future);
  final country = (household?.countryCode ?? 'HR').toUpperCase();

  return [
    for (final type in types)
      // Only a type that names a *different* country is hidden. A statutory
      // item with no country is a household's own addition, and hiding
      // someone's own service type would be worse than showing it.
      if (!type.isStatutory ||
          type.countryCode == null ||
          type.countryCode!.toUpperCase() == country)
        type,
  ];
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
      final today = ref.watch(todayProvider);

      // Where the car stands now, and how fast it is getting there, are read
      // from every source that records an odometer rather than from fill-ups
      // alone: an owner who logs services but pays cash at the pump used to
      // get the assumed rate for every projection.
      final currentOdometerKm = OdometerHistory.currentKm(
        baselineKm: vehicle?.baselineOdometerKm ?? 0,
        samples: samples,
      );
      final rate =
          OdometerHistory.kmPerDay(samples) ??
          ReminderProjector.fallbackKmPerDay;

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
