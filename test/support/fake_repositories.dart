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

  @override
  Future<List<FuelEntry>> forVehicle(String vehicleId) async => entries;

  @override
  Future<void> add(FuelEntry entry) async => entries = [...entries, entry];

  @override
  Future<void> update(FuelEntry entry) async {}

  @override
  Future<void> delete(String id) async {}
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
