import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/domain/maintenance/interval_defaults.dart';

Vehicle car({
  String? make,
  String fuel = 'fuel_petrol',
  String? timingDrive,
  String? transmission,
}) {
  return Vehicle(
    id: 'v1',
    householdId: 'h1',
    nickname: 'Car',
    fuelTypeKey: fuel,
    baselineOdometerKm: 0,
    baselineDate: DateTime.utc(2026, 1, 1),
    make: make,
    timingDrive: timingDrive,
    transmission: transmission,
  );
}

IntervalDefault resolve(String key, Vehicle vehicle) {
  return IntervalDefaults.resolve(
    serviceTypeKey: key,
    presetKm: 11111,
    presetMonths: 11,
    vehicle: vehicle,
  );
}

void main() {
  group('the generic path', () {
    test('an unknown make gets the preset and no note', () {
      final d = resolve('service_oil_change', car(make: 'Geely'));

      expect(d.km, 11111);
      expect(d.months, 11);
      expect(d.source, IntervalSource.generic);
      expect(d.note, isNull);
    });

    test('a type nobody overlays gets the preset whatever the make', () {
      final d = resolve('service_wipers', car(make: 'Škoda'));

      expect(d.source, IntervalSource.generic);
      expect(d.km, 11111);
    });
  });

  group('the make overlay', () {
    test('Mazda oil is 20,000 km / 12 months', () {
      final d = resolve('service_oil_change', car(make: 'Mazda'));

      expect(d.km, 20000);
      expect(d.months, 12);
      expect(d.source, IntervalSource.make);
    });

    test('the oil filter takes the oil-change row', () {
      final d = resolve('service_oil_filter', car(make: 'Mercedes'));

      expect(d.km, 25000);
      expect(d.source, IntervalSource.make);
    });

    test('a half the make does not give keeps the preset half', () {
      // Opel coolant: months from the overlay, km from the preset.
      final d = resolve('service_coolant', car(make: 'Opel'));

      expect(d.months, 60);
      expect(d.km, 11111);
      expect(d.source, IntervalSource.make);
    });

    test('a condition-based make is left generic on purpose', () {
      final d = resolve('service_oil_change', car(make: 'BMW'));

      expect(d.source, IntervalSource.generic);
    });

    test('the oil-filter alias does not invent an oil row', () {
      final d = resolve('service_oil_filter', car(make: 'BMW'));

      expect(d.source, IntervalSource.generic);
      expect(d.km, 11111);
    });
  });

  group('the drivetrain', () {
    test('a chain needs no timing-belt interval and says so', () {
      final d = resolve('service_timing_belt', car(timingDrive: 'chain'));

      expect(d.km, isNull);
      expect(d.months, isNull);
      expect(d.source, IntervalSource.drivetrain);
      expect(d.note, IntervalNote.chain);
    });

    test('a belt in oil is 100,000 km / 72 months', () {
      final d = resolve('service_timing_belt', car(timingDrive: 'wet_belt'));

      expect(d.km, 100000);
      expect(d.months, 72);
      expect(d.note, IntervalNote.wetBelt);
    });

    test('a dry belt keeps the preset', () {
      final d = resolve('service_timing_belt', car(timingDrive: 'belt'));

      expect(d.km, 11111);
      expect(d.source, IntervalSource.generic);
      expect(d.note, isNull);
    });

    test('an unset timing drive keeps the preset and asks for it', () {
      final d = resolve('service_timing_belt', car());

      expect(d.km, 11111);
      expect(d.source, IntervalSource.generic);
      expect(d.note, IntervalNote.setTimingDrive);
    });

    test('the water pump rides with the belt', () {
      final d = resolve('service_water_pump', car(timingDrive: 'chain'));

      expect(d.note, IntervalNote.chain);
    });

    test('the drivetrain wins over the make', () {
      final d = resolve(
        'service_timing_belt',
        car(make: 'Škoda', timingDrive: 'wet_belt'),
      );

      expect(d.km, 100000);
      expect(d.source, IntervalSource.drivetrain);
    });

    test('a dry dual-clutch gearbox is sealed', () {
      final d = resolve(
        'service_transmission_oil',
        car(transmission: 'dct_dry'),
      );

      expect(d.km, isNull);
      expect(d.months, isNull);
      expect(d.note, IntervalNote.sealed);
    });

    test('a wet dual-clutch is 60,000 km / 48 months', () {
      final d = resolve(
        'service_transmission_oil',
        car(transmission: 'dct_wet'),
      );

      expect(d.km, 60000);
      expect(d.months, 48);
      expect(d.note, isNull);
    });

    test('a CVT is 60,000 km / 48 months, advisory', () {
      final d = resolve('service_transmission_oil', car(transmission: 'cvt'));

      expect(d.km, 60000);
      expect(d.months, 48);
      expect(d.source, IntervalSource.drivetrain);
      expect(d.note, IntervalNote.advisory);
    });

    test('an automatic is advisory', () {
      final d = resolve(
        'service_transmission_oil',
        car(transmission: 'automatic'),
      );

      expect(d.km, 60000);
      expect(d.note, IntervalNote.advisory);
    });

    test('a manual is 90,000 km / 72 months, advisory', () {
      final d = resolve(
        'service_transmission_oil',
        car(transmission: 'manual'),
      );

      expect(d.km, 90000);
      expect(d.months, 72);
      expect(d.note, IntervalNote.advisory);
    });

    test('an unset gearbox keeps the preset and asks for it', () {
      final d = resolve('service_transmission_oil', car());

      expect(d.km, 11111);
      expect(d.note, IntervalNote.setTransmission);
    });
  });

  group('the fuel', () {
    test('a diesel fuel filter is 40,000 km / 48 months', () {
      final d = resolve('service_fuel_filter', car(fuel: 'fuel_diesel'));

      expect(d.km, 40000);
      expect(d.months, 48);
      expect(d.source, IntervalSource.fuel);
      expect(d.note, isNull);
    });

    test('a petrol fuel filter is 90,000 km, advisory, no months', () {
      for (final fuel in [
        'fuel_petrol',
        'fuel_petrol_midgrade',
        'fuel_petrol_premium',
        'fuel_lpg',
        'fuel_cng',
        'fuel_ethanol',
        'fuel_hybrid',
      ]) {
        final d = resolve('service_fuel_filter', car(fuel: fuel));

        expect(d.km, 90000, reason: fuel);
        expect(d.months, isNull, reason: fuel);
        expect(d.note, IntervalNote.advisory, reason: fuel);
      }
    });

    test('an electric car gets nothing for a fuel filter', () {
      final d = resolve('service_fuel_filter', car(fuel: 'fuel_electric'));

      expect(d.km, isNull);
      expect(d.months, isNull);
      expect(d.source, IntervalSource.fuel);
    });
  });
}
