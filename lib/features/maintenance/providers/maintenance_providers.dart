import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/reminder_rule.dart';
import '../../../domain/entities/service_entry.dart';
import '../../../domain/maintenance/reminder_projection.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../data/maintenance_repository.dart';
import '../data/supabase_maintenance_repository.dart';

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  return SupabaseMaintenanceRepository(ref.watch(supabaseClientProvider));
});

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

final reminderRulesProvider =
    FutureProvider.family<List<ReminderRule>, String>((ref, vehicleId) async {
  return ref.watch(maintenanceRepositoryProvider).rulesForVehicle(vehicleId);
});

final serviceEntriesProvider =
    FutureProvider.family<List<ServiceEntry>, String>((ref, vehicleId) async {
  final entries = await ref
      .watch(maintenanceRepositoryProvider)
      .serviceEntriesForVehicle(vehicleId);
  return [...entries]..sort((a, b) => b.date.compareTo(a.date));
});

/// Resolves every active rule on a vehicle into a dated due point.
///
/// The driving rate comes from the vehicle's own fuel history, so a car that
/// sits all winter projects its distance-based items further out than one
/// doing a motorway commute — which is the whole reason the projection is
/// dated rather than quoted purely in kilometres.
final vehicleProjectionsProvider =
    FutureProvider.family<List<ReminderProjection>, String>(
        (ref, vehicleId) async {
  final rules = await ref.watch(reminderRulesProvider(vehicleId).future);
  if (rules.isEmpty) {
    return const [];
  }

  final services = await ref.watch(serviceEntriesProvider(vehicleId).future);
  final fuelEntries = await ref.watch(rawFuelEntriesProvider(vehicleId).future);
  final vehicle = await ref.watch(vehicleProvider(vehicleId).future);
  final today = ref.watch(todayProvider);

  // Where the car stands now is the highest odometer we have seen from any
  // source: its baseline, its most recent fuel fill, or its most recent
  // service. Using fuel alone under-reads a car whose owner logs services but
  // pays cash for fuel — the projection would then think the car had driven
  // backwards since that service and push distance-based items far too late.
  var currentOdometerKm = vehicle?.baselineOdometerKm ?? 0;
  if (fuelEntries.isNotEmpty) {
    currentOdometerKm = currentOdometerKm > fuelEntries.last.odometerKm
        ? currentOdometerKm
        : fuelEntries.last.odometerKm;
  }
  for (final service in services) {
    if (service.odometerKm > currentOdometerKm) {
      currentOdometerKm = service.odometerKm;
    }
  }
  final rate = ReminderProjector.kmPerDay(
    odometerReadings: fuelEntries.map((e) => e.odometerKm).toList(),
    dates: fuelEntries.map((e) => e.date).toList(),
  );

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
      baselineOdometerKm:
          last == null ? (vehicle?.baselineOdometerKm ?? currentOdometerKm) : null,
    );
    if (projection != null) {
      projections.add(projection);
    }
  }

  return projections
    ..sort((a, b) => a.projectedDueDate.compareTo(b.projectedDueDate));
});

/// Every vehicle's projections in one list — what the dashboard's
/// "due soonest across the fleet" view and the planner both read.
final householdProjectionsProvider =
    FutureProvider<List<ReminderProjection>>((ref) async {
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
