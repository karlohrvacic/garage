import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/sync/read_cache_providers.dart';
import '../../../domain/company/assignment_resolution.dart';
import '../../../domain/company/money_entry.dart';
import '../../../domain/company/reimbursements.dart';
import '../../../domain/entities/vehicle_assignment.dart';
import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../household/providers/household_providers.dart';
import '../../household/providers/member_providers.dart';
import '../../maintenance/providers/service_entry_providers.dart';
import '../../odometer/providers/odometer_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../data/company_repository.dart';
import '../data/supabase_company_repository.dart';

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return SupabaseCompanyRepository(
    ref.watch(supabaseClientProvider),
    cache: ref.watch(readCacheProvider),
  );
});

/// Whether the garage on screen has the company plan, lapsed or not.
///
/// What the company surfaces key on: a lapsed garage keeps every screen and
/// every row (decision 155), and its log still names who had which car.
final companyPlanProvider = Provider<bool>((ref) {
  return ref.watch(currentHouseholdProvider).value?.isOnCompanyPlan ?? false;
});

/// Whether the plan is current, which is what gates adding a car above the
/// cap, making a driver and assigning. The database decides too; this is
/// what lets the console say why before a tap is refused.
final companyEnabledProvider = Provider<bool>((ref) {
  final household = ref.watch(currentHouseholdProvider).value;
  if (household == null) {
    return false;
  }
  return household.companyEnabledAt(ref.watch(clockProvider)());
});

/// Whether the garage may take one more car. The insert policy decides the
/// same with `can_add_vehicle` (0080) and refuses with a bare permission
/// error, so the vehicles screen asks here first and says which sentence
/// applies: the free cap, or the plan that ended. True while the list is
/// still loading: the database is the boundary, and a form offered to a
/// full garage is refused there, not lost.
final canAddVehicleProvider = Provider<bool>((ref) {
  final household = ref.watch(currentHouseholdProvider).value;
  final active = ref.watch(vehiclesProvider).value;
  if (household == null || active == null) {
    return true;
  }
  return household.canAddVehicleAt(
    ref.watch(clockProvider)(),
    activeVehicles: active.length,
  );
});

/// The signed-in user's role in the garage on screen, from the startup
/// fetch, so it is known before the first frame and off the cache.
final myRoleProvider = Provider<String>((ref) {
  final household = ref.watch(currentHouseholdProvider).value;
  final bootstrap = ref.watch(garageBootstrapProvider).value;
  return bootstrap?.roleIn(household?.id) ?? 'member';
});

final isDriverProvider = Provider<bool>((ref) {
  return ref.watch(myRoleProvider) == 'driver';
});

/// The signed-in user's role in the garage a car belongs to, which is not
/// always the garage on screen: a car opened by URL, or from a push, can be
/// another garage's. The car page asks this, so a driver whose private
/// garage is the current one is not handed the owner's menu on the
/// company's van. `member` for a car the startup fetch does not list, as
/// [myRoleProvider] answers for a garage it does not.
final roleForVehicleProvider = Provider.family<String, String>((
  ref,
  vehicleId,
) {
  final bootstrap = ref.watch(garageBootstrapProvider).value;
  if (bootstrap == null) {
    return 'member';
  }
  for (final household in bootstrap.households) {
    for (final vehicle in bootstrap.vehiclesFor(household.id)) {
      if (vehicle.id == vehicleId) {
        return bootstrap.roleIn(vehicle.householdId);
      }
    }
  }
  return 'member';
});

final isDriverForVehicleProvider = Provider.family<bool, String>((
  ref,
  vehicleId,
) {
  return ref.watch(roleForVehicleProvider(vehicleId)) == 'driver';
});

/// The Company destination: an admin's, in a garage that has the plan. A
/// driver never sees it, and a member has nothing to do there.
final companyConsoleVisibleProvider = Provider<bool>((ref) {
  return ref.watch(companyPlanProvider) && ref.watch(myRoleProvider) == 'admin';
});

/// Every window on the garage's cars, newest first. Empty, and no request,
/// off the plan: a private garage must notice nothing.
final fleetAssignmentsProvider = FutureProvider<List<VehicleAssignment>>((
  ref,
) async {
  if (!ref.watch(companyPlanProvider)) {
    return const [];
  }
  final vehicles = await ref.watch(allVehiclesProvider.future);
  if (vehicles.isEmpty) {
    return const [];
  }
  return ref.watch(companyRepositoryProvider).assignmentsForVehicles([
    for (final vehicle in vehicles) vehicle.id,
  ]);
});

/// A driver's own windows. Only a driver asks: the policy shows a member
/// the whole log, which [fleetAssignmentsProvider] already holds.
final myAssignmentsProvider = FutureProvider<List<VehicleAssignment>>((
  ref,
) async {
  if (!ref.watch(isDriverProvider)) {
    return const [];
  }
  return ref.watch(companyRepositoryProvider).mine();
});

/// The handovers a driver has not signed off: open today, unconfirmed.
final pendingHandoversProvider = FutureProvider<List<VehicleAssignment>>((
  ref,
) async {
  final mine = await ref.watch(myAssignmentsProvider.future);
  final today = ref.watch(todayProvider);
  return [
    for (final assignment in mine)
      if (assignment.covers(today) && !assignment.isConfirmed) assignment,
  ];
});

/// Who had a car on a day, by user id. Null off the plan, on a day with no
/// window, and while the log is still loading.
final driverOnProvider =
    Provider.family<String?, ({String vehicleId, DateTime date})>((ref, key) {
      final assignments = ref.watch(fleetAssignmentsProvider).value;
      if (assignments == null) {
        return null;
      }
      return AssignmentResolution.driverOn(
        assignments,
        vehicleId: key.vehicleId,
        on: key.date,
      );
    });

/// The same, by display name. The member list is read only once there is a
/// driver to name, so a private garage's sheets never ask for it.
final driverNameOnProvider =
    Provider.family<String?, ({String vehicleId, DateTime date})>((ref, key) {
      final userId = ref.watch(driverOnProvider(key));
      if (userId == null) {
        return null;
      }
      return ref.watch(memberNamesProvider).value?[userId] ?? '';
    });

final companyControllerProvider =
    AsyncNotifierProvider<CompanyController, void>(CompanyController.new);

class CompanyController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns whether the write landed, so a sheet can hold itself open on
  /// failure instead of closing over an error nobody read.
  Future<bool> handOver({
    required String vehicleId,
    required DateTime on,
    int? odometerKm,
    String? toUserId,
    String? note,
  }) {
    return _run(() async {
      await ref
          .read(companyRepositoryProvider)
          .handOver(
            vehicleId: vehicleId,
            on: on,
            odometerKm: odometerKm,
            toUserId: toUserId,
            note: note,
          );
      // The handover wrote a reading, and it changed which cars a driver's
      // startup fetch returns: the bootstrap is the one to refresh, never
      // the providers derived from it.
      ref
        ..invalidate(fleetAssignmentsProvider)
        ..invalidate(odometerEntriesProvider(vehicleId))
        ..invalidate(garageBootstrapProvider);
    });
  }

  /// The driver's sign-off. The row names its car, so the id is enough.
  Future<bool> confirm(String assignmentId) {
    return _run(() async {
      await ref.read(companyRepositoryProvider).confirm(assignmentId);
      ref
        ..invalidate(myAssignmentsProvider)
        ..invalidate(fleetAssignmentsProvider);
    });
  }

  Future<bool> removeAssignment(VehicleAssignment assignment) {
    return _run(() async {
      await ref.read(companyRepositoryProvider).deleteAssignment(assignment.id);
      ref
        ..invalidate(fleetAssignmentsProvider)
        ..invalidate(garageBootstrapProvider);
    });
  }

  /// Stamps every entry on the line paid back, one update per table, and
  /// refreshes the cars they were on.
  Future<bool> markReimbursed(ReimbursementLine line, {required DateTime at}) {
    return _run(() async {
      final repository = ref.read(companyRepositoryProvider);
      final byTable = <String, List<String>>{};
      for (final entry in line.entries) {
        byTable.putIfAbsent(entry.kind.table, () => []).add(entry.id);
      }
      try {
        for (final MapEntry(key: table, value: ids) in byTable.entries) {
          await repository.markReimbursed(table: table, ids: ids, at: at);
        }
      } finally {
        // On a refusal too: a table stamped before the one that was refused
        // stays stamped, and the line has to show what is still owed rather
        // than the full total until something else refreshes it.
        for (final vehicleId in {
          for (final entry in line.entries) entry.vehicleId,
        }) {
          ref
            ..invalidate(rawFuelEntriesProvider(vehicleId))
            ..invalidate(serviceEntriesProvider(vehicleId))
            ..invalidate(costEntriesProvider(vehicleId));
        }
      }
    });
  }

  /// A push to the driver's phones, through the daily reminder function.
  /// Asked again for the same entry, it pushes again: the row is the
  /// request, not the state, and a second nudge is what an admin who taps
  /// twice meant.
  Future<bool> remindDriver(MoneyEntry entry, {required String driverId}) {
    return _run(() async {
      await ref
          .read(companyRepositoryProvider)
          .requestReceiptReminder(
            vehicleId: entry.vehicleId,
            kind: entry.kind.key,
            entryId: entry.id,
            driverId: driverId,
          );
    });
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
      return false;
    }
  }
}
