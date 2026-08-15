import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/import/fuelio_backup.dart';

FuelioFillUp fill(DateTime date, int odometerKm) {
  return FuelioFillUp(
    date: date,
    odometerKm: odometerKm,
    volumeL: 40,
    fullTank: true,
    missedFill: false,
  );
}

void main() {
  const car = FuelioVehicle(
    name: 'Renault Clio',
    make: 'Renault',
    model: 'Clio',
    year: 2022,
    plate: 'ZG1234AB',
    vin: 'VF1234567890',
  );

  test('the car keeps the name and details it had in Fuelio', () {
    final vehicle = vehicleFromFuelio(
      car,
      householdId: 'h1',
      fuelTypeKey: 'fuel_diesel',
      fillUps: const [],
      now: DateTime.utc(2026, 8, 15),
    );

    expect(vehicle.nickname, 'Renault Clio');
    expect(vehicle.make, 'Renault');
    expect(vehicle.model, 'Clio');
    expect(vehicle.year, 2022);
    expect(vehicle.plate, 'ZG1234AB');
    expect(vehicle.vin, 'VF1234567890');
    expect(vehicle.householdId, 'h1');
    expect(vehicle.fuelTypeKey, 'fuel_diesel');
  });

  test('tracking starts at the oldest reading in the backup', () {
    final vehicle = vehicleFromFuelio(
      car,
      householdId: 'h1',
      fuelTypeKey: 'fuel_petrol',
      fillUps: [
        fill(DateTime.utc(2026, 7, 25), 46818),
        fill(DateTime.utc(2025, 3, 2), 21000),
        fill(DateTime.utc(2026, 1, 9), 33000),
      ],
      now: DateTime.utc(2026, 8, 15),
    );

    expect(
      vehicle.baselineOdometerKm,
      21000,
      reason: 'a later baseline would put imported history before the start',
    );
    expect(vehicle.baselineDate, DateTime.utc(2025, 3, 2));
  });

  test('a backup with no fill-ups starts from today at zero', () {
    final vehicle = vehicleFromFuelio(
      car,
      householdId: 'h1',
      fuelTypeKey: 'fuel_petrol',
      fillUps: const [],
      now: DateTime.utc(2026, 8, 15),
    );

    expect(vehicle.baselineOdometerKm, 0);
    expect(vehicle.baselineDate, DateTime.utc(2026, 8, 15));
  });

  test('the id is left for the database to assign', () {
    final vehicle = vehicleFromFuelio(
      car,
      householdId: 'h1',
      fuelTypeKey: 'fuel_petrol',
      fillUps: const [],
      now: DateTime.utc(2026, 8, 15),
    );

    expect(vehicle.id, isEmpty);
  });
}
