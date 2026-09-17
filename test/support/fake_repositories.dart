import 'dart:async';

import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/costs/data/cost_repository.dart';
import 'package:garage/features/fuel/data/fuel_repository.dart';
import 'package:garage/features/maintenance/data/maintenance_repository.dart';
import 'package:garage/domain/entities/vehicle_transfer.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/features/household/data/garage_bootstrap.dart';
import 'package:garage/features/vehicles/data/vehicle_repository.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/domain/entities/trip_route.dart';
import 'package:garage/features/trips/data/route_repository.dart';
import 'package:garage/features/household/data/garage_bootstrap_cache.dart';
import 'package:garage/domain/entities/odometer_entry.dart';
import 'package:garage/features/odometer/data/odometer_repository.dart';
import 'package:garage/domain/entities/tyre_set.dart';
import 'package:garage/features/tyres/data/tyre_repository.dart';
import 'package:garage/domain/entities/trip_draft.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/features/trips/data/trip_repository.dart';
import 'package:garage/domain/entities/income_entry.dart';
import 'package:garage/features/income/data/income_repository.dart';

/// In-memory stand-ins for the four repositories, for tests about a screen
/// that writes rather than about the writing itself.
class FakeVehicleRepository implements VehicleRepository {
  @override
  Future<List<VehicleTransfer>> transfersOffered(String householdId) async =>
      const [];

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> cancelTransfer(String vehicleId) async {}

  @override
  Future<String?> outstandingTransferCode(String vehicleId) async => null;

  FakeVehicleRepository({List<Vehicle> vehicles = const []})
    : vehicles = [...vehicles];

  List<Vehicle> vehicles;
  final List<Vehicle> created = [];

  /// What was written back, for a test that asserts on the edit rather than
  /// on a rendering of it.
  final List<Vehicle> updated = [];

  /// Set to hold [create] open, so a test can observe what the UI does while a
  /// write is still in flight. Complete it to let the write finish.
  Completer<void>? pause;

  @override
  Future<List<Vehicle>> forHousehold(String householdId) async => vehicles;

  @override
  Future<Vehicle> create(Vehicle vehicle) async {
    created.add(vehicle);
    if (pause case final gate?) {
      await gate.future;
    }
    // A real create returns the row the database assigned an id, and the
    // sample loader threads that id through everything it writes next.
    final saved = Vehicle(
      id: 'created-${created.length}',
      householdId: vehicle.householdId,
      nickname: vehicle.nickname,
      fuelTypeKey: vehicle.fuelTypeKey,
      baselineOdometerKm: vehicle.baselineOdometerKm,
      baselineDate: vehicle.baselineDate,
      make: vehicle.make,
      model: vehicle.model,
      year: vehicle.year,
      tankCapacityL: vehicle.tankCapacityL,
    );
    vehicles = [...vehicles, saved];
    return saved;
  }

  @override
  Future<void> update(Vehicle vehicle) async => updated.add(vehicle);

  @override
  Future<void> setArchived(String id, bool archived) async {}

  @override
  Future<void> deleteAllForHousehold(String householdId) async {
    vehicles = const [];
  }

  @override
  Future<String> offerTransfer(String vehicleId) async => 'TRANSFER';

  @override
  Future<String> redeemTransfer({
    required String code,
    required String householdId,
  }) async => 'v1';
}

class FakeFuelRepository implements FuelRepository {
  FakeFuelRepository({List<FuelEntry> entries = const []})
    : entries = [...entries];

  List<FuelEntry> entries;

  /// Ids this was asked to delete, for a test about what a deletion takes
  /// with it.
  final List<String> deleted = [];

  /// What was written back, for a test that asserts on an edit rather than
  /// on a rendering of it.
  final List<FuelEntry> updated = [];

  @override
  Future<List<FuelEntry>> forVehicle(String vehicleId) async => entries;

  @override
  Future<void> add(FuelEntry entry) async => entries = [...entries, entry];

  @override
  Future<void> update(FuelEntry entry) async => updated.add(entry);

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    entries = [
      for (final entry in entries)
        if (entry.id != id) entry,
    ];
  }
}

class FakeCostRepository implements CostRepository {
  FakeCostRepository({List<CostEntry> entries = const []})
    : entries = [...entries];

  List<CostEntry> entries;

  @override
  Future<List<CostEntry>> forVehicle(String vehicleId) async => entries;

  @override
  Future<void> add(CostEntry entry) async => entries = [...entries, entry];

  @override
  Future<void> update(CostEntry entry) async {}

  @override
  Future<void> delete(String id) async {}
}

class FakeMaintenanceRepository implements MaintenanceRepository {
  FakeMaintenanceRepository({
    List<ServiceEntry> services = const [],
    List<ReminderRule> rules = const [],
  }) : services = [...services],
       rules = [...rules];

  List<ServiceEntry> services;
  List<ReminderRule> rules;

  @override
  Future<List<ServiceType>> serviceTypes() async => const [];

  @override
  Future<List<ReminderRule>> rulesForVehicle(String vehicleId) async => rules;

  @override
  Future<List<ServiceEntry>> serviceEntriesForVehicle(String vehicleId) async =>
      services;

  @override
  Future<void> upsertRule(ReminderRule rule) async => rules = [...rules, rule];

  @override
  Future<void> deleteRule(String id) async {}

  @override
  Future<void> completeOneTimeRules(
    String vehicleId,
    List<String> serviceTypeKeys,
  ) async {}

  @override
  Future<void> addServiceEntry(ServiceEntry entry) async =>
      services = [...services, entry];

  @override
  Future<void> updateServiceEntry(ServiceEntry entry) async {}

  @override
  Future<void> deleteServiceEntry(String id) async {}
}

/// Startup's single fetch, standing in for the embedded select.
///
/// Every screen test needs one now: `allVehiclesProvider` is derived from
/// `garageBootstrapProvider`, so without this the vehicle list reaches for a
/// real Supabase client and the test dies on an uninitialised instance rather
/// than on anything it meant to assert.
class FakeGarageBootstrapRepository implements GarageBootstrapRepository {
  FakeGarageBootstrapRepository({
    this.households = const [Household(id: 'h1', name: 'Test')],
    this.vehicles = const [],
    this.borrowed = const [],
  });

  /// Reads the current list on every call rather than a snapshot taken at
  /// construction, so a test that adds a car and invalidates the bootstrap
  /// sees the car.
  List<Household> households;
  List<Vehicle> vehicles;

  /// Cars reachable through a guest pass — they belong to a garage the caller
  /// is not in, so they never appear under one.
  List<Vehicle> borrowed;
  int loads = 0;

  @override
  Future<GarageBootstrap> load() async {
    loads++;
    return GarageBootstrap(
      households: households,
      borrowedVehicles: borrowed,
      vehiclesByHousehold: {
        for (final household in households)
          household
              .id: [...vehicles.where((it) => it.householdId == household.id)]
            ..sort(
              (a, b) =>
                  a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()),
            ),
      },
    );
  }
}

/// Named journeys, in memory. [conflictsWith] simulates another phone winning
/// the race to name the same route: the insert is refused by the unique index
/// and the row it collided with is already there.
class FakeRouteRepository implements RouteRepository {
  FakeRouteRepository({List<TripRoute>? routes})
    : routes = routes ?? <TripRoute>[];

  final List<TripRoute> routes;
  final List<String> calls = [];
  TripRoute? conflictsWith;

  /// The write refused outright, for the case where naming a route fails and
  /// the drive must not be started regardless.
  bool failAdd = false;

  @override
  Future<List<TripRoute>> forHousehold(String householdId) async {
    calls.add('forHousehold');
    if (conflictsWith case final route?) {
      return [...routes, route];
    }
    return List.of(routes);
  }

  @override
  Future<TripRoute> add({
    required String householdId,
    required String name,
  }) async {
    calls.add('add:$name');
    if (failAdd) {
      throw const AppFailure(kind: AppFailureKind.network);
    }
    if (conflictsWith != null) {
      throw const AppFailure(kind: AppFailureKind.conflict);
    }
    final created = TripRoute(
      id: 'r${routes.length + 1}',
      householdId: householdId,
      name: name,
    );
    routes.add(created);
    return created;
  }

  @override
  Future<void> rename(String id, String name) async =>
      calls.add('rename:$id:$name');

  @override
  Future<void> delete(String id) async => calls.add('delete:$id');
}

/// A startup cache that answers from memory, so a test can say what was in it
/// without reaching for the device's preferences.
class FakeBootstrapCache implements GarageBootstrapCache {
  FakeBootstrapCache({this.cached});

  GarageBootstrap? cached;
  int cleared = 0;
  int writes = 0;

  @override
  Future<GarageBootstrap?> read(String userId) async => cached;

  @override
  Future<void> write(
    String userId, {
    required List<Map<String, dynamic>> households,
    required List<Map<String, dynamic>> vehicles,
  }) async {
    writes++;
  }

  @override
  Future<void> clear() async => cleared++;
}

/// Standalone odometer readings, in memory. Needed by any harness that drives
/// the maintenance projections for real: `odometerSamplesProvider` merges this
/// with fuel, services and costs, and the projections are what the dashboard's
/// reminder listeners hang off.
class FakeOdometerRepository implements OdometerRepository {
  FakeOdometerRepository({List<OdometerEntry> entries = const []})
    : entries = [...entries];

  List<OdometerEntry> entries;

  @override
  Future<List<OdometerEntry>> forVehicle(String vehicleId) async => [
    for (final entry in entries)
      if (entry.vehicleId == vehicleId) entry,
  ];

  @override
  Future<void> add(OdometerEntry entry) async => entries = [...entries, entry];

  @override
  Future<void> update(OdometerEntry entry) async {}

  @override
  Future<void> delete(String id) async {}
}

/// Tyre sets, in memory and empty by default. A harness that drives the
/// maintenance projections needs one: the seasonal-swap rule asks what the car
/// is shod with before deciding whether the reminder applies at all, so
/// without this the whole projection chain lands in an error state and the
/// dashboard's listeners never fire.
class FakeTyreRepository implements TyreRepository {
  FakeTyreRepository({List<TyreSet> sets = const []}) : sets = [...sets];

  List<TyreSet> sets;

  @override
  Future<List<TyreSet>> forVehicle(String vehicleId) async => sets;

  @override
  Future<void> addSet({
    required String vehicleId,
    required String name,
    required TyreSeason season,
    String? size,
    String? storageLocation,
    Map<TyreCorner, DateTime> manufacturedByCorner = const {},
  }) async {}

  @override
  Future<void> updateSet({
    required String setId,
    required String name,
    required TyreSeason season,
    String? size,
    String? storageLocation,
    Map<TyreCorner, DateTime> manufacturedByCorner = const {},
  }) async {}

  @override
  Future<void> fitSet({
    required String vehicleId,
    required String setId,
  }) async {}

  @override
  Future<void> unfitSet(String setId) async {}

  @override
  Future<void> retireSet(String setId) async {}

  @override
  Future<void> unretireSet(String setId) async {}

  @override
  Future<void> deleteSet(String setId) async {}

  @override
  Future<void> addReading({
    required String tyreSetId,
    required DateTime date,
    int? odometerKm,
    double? frontLeftMm,
    double? frontRightMm,
    double? rearLeftMm,
    double? rearRightMm,
  }) async {}
}

/// Trips, in memory. Reached by any harness that drives the odometer series:
/// it merges every source that records a reading, and a trip's end odometer is
/// one of them.
class FakeTripRepository implements TripRepository {
  FakeTripRepository({List<TripEntry> entries = const []})
    : entries = [...entries];

  List<TripEntry> entries;

  @override
  Future<List<TripEntry>> forVehicle(String vehicleId) async => [
    for (final entry in entries)
      if (entry.vehicleId == vehicleId) entry,
  ];

  @override
  Future<void> add(TripEntry entry) async => entries = [...entries, entry];

  @override
  Future<void> update(TripEntry entry) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<TripDraft?> openDraft(String vehicleId) async => null;

  @override
  Future<void> startDraft(TripDraft draft) async {}

  @override
  Future<void> discardDraft(String id) async {}
}

/// Money in, in memory. Another source the odometer series merges, and so
/// another repository a harness driving the real projections has to supply.
class FakeIncomeRepository implements IncomeRepository {
  FakeIncomeRepository({List<IncomeEntry> entries = const []})
    : entries = [...entries];

  List<IncomeEntry> entries;

  @override
  Future<List<IncomeEntry>> forVehicle(String vehicleId) async => [
    for (final entry in entries)
      if (entry.vehicleId == vehicleId) entry,
  ];

  @override
  Future<void> add(IncomeEntry entry) async => entries = [...entries, entry];

  @override
  Future<void> update(IncomeEntry entry) async {}

  @override
  Future<void> delete(String id) async {}
}
