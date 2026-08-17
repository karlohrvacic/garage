import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/income_entry.dart';
import 'package:garage/domain/entities/odometer_entry.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/domain/export/garage_backup.dart';

Vehicle vehicle() => Vehicle(
  id: 'v1',
  householdId: 'h1',
  nickname: 'Golf',
  fuelTypeKey: 'fuel_diesel',
  secondaryFuelTypeKey: 'fuel_lpg',
  baselineOdometerKm: 50000,
  baselineDate: DateTime.utc(2026, 1, 1),
  make: 'VW',
  model: 'Golf',
  year: 2015,
  plate: 'ZG1234AB',
  tankCapacityL: 55,
);

VehicleBackup contents() => VehicleBackup(
  vehicle: vehicle(),
  fuel: [
    FuelEntry(
      id: 'f1',
      vehicleId: 'v1',
      date: DateTime.utc(2026, 3, 1),
      odometerKm: 51000,
      volumeL: 42.5,
      pricePerL: 1.54,
      total: 65.45,
      fullTank: true,
      missedFill: false,
      fuelTypeKey: 'fuel_diesel',
      station: 'INA',
      notes: 'motorway',
      createdBy: 'u1',
    ),
  ],
  services: [
    ServiceEntry(
      id: 's1',
      vehicleId: 'v1',
      date: DateTime.utc(2026, 3, 5),
      odometerKm: 51100,
      serviceTypeKeys: const ['service_oil_change', 'service_oil_filter'],
      cost: 210,
      shop: 'Auto Hrvačić',
      createdBy: 'u1',
    ),
  ],
  costs: [
    CostEntry(
      id: 'c1',
      vehicleId: 'v1',
      date: DateTime.utc(2026, 4, 1),
      category: CostCategories.insurance,
      amount: 300,
      createdBy: 'u1',
    ),
  ],
  readings: [
    OdometerEntry(
      id: 'o1',
      vehicleId: 'v1',
      date: DateTime.utc(2026, 4, 10),
      odometerKm: 52000,
      createdBy: 'u1',
    ),
  ],
  trips: [
    TripEntry(
      id: 't1',
      vehicleId: 'v1',
      date: DateTime.utc(2026, 4, 12),
      distanceKm: 188,
      purpose: TripPurpose.business,
      title: 'Split',
      fromPlace: 'Zagreb',
      toPlace: 'Split',
      minutes: 240,
      createdBy: 'u1',
    ),
  ],
  income: [
    IncomeEntry(
      id: 'i1',
      vehicleId: 'v1',
      date: DateTime.utc(2026, 4, 12),
      category: IncomeCategories.ride,
      amount: 25,
      createdBy: 'u1',
    ),
  ],
);

void main() {
  group('a backup that can be restored', () {
    test('round-trips every entry kind', () {
      final restored = GarageBackup.decode(
        GarageBackup.encode([contents()], householdName: 'Hrvačić'),
      );

      final only = restored.vehicles.single;
      expect(only.fuel.single.volumeL, 42.5);
      expect(only.services.single.serviceTypeKeys, hasLength(2));
      expect(only.costs.single.amount, 300);
      expect(only.readings.single.odometerKm, 52000);
      expect(only.trips.single.purpose, TripPurpose.business);
      expect(only.income.single.amount, 25);
    });

    test('round-trips the vehicle itself, not just its entries', () {
      final restored = GarageBackup.decode(
        GarageBackup.encode([contents()], householdName: 'Hrvačić'),
      );

      final car = restored.vehicles.single.vehicle;
      expect(car.nickname, 'Golf');
      expect(car.plate, 'ZG1234AB');
      expect(car.tankCapacityL, 55);
      expect(car.baselineOdometerKm, 50000);
      expect(car.secondaryFuelTypeKey, 'fuel_lpg');
    });

    test('keeps dates as the days they were, not as instants', () {
      // A backup taken in Zagreb and restored anywhere else has to land on the
      // same calendar day, which is what the whole log is ordered by.
      final restored = GarageBackup.decode(
        GarageBackup.encode([contents()], householdName: 'Hrvačić'),
      );

      expect(
        restored.vehicles.single.fuel.single.date,
        DateTime.utc(2026, 3, 1),
      );
      expect(restored.vehicles.single.fuel.single.date.isUtc, isTrue);
    });

    test('carries the name of the garage it came from', () {
      final restored = GarageBackup.decode(
        GarageBackup.encode(const [], householdName: 'Hrvačić'),
      );

      expect(restored.householdName, 'Hrvačić');
    });

    test('states its own format version', () {
      final restored = GarageBackup.decode(
        GarageBackup.encode(const [], householdName: 'x'),
      );

      expect(restored.version, GarageBackup.currentVersion);
    });
  });

  group('refusing a file that is not one of ours', () {
    test('rejects something that is not JSON at all', () {
      expect(
        () => GarageBackup.decode('not json'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('rejects JSON that is not a backup', () {
      expect(
        () => GarageBackup.decode('{"hello":"world"}'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('rejects a version this build cannot read', () {
      // Written by a build from the future; this one must refuse it rather
      // than reading the half it recognises.
      final future = GarageBackup.encode(
        const [],
        householdName: 'x',
      ).replaceFirst(RegExp(r'"version":\s*1'), '"version": 99');

      expect(
        () => GarageBackup.decode(future),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });
}
