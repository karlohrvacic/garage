import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/vehicles/data/supabase_vehicle_repository.dart';

Map<String, dynamic> row({Object? tankCapacity = 55}) {
  return {
    'id': 'v1',
    'household_id': 'h1',
    'nickname': 'Golf',
    'fuel_type_key': 'fuel_diesel',
    'baseline_odometer_km': 180000,
    'baseline_date': '2026-01-01',
    'make': 'VW',
    'model': 'Golf VII',
    'year': 2015,
    'trim': 'Highline',
    'vin': 'WVWZZZ1KZAW000001',
    'plate': 'ZG1234AB',
    'photo_path': null,
    'tank_capacity_l': tankCapacity,
    'archived': false,
  };
}

Vehicle vehicle({double? tankCapacityL = 55}) {
  return Vehicle(
    id: 'v1',
    householdId: 'h1',
    nickname: 'Golf',
    fuelTypeKey: 'fuel_diesel',
    baselineOdometerKm: 180000,
    baselineDate: DateTime.utc(2026, 1, 1),
    make: 'VW',
    model: 'Golf VII',
    year: 2015,
    trim: 'Highline',
    vin: 'WVWZZZ1KZAW000001',
    plate: 'ZG1234AB',
    tankCapacityL: tankCapacityL,
  );
}

void main() {
  group('reading a row', () {
    test('maps every column onto the entity', () {
      expect(vehicleFromRow(row()), vehicle());
    });

    test('reads the baseline date as UTC midnight', () {
      final date = vehicleFromRow(row()).baselineDate;

      expect(date.isUtc, isTrue);
      expect(date, DateTime.utc(2026, 1, 1));
    });

    test('reads an integer tank capacity as a double', () {
      expect(vehicleFromRow(row(tankCapacity: 60)).tankCapacityL, 60.0);
    });

    test('a vehicle with no capacity recorded reads as null', () {
      expect(vehicleFromRow(row(tankCapacity: null)).tankCapacityL, isNull);
    });

    test('the photo column is named photo_path, not photo_url', () {
      final read = vehicleFromRow({...row(), 'photo_path': 'garage/v1.png'});

      expect(read.photoUrl, 'garage/v1.png');
    });
  });

  group('writing a row', () {
    test('names the columns the table actually has', () {
      expect(vehicleToRow(vehicle()).keys, {
        'household_id',
        'nickname',
        'fuel_type_key',
        'baseline_odometer_km',
        'baseline_date',
        'make',
        'model',
        'year',
        'trim',
        'vin',
        'plate',
        'photo_path',
        'tank_capacity_l',
        'archived',
      });
    });

    test('writes the tank capacity in litres', () {
      expect(vehicleToRow(vehicle())['tank_capacity_l'], 55);
    });

    test('omits a capacity nobody entered rather than sending zero', () {
      expect(
        vehicleToRow(vehicle(tankCapacityL: null))['tank_capacity_l'],
        isNull,
      );
    });

    test('writes the baseline date as a date-only string', () {
      expect(vehicleToRow(vehicle())['baseline_date'], '2026-01-01');
    });
  });

  test('a row survives the round trip unchanged', () {
    final written = vehicleToRow(vehicle());
    final reread = vehicleFromRow({...written, 'id': 'v1'});

    expect(reread, vehicle());
  });
}
