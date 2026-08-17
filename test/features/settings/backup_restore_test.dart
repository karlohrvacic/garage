import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/income_entry.dart';
import 'package:garage/domain/entities/odometer_entry.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/domain/entities/tyre_set.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/domain/export/garage_backup.dart';
import 'package:garage/features/costs/data/cost_repository.dart';
import 'package:garage/features/costs/providers/cost_providers.dart';
import 'package:garage/features/fuel/data/fuel_repository.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/income/data/income_repository.dart';
import 'package:garage/features/income/providers/income_providers.dart';
import 'package:garage/features/maintenance/data/maintenance_repository.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/odometer/data/odometer_repository.dart';
import 'package:garage/features/odometer/providers/odometer_providers.dart';
import 'package:garage/features/settings/data/backup_action.dart';
import 'package:garage/features/trips/data/trip_repository.dart';
import 'package:garage/features/trips/providers/trip_providers.dart';
import 'package:garage/features/tyres/data/tyre_repository.dart';
import 'package:garage/features/tyres/providers/tyre_providers.dart';
import 'package:garage/features/vehicles/data/vehicle_repository.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:riverpod/misc.dart' show Override;

class FakeVehicles implements VehicleRepository {
  FakeVehicles(this.vehicles);

  List<Vehicle> vehicles;
  var _next = 0;

  @override
  Future<List<Vehicle>> forHousehold(String householdId) async => vehicles;

  @override
  Future<Vehicle> create(Vehicle vehicle) async {
    // The real repository returns the row the server wrote, id and all.
    final created = Vehicle(
      id: 'new${_next++}',
      householdId: vehicle.householdId,
      nickname: vehicle.nickname,
      fuelTypeKey: vehicle.fuelTypeKey,
      secondaryFuelTypeKey: vehicle.secondaryFuelTypeKey,
      baselineOdometerKm: vehicle.baselineOdometerKm,
      baselineDate: vehicle.baselineDate,
      make: vehicle.make,
      model: vehicle.model,
      year: vehicle.year,
      plate: vehicle.plate,
      tankCapacityL: vehicle.tankCapacityL,
      archived: vehicle.archived,
    );
    vehicles = [...vehicles, created];
    return created;
  }

  @override
  Future<void> update(Vehicle vehicle) async {}

  @override
  Future<void> setArchived(String id, bool archived) async {}

  @override
  Future<void> deleteAllForHousehold(String householdId) async {}

  @override
  Future<String> offerTransfer(String vehicleId) async => 'X';

  @override
  Future<String> redeemTransfer({
    required String code,
    required String householdId,
  }) async => 'v1';
}

class FakeFuel implements FuelRepository {
  FakeFuel([this.entries = const []]);
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

class FakeCosts implements CostRepository {
  List<CostEntry> entries = [];

  @override
  Future<List<CostEntry>> forVehicle(String vehicleId) async => entries;

  @override
  Future<void> add(CostEntry entry) async => entries = [...entries, entry];

  @override
  Future<void> update(CostEntry entry) async {}

  @override
  Future<void> delete(String id) async {}
}

class FakeOdometer implements OdometerRepository {
  List<OdometerEntry> entries = [];

  @override
  Future<List<OdometerEntry>> forVehicle(String vehicleId) async => entries;

  @override
  Future<void> add(OdometerEntry entry) async => entries = [...entries, entry];

  @override
  Future<void> update(OdometerEntry entry) async {}

  @override
  Future<void> delete(String id) async {}
}

class FakeTrips implements TripRepository {
  List<TripEntry> entries = [];

  @override
  Future<List<TripEntry>> forVehicle(String vehicleId) async => entries;

  @override
  Future<void> add(TripEntry entry) async => entries = [...entries, entry];

  @override
  Future<void> update(TripEntry entry) async {}

  @override
  Future<void> delete(String id) async {}
}

class FakeIncome implements IncomeRepository {
  List<IncomeEntry> entries = [];

  @override
  Future<List<IncomeEntry>> forVehicle(String vehicleId) async => entries;

  @override
  Future<void> add(IncomeEntry entry) async => entries = [...entries, entry];

  @override
  Future<void> update(IncomeEntry entry) async {}

  @override
  Future<void> delete(String id) async {}
}

class FakeMaintenance implements MaintenanceRepository {
  FakeMaintenance({this.rules = const []});

  List<ServiceEntry> entries = [];
  List<ReminderRule> rules;

  @override
  Future<List<ServiceType>> serviceTypes() async => const [];

  @override
  Future<List<ReminderRule>> rulesForVehicle(String vehicleId) async => rules;

  @override
  Future<List<ServiceEntry>> serviceEntriesForVehicle(String vehicleId) async =>
      entries;

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
      entries = [...entries, entry];

  @override
  Future<void> updateServiceEntry(ServiceEntry entry) async {}

  @override
  Future<void> deleteServiceEntry(String id) async {}
}

/// Keeps enough of the real repository's behaviour for a restore to be
/// testable: a set gets an id it did not have, and fitting one takes the
/// other off.
class FakeTyres implements TyreRepository {
  FakeTyres({List<TyreSet> sets = const []}) : sets = [...sets];

  List<TyreSet> sets;
  var _next = 0;

  @override
  Future<List<TyreSet>> forVehicle(String vehicleId) async => sets;

  @override
  Future<void> addSet({
    required String vehicleId,
    required String name,
    required TyreSeason season,
    String? size,
    String? storageLocation,
  }) async {
    sets = [
      ...sets,
      TyreSet(
        id: 'set${_next++}',
        vehicleId: vehicleId,
        name: name,
        season: season,
        fitted: false,
        createdBy: 'u1',
        size: size,
        storageLocation: storageLocation,
      ),
    ];
  }

  @override
  Future<void> fitSet({
    required String vehicleId,
    required String setId,
  }) async {
    sets = [for (final set in sets) _copy(set, fitted: set.id == setId)];
  }

  @override
  Future<void> retireSet(String setId) async {
    sets = [
      for (final set in sets)
        if (set.id == setId)
          _copy(set, fitted: false, retiredAt: DateTime.utc(2026, 6, 1))
        else
          set,
    ];
  }

  @override
  Future<void> deleteSet(String setId) async {
    sets = [
      for (final set in sets)
        if (set.id != setId) set,
    ];
  }

  @override
  Future<void> addReading({
    required String tyreSetId,
    required DateTime date,
    int? odometerKm,
    double? frontLeftMm,
    double? frontRightMm,
    double? rearLeftMm,
    double? rearRightMm,
  }) async {
    sets = [
      for (final set in sets)
        if (set.id == tyreSetId)
          _copy(
            set,
            readings: [
              ...set.readings,
              TyreReading(
                id: 'r${_next++}',
                date: date,
                odometerKm: odometerKm,
                frontLeftMm: frontLeftMm,
                frontRightMm: frontRightMm,
                rearLeftMm: rearLeftMm,
                rearRightMm: rearRightMm,
              ),
            ],
          )
        else
          set,
    ];
  }

  TyreSet _copy(
    TyreSet set, {
    bool? fitted,
    DateTime? retiredAt,
    List<TyreReading>? readings,
  }) {
    return TyreSet(
      id: set.id,
      vehicleId: set.vehicleId,
      name: set.name,
      season: set.season,
      fitted: fitted ?? set.fitted,
      createdBy: set.createdBy,
      size: set.size,
      storageLocation: set.storageLocation,
      fittedAt: set.fittedAt,
      retiredAt: retiredAt ?? set.retiredAt,
      readings: readings ?? set.readings,
    );
  }
}

/// [restoreBackup] takes a `WidgetRef`, so the test drives it through a widget
/// rather than a bare container. A one-widget harness is cheaper than making
/// the production code take something it does not naturally have.
Future<void> withRef(
  WidgetTester tester,
  List<Override> overrides,
  Future<void> Function(WidgetRef ref) run,
) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: Consumer(
        builder: (context, ref, _) {
          captured = ref;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await run(captured);
  await tester.pump();
}

Vehicle golf({String id = 'v1'}) => Vehicle(
  id: id,
  householdId: 'h1',
  nickname: 'Golf',
  fuelTypeKey: 'fuel_diesel',
  baselineOdometerKm: 50000,
  baselineDate: DateTime.utc(2026, 1, 1),
);

FuelEntry fill() => FuelEntry(
  id: 'f1',
  vehicleId: 'v1',
  date: DateTime.utc(2026, 3, 1),
  odometerKm: 51000,
  volumeL: 42.5,
  fullTank: true,
  missedFill: false,
  createdBy: 'u1',
);

void main() {
  late FakeVehicles vehicles;
  late FakeFuel fuel;
  late FakeCosts costs;
  late FakeOdometer readings;
  late FakeTrips trips;
  late FakeIncome income;
  late FakeMaintenance maintenance;
  late FakeTyres tyres;

  List<Override> overrides() => [
    vehicleRepositoryProvider.overrideWithValue(vehicles),
    fuelRepositoryProvider.overrideWithValue(fuel),
    costRepositoryProvider.overrideWithValue(costs),
    odometerRepositoryProvider.overrideWithValue(readings),
    tripRepositoryProvider.overrideWithValue(trips),
    incomeRepositoryProvider.overrideWithValue(income),
    maintenanceRepositoryProvider.overrideWithValue(maintenance),
    tyreRepositoryProvider.overrideWithValue(tyres),
    allVehiclesProvider.overrideWith((ref) async => vehicles.vehicles),
  ];

  setUp(() {
    vehicles = FakeVehicles([golf()]);
    fuel = FakeFuel([fill()]);
    costs = FakeCosts();
    readings = FakeOdometer();
    trips = FakeTrips();
    income = FakeIncome();
    maintenance = FakeMaintenance();
    tyres = FakeTyres();
  });

  testWidgets('a backup carries the whole garage', (tester) async {
    String? json;
    await withRef(tester, overrides(), (ref) async {
      json = await buildBackup(ref: ref, householdName: 'Hrvačić');
    });

    final restored = GarageBackup.decode(json!);
    expect(restored.householdName, 'Hrvačić');
    expect(restored.vehicles.single.vehicle.nickname, 'Golf');
    expect(restored.vehicles.single.fuel.single.volumeL, 42.5);
  });

  testWidgets('restoring into an empty garage recreates the cars', (
    tester,
  ) async {
    final json = GarageBackup.encode([
      VehicleBackup(vehicle: golf(), fuel: [fill()]),
    ], householdName: 'Hrvačić');

    vehicles = FakeVehicles(const []);
    fuel = FakeFuel(const []);

    late RestoreResult result;
    await withRef(tester, overrides(), (ref) async {
      result = await restoreBackup(
        ref: ref,
        householdId: 'h2',
        backup: GarageBackup.decode(json),
      );
    });

    expect(result.vehiclesCreated, 1);
    expect(result.entriesWritten, 1);
    expect(vehicles.vehicles.single.nickname, 'Golf');
    expect(fuel.entries.single.volumeL, 42.5);
  });

  testWidgets('restoring what is already there changes nothing', (
    tester,
  ) async {
    // The whole point of the additive rule: restoring is what people do when
    // they are already worried about their data.
    final json = GarageBackup.encode([
      VehicleBackup(vehicle: golf(), fuel: [fill()]),
    ], householdName: 'Hrvačić');

    late RestoreResult result;
    await withRef(tester, overrides(), (ref) async {
      result = await restoreBackup(
        ref: ref,
        householdId: 'h1',
        backup: GarageBackup.decode(json),
      );
    });

    expect(result.vehiclesCreated, 0);
    expect(result.vehiclesMatched, 1);
    expect(result.entriesWritten, 0);
    expect(result.entriesSkipped, 1);
    expect(fuel.entries, hasLength(1));
  });

  testWidgets('a car is matched by name, not by the id it used to have', (
    tester,
  ) async {
    // A backup restored into a different household carries ids that mean
    // nothing there.
    final json = GarageBackup.encode([
      VehicleBackup(vehicle: golf(id: 'from-another-household')),
    ], householdName: 'Hrvačić');

    late RestoreResult result;
    await withRef(tester, overrides(), (ref) async {
      result = await restoreBackup(
        ref: ref,
        householdId: 'h1',
        backup: GarageBackup.decode(json),
      );
    });

    expect(result.vehiclesCreated, 0);
    expect(result.vehiclesMatched, 1);
  });

  testWidgets('a backup carries the reminders that make it useful', (
    tester,
  ) async {
    // Losing these on a restore is silent: the log comes back, the
    // notifications never do, and nothing says so.
    maintenance = FakeMaintenance(
      rules: [
        ReminderRule(
          id: 'r1',
          vehicleId: 'v1',
          serviceTypeKey: 'service_oil_change',
          intervalKm: 15000,
          intervalMonths: 12,
        ),
      ],
    );

    String? json;
    await withRef(tester, overrides(), (ref) async {
      json = await buildBackup(ref: ref, householdName: 'Hrvačić');
    });

    final rules = GarageBackup.decode(json!).vehicles.single.rules;
    expect(rules.single.serviceTypeKey, 'service_oil_change');
    expect(rules.single.intervalKm, 15000);
    expect(rules.single.intervalMonths, 12);
  });

  testWidgets('restoring puts the reminders back on the new car', (
    tester,
  ) async {
    final json = GarageBackup.encode([
      VehicleBackup(
        vehicle: golf(),
        rules: [
          ReminderRule(
            id: 'from-another-household',
            vehicleId: 'v1',
            serviceTypeKey: 'service_oil_change',
            intervalKm: 15000,
          ),
        ],
      ),
    ], householdName: 'Hrvačić');

    vehicles = FakeVehicles(const []);
    fuel = FakeFuel(const []);

    await withRef(tester, overrides(), (ref) async {
      await restoreBackup(
        ref: ref,
        householdId: 'h2',
        backup: GarageBackup.decode(json),
      );
    });

    final written = maintenance.rules.single;
    expect(written.serviceTypeKey, 'service_oil_change');
    expect(written.vehicleId, vehicles.vehicles.single.id);
    expect(
      written.id,
      isEmpty,
      reason:
          'an id from another household updates nothing and inserts nothing',
    );
  });

  testWidgets('a reminder already set up is left alone', (tester) async {
    maintenance = FakeMaintenance(
      rules: [
        ReminderRule(
          id: 'r1',
          vehicleId: 'v1',
          serviceTypeKey: 'service_oil_change',
          intervalKm: 10000,
        ),
      ],
    );
    final json = GarageBackup.encode([
      VehicleBackup(
        vehicle: golf(),
        rules: [
          ReminderRule(
            id: 'r1',
            vehicleId: 'v1',
            serviceTypeKey: 'service_oil_change',
            intervalKm: 15000,
          ),
        ],
      ),
    ], householdName: 'Hrvačić');

    await withRef(tester, overrides(), (ref) async {
      await restoreBackup(
        ref: ref,
        householdId: 'h1',
        backup: GarageBackup.decode(json),
      );
    });

    expect(
      maintenance.rules.single.intervalKm,
      10000,
      reason: 'a restore never overwrites what the household has since chosen',
    );
  });

  testWidgets('a backup written before reminders were carried still reads', (
    tester,
  ) async {
    final json = GarageBackup.encode([
      VehicleBackup(vehicle: golf()),
    ], householdName: 'Hrvačić');
    final withoutRules = json.replaceAll('"rules": [],', '');

    expect(GarageBackup.decode(withoutRules).vehicles.single.rules, isEmpty);
  });

  testWidgets('a backup carries tyre sets and their tread history', (
    tester,
  ) async {
    tyres = FakeTyres(
      sets: [
        TyreSet(
          id: 't1',
          vehicleId: 'v1',
          name: 'Winters',
          season: TyreSeason.winter,
          fitted: true,
          createdBy: 'u1',
          size: '205/55 R16',
          storageLocation: 'Garage shelf',
          readings: [
            TyreReading(
              id: 'r1',
              date: DateTime.utc(2026, 3, 1),
              frontLeftMm: 6.5,
              odometerKm: 50000,
            ),
          ],
        ),
      ],
    );

    String? json;
    await withRef(tester, overrides(), (ref) async {
      json = await buildBackup(ref: ref, householdName: 'Hrvačić');
    });

    final set = GarageBackup.decode(json!).vehicles.single.tyres.single;
    expect(set.name, 'Winters');
    expect(set.season, TyreSeason.winter);
    expect(set.fitted, isTrue);
    expect(set.size, '205/55 R16');
    expect(set.readings.single.frontLeftMm, 6.5);
  });

  testWidgets('restoring brings the tyres back, fitted as they were', (
    tester,
  ) async {
    final json = GarageBackup.encode([
      VehicleBackup(
        vehicle: golf(),
        tyres: [
          TyreSet(
            id: 't1',
            vehicleId: 'v1',
            name: 'Winters',
            season: TyreSeason.winter,
            fitted: true,
            createdBy: 'u1',
            readings: [
              TyreReading(
                id: 'r1',
                date: DateTime.utc(2026, 3, 1),
                frontLeftMm: 6.5,
              ),
            ],
          ),
        ],
      ),
    ], householdName: 'Hrvačić');

    vehicles = FakeVehicles(const []);
    fuel = FakeFuel(const []);

    await withRef(tester, overrides(), (ref) async {
      await restoreBackup(
        ref: ref,
        householdId: 'h2',
        backup: GarageBackup.decode(json),
      );
    });

    final set = tyres.sets.single;
    expect(set.name, 'Winters');
    expect(set.vehicleId, vehicles.vehicles.single.id);
    expect(set.readings.single.frontLeftMm, 6.5);
    expect(
      set.fitted,
      isTrue,
      reason: 'the set that was on the car goes back on',
    );
  });

  testWidgets('a tyre set already there gains only the readings it lacks', (
    tester,
  ) async {
    tyres = FakeTyres(
      sets: [
        TyreSet(
          id: 't1',
          vehicleId: 'v1',
          name: 'Winters',
          season: TyreSeason.winter,
          fitted: false,
          createdBy: 'u1',
          readings: [
            TyreReading(
              id: 'r1',
              date: DateTime.utc(2026, 3, 1),
              frontLeftMm: 6.5,
            ),
          ],
        ),
      ],
    );
    final json = GarageBackup.encode([
      VehicleBackup(
        vehicle: golf(),
        tyres: [
          TyreSet(
            id: 't1',
            vehicleId: 'v1',
            name: 'Winters',
            season: TyreSeason.winter,
            fitted: false,
            createdBy: 'u1',
            readings: [
              TyreReading(
                id: 'r1',
                date: DateTime.utc(2026, 3, 1),
                frontLeftMm: 6.5,
              ),
              TyreReading(
                id: 'r2',
                date: DateTime.utc(2026, 9, 1),
                frontLeftMm: 5.5,
              ),
            ],
          ),
        ],
      ),
    ], householdName: 'Hrvačić');

    await withRef(tester, overrides(), (ref) async {
      await restoreBackup(
        ref: ref,
        householdId: 'h1',
        backup: GarageBackup.decode(json),
      );
    });

    expect(tyres.sets, hasLength(1), reason: 'no second set called Winters');
    expect(tyres.sets.single.readings, hasLength(2));
  });

  testWidgets('two cars with one name do not both get created', (tester) async {
    // A restore that creates a duplicate it made itself is worse than one that
    // merges two cars: the first is a bug, the second is the documented rule.
    final json = GarageBackup.encode([
      VehicleBackup(vehicle: golf(id: 'a')),
      VehicleBackup(vehicle: golf(id: 'b')),
    ], householdName: 'Hrvačić');

    vehicles = FakeVehicles(const []);
    fuel = FakeFuel(const []);

    late RestoreResult result;
    await withRef(tester, overrides(), (ref) async {
      result = await restoreBackup(
        ref: ref,
        householdId: 'h1',
        backup: GarageBackup.decode(json),
      );
    });

    expect(result.vehiclesCreated, 1);
    expect(result.vehiclesMatched, 1);
    expect(vehicles.vehicles, hasLength(1));
  });
}
