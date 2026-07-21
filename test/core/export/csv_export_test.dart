import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/export/csv_export.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/service_entry.dart';

void main() {
  test('the fuel export carries a header row', () {
    final csv = fuelEntriesToCsv(const [], vehicleName: 'Golf');

    expect(csv.split('\n').first, contains('odometer'));
  });

  test('a fuel entry exports its values', () {
    final csv = fuelEntriesToCsv(
      [
        FuelEntry(
          id: '1',
          vehicleId: 'v1',
          date: DateTime(2026, 7, 1),
          odometerKm: 50000,
          volumeL: 45.2,
          pricePerL: 1.6,
          total: 72.32,
          fullTank: true,
          missedFill: false,
          station: 'INA',
          createdBy: 'u1',
        ),
      ],
      vehicleName: 'Golf',
    );

    expect(csv, contains('2026-07-01'));
    expect(csv, contains('50000'));
    expect(csv, contains('45.2'));
    expect(csv, contains('INA'));
  });

  test('a field containing a comma is quoted, not split', () {
    final csv = fuelEntriesToCsv(
      [
        FuelEntry(
          id: '1',
          vehicleId: 'v1',
          date: DateTime(2026, 7, 1),
          odometerKm: 50000,
          volumeL: 45.2,
          fullTank: true,
          missedFill: false,
          notes: 'topped up, then washed',
          createdBy: 'u1',
        ),
      ],
      vehicleName: 'Golf',
    );

    expect(csv, contains('"topped up, then washed"'));
    expect(csv.trim().split('\n'), hasLength(2));
  });

  test('the service export joins multiple items into one cell', () {
    final csv = serviceEntriesToCsv(
      [
        ServiceEntry(
          id: '1',
          vehicleId: 'v1',
          date: DateTime(2026, 7, 1),
          odometerKm: 50000,
          serviceTypeKeys: const ['service_oil_change', 'service_oil_filter'],
          cost: 120,
          createdBy: 'u1',
        ),
      ],
      vehicleName: 'Golf',
    );

    expect(csv, contains('service_oil_change;service_oil_filter'));
  });
}
