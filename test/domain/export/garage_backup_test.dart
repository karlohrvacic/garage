import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/stations/fuel_price_context.dart';
import 'package:garage/domain/entities/income_entry.dart';
import 'package:garage/domain/entities/odometer_entry.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/domain/entities/tyre_set.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/domain/export/garage_backup.dart';
import 'package:garage/domain/maintenance/recurring_costs.dart';

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
      priceContext: FuelPriceContext(
        station: 'Petrol Ilica',
        pricePerUnit: 1.44,
        distanceKm: 3.2,
        seenOn: DateTime.utc(2026, 3, 1),
      ),
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

/// Every optional field set, on the two entry kinds whose serializers had
/// stopped keeping up with their entities.
///
/// The fixture above is deliberately sparse, which is exactly why the gap
/// survived: a backup that drops a field nobody populated round-trips
/// perfectly. Anything added to [ServiceEntry] or [CostEntry] from here on
/// belongs in this fixture, and the tests below will say so if it does not
/// also reach the serializer.
VehicleBackup fullyPopulated() => VehicleBackup(
  vehicle: vehicle(),
  fuel: const [],
  services: [
    ServiceEntry(
      id: 's1',
      vehicleId: 'v1',
      date: DateTime.utc(2026, 3, 5),
      odometerKm: 51100,
      serviceTypeKeys: const ['service_oil_change', 'service_brake_pads'],
      cost: 210,
      shop: 'Auto Hrvačić',
      notes: 'ramp booked for 9am',
      createdBy: 'u1',
      diy: true,
      partsCost: 120.5,
      laborCost: 89.5,
      partsDetail: 'Castrol 5W-30, filter W712/95',
      warrantyUntil: DateTime.utc(2028, 3, 5),
      measurements: const {
        'brake_pad_front_mm': 7.5,
        'tread_front_left_mm': 6.2,
        'battery_volts': 12.6,
      },
      faultCodes: 'P0401, P0299',
    ),
  ],
  costs: [
    CostEntry(
      id: 'c1',
      vehicleId: 'v1',
      date: DateTime.utc(2026, 4, 1),
      category: CostCategories.vignette,
      amount: 16,
      odometerKm: 51500,
      notes: 'Slovenia, week away',
      createdBy: 'u1',
      vignetteCountry: VignetteCountry.slovenia,
      vignetteValidity: VignetteValidity.days7,
    ),
  ],
  readings: const [],
  trips: const [],
  income: const [],
  tyres: [
    TyreSet(
      id: 't1',
      vehicleId: 'v1',
      name: 'Winter — studded',
      season: TyreSeason.winter,
      fitted: true,
      createdBy: 'u1',
      size: '205/55 R16',
      storageLocation: 'Cellar',
      fittedAt: DateTime.utc(2025, 11, 1),
      manufacturedOn: DateTime.utc(2019, 8, 19),
      readings: [
        TyreReading(
          id: 'r1',
          date: DateTime.utc(2026, 1, 10),
          odometerKm: 51000,
          frontLeftMm: 6.5,
          frontRightMm: 6.4,
          rearLeftMm: 7.0,
          rearRightMm: 6.9,
        ),
      ],
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

  // A backup that reports success and quietly returns less than it was given
  // is worse than one that fails: the household finds out when they go looking
  // for the readings, by which time the source is gone.
  group('a restore gives back everything it was given', () {
    VehicleBackup roundTrip() => GarageBackup.decode(
      GarageBackup.encode([fullyPopulated()], householdName: 'Hrvačić'),
    ).vehicles.single;

    test('a service visit keeps its deeper fields', () {
      final restored = roundTrip().services.single;
      final original = fullyPopulated().services.single;

      expect(restored.date, original.date);
      expect(restored.odometerKm, original.odometerKm);
      expect(restored.serviceTypeKeys, original.serviceTypeKeys);
      expect(restored.cost, original.cost);
      expect(restored.shop, original.shop);
      expect(restored.notes, original.notes);
      expect(restored.partsCost, original.partsCost);
      expect(restored.laborCost, original.laborCost);
      expect(restored.diy, original.diy);
      expect(restored.partsDetail, original.partsDetail);
      expect(restored.warrantyUntil, original.warrantyUntil);
      expect(restored.faultCodes, original.faultCodes);
    });

    // Called out on their own because they are the ones with cumulative value:
    // a single pad thickness says little, and the tyre-wear estimate needs two
    // readings before it says anything at all.
    test('and every measurement taken at it', () {
      expect(roundTrip().services.single.measurements, {
        'brake_pad_front_mm': 7.5,
        'tread_front_left_mm': 6.2,
        'battery_volts': 12.6,
      });
    });

    // Read off a sidewall once and gone for good if a restore dropped it:
    // nobody re-reads a DOT code on tyres already stacked in a cellar.
    test('a tyre set keeps when it was made', () {
      final restored = roundTrip().tyres.single;

      expect(restored.name, 'Winter — studded');
      expect(restored.season, TyreSeason.winter);
      expect(restored.size, '205/55 R16');
      expect(restored.storageLocation, 'Cellar');
      expect(restored.fittedAt, DateTime.utc(2025, 11, 1));
      expect(restored.manufacturedOn, DateTime.utc(2019, 8, 19));
      expect(restored.readings.single.frontLeftMm, 6.5);
    });

    test('a vignette keeps what it was actually for', () {
      final restored = roundTrip().costs.single;
      expect(restored.category, CostCategories.vignette);
      expect(restored.amount, 16);
      expect(restored.odometerKm, 51500);
      expect(restored.notes, 'Slovenia, week away');
      expect(restored.vignetteCountry, VignetteCountry.slovenia);
      expect(restored.vignetteValidity, VignetteValidity.days7);
    });

    // The ids and the author are dropped on purpose — a restore writes new
    // rows, in whichever household is doing the restoring.
    test('but not the ids, which name nothing here', () {
      final restored = roundTrip().services.single;
      expect(restored.id, isEmpty);
      expect(restored.createdBy, isEmpty);
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
