import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/export/csv_export.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/income_entry.dart';
import 'package:garage/domain/entities/odometer_entry.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/domain/maintenance/recurring_costs.dart';

void main() {
  test('the fuel export carries a header row', () {
    final csv = fuelEntriesToCsv(const [], vehicleName: 'Golf');

    expect(csv.split('\n').first, contains('odometer'));
  });

  test('a fuel entry exports its values', () {
    final csv = fuelEntriesToCsv([
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
    ], vehicleName: 'Golf');

    expect(csv, contains('2026-07-01'));
    expect(csv, contains('50000'));
    expect(csv, contains('45.2'));
    expect(csv, contains('INA'));
  });

  test('a field containing a comma is quoted, not split', () {
    final csv = fuelEntriesToCsv([
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
    ], vehicleName: 'Golf');

    expect(csv, contains('"topped up, then washed"'));
    expect(csv.trim().split('\n'), hasLength(2));
  });

  test('the service export joins multiple items into one cell', () {
    final csv = serviceEntriesToCsv([
      ServiceEntry(
        id: '1',
        vehicleId: 'v1',
        date: DateTime(2026, 7, 1),
        odometerKm: 50000,
        serviceTypeKeys: const ['service_oil_change', 'service_oil_filter'],
        cost: 120,
        createdBy: 'u1',
      ),
    ], vehicleName: 'Golf');

    expect(csv, contains('service_oil_change;service_oil_filter'));
  });

  // The exporter wrote fuel and services and nothing else, while CsvEntryKind
  // imports six kinds — so a household could bring its costs and trips in from
  // another app and had no way to take them back out. For a file whose own
  // docstring calls itself the portability mechanism, that is the wrong
  // direction.
  group('the kinds that had no CSV at all', () {
    test('a cost exports its category and amount', () {
      final csv = costEntriesToCsv([
        CostEntry(
          id: 'c1',
          vehicleId: 'v1',
          date: DateTime.utc(2026, 4, 1),
          category: CostCategories.insurance,
          amount: 300,
          odometerKm: 51500,
          notes: 'annual',
          createdBy: 'u1',
        ),
      ], vehicleName: 'Golf');

      expect(csv.split('\n').first, contains('category'));
      expect(csv, contains('2026-04-01'));
      expect(csv, contains('insurance'));
      expect(csv, contains('300'));
      expect(csv, contains('51500'));
    });

    // The pair that decides when a vignette lapses. Dropping them here would
    // repeat the mistake the JSON backup had just been fixed for.
    test('a vignette carries what it was for', () {
      final csv = costEntriesToCsv([
        CostEntry(
          id: 'c1',
          vehicleId: 'v1',
          date: DateTime.utc(2026, 5, 23),
          category: CostCategories.vignette,
          amount: 16,
          createdBy: 'u1',
          vignetteCountry: VignetteCountry.slovenia,
          vignetteValidity: VignetteValidity.days7,
        ),
      ], vehicleName: 'Golf');

      expect(csv, contains('SI'));
      expect(csv, contains('days7'));
    });

    test('income exports its category and amount', () {
      final csv = incomeEntriesToCsv([
        IncomeEntry(
          id: 'i1',
          vehicleId: 'v1',
          date: DateTime.utc(2026, 4, 12),
          category: IncomeCategories.ride,
          amount: 25,
          createdBy: 'u1',
        ),
      ], vehicleName: 'Golf');

      expect(csv, contains('25'));
      expect(csv, contains(IncomeCategories.ride));
    });

    test('a trip exports where it went and what it was for', () {
      final csv = tripEntriesToCsv([
        TripEntry(
          id: 't1',
          vehicleId: 'v1',
          date: DateTime.utc(2026, 4, 12),
          distanceKm: 188,
          purpose: TripPurpose.business,
          title: 'Split',
          fromPlace: 'Zagreb',
          toPlace: 'Split',
          startOdometerKm: 51000,
          endOdometerKm: 51188,
          minutes: 240,
          createdBy: 'u1',
        ),
      ], vehicleName: 'Golf');

      expect(csv.split('\n').first, contains('purpose'));
      expect(csv, contains('business'));
      expect(csv, contains('Zagreb'));
      expect(csv, contains('188'));
      expect(csv, contains('240'));
    });

    test('a bare reading exports as its own row', () {
      final csv = odometerEntriesToCsv([
        OdometerEntry(
          id: 'o1',
          vehicleId: 'v1',
          date: DateTime.utc(2026, 4, 10),
          odometerKm: 52000,
          notes: 'MOT',
          createdBy: 'u1',
        ),
      ], vehicleName: 'Golf');

      expect(csv, contains('52000'));
      expect(csv, contains('MOT'));
    });

    test('every kind names the vehicle and dates the row', () {
      for (final csv in [
        costEntriesToCsv(const [], vehicleName: 'Golf'),
        incomeEntriesToCsv(const [], vehicleName: 'Golf'),
        tripEntriesToCsv(const [], vehicleName: 'Golf'),
        odometerEntriesToCsv(const [], vehicleName: 'Golf'),
      ]) {
        final header = csv.split('\n').first;
        expect(header, contains('vehicle'));
        expect(header, contains('date'));
      }
    });
  });
}
