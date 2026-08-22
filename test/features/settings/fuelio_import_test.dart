import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/import/fuelio_backup.dart';
import 'package:garage/features/costs/data/cost_repository.dart';
import 'package:garage/features/costs/providers/cost_providers.dart';
import 'package:garage/features/fuel/data/fuel_repository.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/maintenance/data/maintenance_repository.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/settings/data/fuelio_import.dart';

class FakeFuelRepository implements FuelRepository {
  FakeFuelRepository(this.entries);

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
  FakeCostRepository(this.entries);

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
  FakeMaintenanceRepository({this.services = const [], this.rules = const []});

  List<ServiceEntry> services;
  List<ReminderRule> rules;
  final List<ReminderRule> upserted = [];

  @override
  Future<List<ServiceType>> serviceTypes() async => const [];

  @override
  Future<List<ReminderRule>> rulesForVehicle(String vehicleId) async => rules;

  @override
  Future<List<ServiceEntry>> serviceEntriesForVehicle(String vehicleId) async =>
      services;

  @override
  Future<void> upsertRule(ReminderRule rule) async => upserted.add(rule);

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

FuelioBackup backup({
  List<FuelioFillUp> fillUps = const [],
  List<FuelioCost> costs = const [],
  List<FuelioService> services = const [],
  List<FuelioReminder> reminders = const [],
}) {
  return FuelioBackup(
    fillUps: fillUps,
    costs: costs,
    services: services,
    reminders: reminders,
  );
}

FuelioFillUp fill({
  DateTime? date,
  int odometerKm = 50000,
  double? total = 62,
  double? pricePerL,
}) {
  return FuelioFillUp(
    date: date ?? DateTime.utc(2026, 5, 1),
    odometerKm: odometerKm,
    volumeL: 40,
    fullTank: true,
    missedFill: false,
    total: total,
    pricePerL: pricePerL,
    station: 'INA',
  );
}

/// Runs the import with a real [WidgetRef], which is what it takes.
Future<FuelioImportResult> runImport(
  WidgetTester tester, {
  required FuelioBackup data,
  FakeFuelRepository? fuel,
  FakeCostRepository? costs,
  FakeMaintenanceRepository? maintenance,
  String? defaultStation,
}) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fuelRepositoryProvider.overrideWithValue(
          fuel ?? FakeFuelRepository([]),
        ),
        costRepositoryProvider.overrideWithValue(
          costs ?? FakeCostRepository([]),
        ),
        maintenanceRepositoryProvider.overrideWithValue(
          maintenance ?? FakeMaintenanceRepository(),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          captured = ref;
          return const SizedBox();
        },
      ),
    ),
  );

  return importFuelioBackup(
    ref: captured,
    vehicleId: 'v1',
    backup: data,
    defaultStation: defaultStation,
  );
}

void main() {
  testWidgets('an empty backup imports nothing', (tester) async {
    final result = await runImport(tester, data: backup());

    expect(result.fillUps, 0);
    expect(result.costs, 0);
    expect(result.services, 0);
    expect(result.reminders, 0);
    expect(result.skippedReminders, isEmpty);
  });

  testWidgets('fill-ups are written to the chosen vehicle', (tester) async {
    final fuel = FakeFuelRepository([]);

    final result = await runImport(
      tester,
      data: backup(fillUps: [fill(), fill(odometerKm: 50500)]),
      fuel: fuel,
    );

    expect(result.fillUps, 2);
    expect(fuel.entries.map((e) => e.vehicleId), ['v1', 'v1']);
    expect(fuel.entries.first.station, 'INA');
  });

  testWidgets('a missing unit price is derived from the total', (tester) async {
    final fuel = FakeFuelRepository([]);

    await runImport(
      tester,
      data: backup(fillUps: [fill(total: 62, pricePerL: null)]),
      fuel: fuel,
    );

    expect(fuel.entries.single.pricePerL, closeTo(1.55, 0.0001));
  });

  testWidgets('a fill-up already logged is not imported twice', (tester) async {
    final fuel = FakeFuelRepository([
      FuelEntry(
        id: 'existing',
        vehicleId: 'v1',
        date: DateTime.utc(2026, 5, 1),
        odometerKm: 50000,
        volumeL: 40,
        fullTank: true,
        missedFill: false,
        createdBy: 'u1',
      ),
    ]);

    final result = await runImport(
      tester,
      data: backup(fillUps: [fill(), fill(odometerKm: 51000)]),
      fuel: fuel,
    );

    expect(result.fillUps, 1);
    expect(fuel.entries, hasLength(2));
  });

  testWidgets('services and costs are imported and deduplicated', (
    tester,
  ) async {
    final maintenance = FakeMaintenanceRepository(
      services: [
        ServiceEntry(
          id: 'existing',
          vehicleId: 'v1',
          date: DateTime.utc(2026, 4, 2),
          odometerKm: 49000,
          serviceTypeKeys: const ['service_oil_change'],
          createdBy: 'u1',
        ),
      ],
    );
    final costs = FakeCostRepository([]);

    final result = await runImport(
      tester,
      data: backup(
        services: [
          FuelioService(
            date: DateTime.utc(2026, 4, 2),
            odometerKm: 49000,
            serviceTypeKey: 'service_oil_change',
          ),
          FuelioService(
            date: DateTime.utc(2026, 6, 2),
            odometerKm: 51000,
            serviceTypeKey: 'service_brake_fluid',
            cost: 90,
          ),
        ],
        costs: [
          FuelioCost(
            date: DateTime.utc(2026, 3, 1),
            category: CostCategories.insurance,
            amount: 320,
          ),
        ],
      ),
      maintenance: maintenance,
      costs: costs,
    );

    expect(result.services, 1);
    expect(result.costs, 1);
    expect(costs.entries.single.category, CostCategories.insurance);
  });

  testWidgets('a cost already logged is not imported twice', (tester) async {
    final costs = FakeCostRepository([
      CostEntry(
        id: 'existing',
        vehicleId: 'v1',
        date: DateTime.utc(2026, 3, 1),
        category: CostCategories.insurance,
        amount: 320,
        createdBy: 'u1',
      ),
    ]);

    final result = await runImport(
      tester,
      data: backup(
        costs: [
          FuelioCost(
            date: DateTime.utc(2026, 3, 1),
            category: CostCategories.insurance,
            amount: 320,
          ),
        ],
      ),
      costs: costs,
    );

    expect(result.costs, 0);
  });

  testWidgets('a recurring reminder becomes an interval rule', (tester) async {
    final maintenance = FakeMaintenanceRepository();

    final result = await runImport(
      tester,
      data: backup(
        reminders: [
          const FuelioReminder(
            title: 'Oil change',
            serviceTypeKey: 'service_oil_change',
            repeatKm: 15000,
            repeatMonths: 12,
          ),
        ],
      ),
      maintenance: maintenance,
    );

    expect(result.reminders, 1);
    expect(maintenance.upserted.single.oneTime, isFalse);
    expect(maintenance.upserted.single.intervalKm, 15000);
    expect(maintenance.upserted.single.intervalMonths, 12);
  });

  testWidgets('a dated reminder becomes a one-off rule', (tester) async {
    final maintenance = FakeMaintenanceRepository();

    await runImport(
      tester,
      data: backup(
        reminders: [
          FuelioReminder(
            title: 'Registration',
            serviceTypeKey: 'service_registration',
            dueDate: DateTime.utc(2026, 9, 30),
          ),
        ],
      ),
      maintenance: maintenance,
    );

    expect(maintenance.upserted.single.oneTime, isTrue);
    expect(maintenance.upserted.single.dueDate, DateTime.utc(2026, 9, 30));
  });

  testWidgets('a one-off already present is not duplicated', (tester) async {
    final maintenance = FakeMaintenanceRepository(
      rules: [
        ReminderRule(
          id: 'r1',
          vehicleId: 'v1',
          serviceTypeKey: 'service_registration',
          oneTime: true,
          dueDate: DateTime.utc(2026, 9, 30),
        ),
      ],
    );

    final result = await runImport(
      tester,
      data: backup(
        reminders: [
          FuelioReminder(
            title: 'Registration',
            serviceTypeKey: 'service_registration',
            dueDate: DateTime.utc(2026, 9, 30),
          ),
        ],
      ),
      maintenance: maintenance,
    );

    expect(result.reminders, 0);
    expect(maintenance.upserted, isEmpty);
  });

  testWidgets('an unmappable reminder is reported, never guessed', (
    tester,
  ) async {
    final maintenance = FakeMaintenanceRepository();

    final result = await runImport(
      tester,
      data: backup(
        reminders: [
          const FuelioReminder(title: 'Something odd', serviceTypeKey: null),
        ],
      ),
      maintenance: maintenance,
    );

    expect(result.reminders, 0);
    expect(result.skippedReminders, ['Something odd']);
    expect(maintenance.upserted, isEmpty);
  });

  // Fuelio's export leaves City and StationID empty, so an import lands every
  // fill-up with no station and the only fix was editing them one at a time.
  group('a station for a file that carries none', () {
    FuelioFillUp fill({String? station}) => FuelioFillUp(
      date: DateTime.utc(2026, 8, 12),
      odometerKm: 48029,
      volumeL: 37.7,
      fullTank: true,
      missedFill: false,
      station: station,
    );

    testWidgets('is written onto every imported fill-up', (tester) async {
      final fuel = FakeFuelRepository([]);
      await runImport(
        tester,
        data: backup(fillUps: [fill(), fill()]),
        fuel: fuel,
        defaultStation: 'INA Zagreb',
      );

      expect(fuel.entries, hasLength(2));
      expect(fuel.entries.every((e) => e.station == 'INA Zagreb'), isTrue);
    });

    testWidgets('never overwrites a station the file did name', (tester) async {
      // A default is a fallback, not a correction. Overwriting would throw
      // away the one fact the file actually carried.
      final fuel = FakeFuelRepository([]);
      await runImport(
        tester,
        data: backup(
          fillUps: [
            fill(station: 'Petrol'),
            fill(),
          ],
        ),
        fuel: fuel,
        defaultStation: 'INA Zagreb',
      );

      expect(fuel.entries.first.station, 'Petrol');
      expect(fuel.entries.last.station, 'INA Zagreb');
    });

    testWidgets('a blank answer leaves the station unset', (tester) async {
      final fuel = FakeFuelRepository([]);
      await runImport(
        tester,
        data: backup(fillUps: [fill()]),
        fuel: fuel,
        defaultStation: '   ',
      );

      expect(fuel.entries.single.station, isNull);
    });

    testWidgets('not asking leaves the import exactly as it was', (
      tester,
    ) async {
      final fuel = FakeFuelRepository([]);
      await runImport(
        tester,
        data: backup(fillUps: [fill()]),
        fuel: fuel,
      );

      expect(fuel.entries.single.station, isNull);
    });
  });
}
