import 'dart:async';

import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/costs/data/cost_repository.dart';
import 'package:garage/features/fuel/data/fuel_repository.dart';
import 'package:garage/features/maintenance/data/maintenance_repository.dart';
import 'package:garage/features/vehicles/data/vehicle_repository.dart';

/// In-memory stand-ins for the four repositories, for tests about a screen
/// that writes rather than about the writing itself.
class FakeVehicleRepository implements VehicleRepository {
  FakeVehicleRepository({List<Vehicle> vehicles = const []})
    : vehicles = [...vehicles];

  List<Vehicle> vehicles;
  final List<Vehicle> created = [];

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
  Future<void> update(Vehicle vehicle) async {}

  @override
  Future<void> setArchived(String id, bool archived) async {}

  @override
  Future<void> deleteAllForHousehold(String householdId) async {
    vehicles = const [];
  }
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
