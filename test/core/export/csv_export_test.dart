import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/export/csv_export.dart';
import 'package:garage/domain/company/payment_method.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/income_entry.dart';
import 'package:garage/domain/entities/odometer_entry.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/domain/maintenance/recurring_costs.dart';
import 'package:garage/domain/entities/observation.dart';

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

  group('what the driver noticed', () {
    Observation seen({DateTime? resolvedOn}) => Observation(
      id: 'o1',
      vehicleId: 'v1',
      noticedOn: DateTime.utc(2026, 3, 2),
      note: 'Rattles at the front when cold',
      odometerKm: 142300,
      resolvedOn: resolvedOn,
      createdBy: 'u1',
      createdAt: DateTime.utc(2026, 3, 2),
    );

    test('a complaint exports with the reading it was noticed at', () {
      final csv = observationsToCsv([seen()], vehicleName: 'Golf');

      expect(csv, contains('Rattles at the front when cold'));
      expect(csv, contains('142300'));
      expect(csv, contains('2026-03-02'));
    });

    test('one still going on has an empty resolved column', () {
      // That column is the answer to "what is wrong with this car" for anyone
      // reading the file without the app.
      final csv = observationsToCsv([seen()], vehicleName: 'Golf');
      final row = csv.split('\n')[1];

      expect(row.trimRight().endsWith(','), isTrue);
    });

    test('one that stopped carries the day it did', () {
      final csv = observationsToCsv([
        seen(resolvedOn: DateTime.utc(2026, 5, 20)),
      ], vehicleName: 'Golf');

      expect(csv, contains('2026-05-20'));
    });
  });

  group('a trip on a named route', () {
    TripEntry commute({String? routeId = 'r1', bool comparable = true}) {
      return TripEntry(
        id: 't1',
        vehicleId: 'v1',
        date: DateTime.utc(2026, 3, 2),
        distanceKm: 22,
        purpose: TripPurpose.private,
        createdBy: 'u1',
        minutes: 35,
        routeId: routeId,
        comparable: comparable,
      );
    }

    test('exports the name, not the id', () {
      // An id is a number nobody outside this database can read, and the name
      // is the column that makes two journeys comparable.
      final csv = tripEntriesToCsv(
        [commute()],
        vehicleName: 'Golf',
        routeNames: const {'r1': 'Doma → Posao'},
      );

      expect(csv, contains('Doma → Posao'));
      expect(csv, isNot(contains('r1')));
    });

    test('a trip on no route leaves the column empty', () {
      final csv = tripEntriesToCsv(
        [commute(routeId: null)],
        vehicleName: 'Golf',
        routeNames: const {'r1': 'Doma → Posao'},
      );

      expect(csv.split('\n')[1], contains(',,'));
    });

    test('an unusual run says so, so a reader can leave it out too', () {
      final csv = tripEntriesToCsv(
        [commute(comparable: false)],
        vehicleName: 'Golf',
        routeNames: const {'r1': 'Doma → Posao'},
      );

      expect(csv, contains('false'));
    });
  });

  // A company's export says who had the car on the day of each entry, read
  // off the assignment log by the caller: this file only writes the cell.
  group('who had the car that day', () {
    List<List<dynamic>> rows(String csv) => Csv().decode(csv);
    String driverOn(DateTime date) => date.month == 9 ? 'Ana' : '';

    test('every entry sheet names who had the car that day', () {
      final fuel = rows(
        fuelEntriesToCsv(
          [
            FuelEntry(
              id: 'f1',
              vehicleId: 'v1',
              date: DateTime.utc(2026, 9, 12),
              odometerKm: 61000,
              volumeL: 40,
              total: 62,
              fullTank: true,
              missedFill: false,
              createdBy: 'u1',
              paidWith: PaymentMethod.companyCard,
            ),
          ],
          vehicleName: 'Golf',
          driverOn: driverOn,
        ),
      );
      expect(fuel.first.last, 'driver');
      expect(fuel.first[fuel.first.indexOf('notes') + 1], 'paid_with');
      expect(fuel[1].last, 'Ana');
      expect(fuel[1][fuel.first.indexOf('paid_with')], 'company_card');

      final costs = rows(
        costEntriesToCsv(
          [
            CostEntry(
              id: 'c1',
              vehicleId: 'v1',
              date: DateTime.utc(2026, 8, 2),
              category: CostCategories.parking,
              amount: 4,
              createdBy: 'u1',
            ),
          ],
          vehicleName: 'Golf',
          driverOn: driverOn,
        ),
      );
      expect(costs.first.last, 'driver');
      expect(costs[1].last, '', reason: 'nobody had the car in August');
    });

    test('a trip keeps the typed driver and adds the assigned one', () {
      final trips = rows(
        tripEntriesToCsv(
          [
            TripEntry(
              id: 't1',
              vehicleId: 'v1',
              date: DateTime.utc(2026, 9, 4),
              distanceKm: 42,
              purpose: TripPurpose.business,
              createdBy: 'u1',
              driver: 'Marko (agency)',
            ),
          ],
          vehicleName: 'Golf',
          driverOn: driverOn,
        ),
      );

      final header = trips.first;
      expect(trips[1][header.indexOf('driver')], 'Marko (agency)');
      expect(trips[1][header.indexOf('assigned_driver')], 'Ana');
    });

    test('the other sheets that date a row carry the column too', () {
      // Fuel and trips are not the only ledgers a driver leaves; a service
      // visit, a reading and a complaint all happened on somebody's day.
      final sheets = [
        serviceEntriesToCsv(
          [
            ServiceEntry(
              id: 's1',
              vehicleId: 'v1',
              date: DateTime.utc(2026, 9, 1),
              odometerKm: 60000,
              serviceTypeKeys: const ['service_oil_change'],
              createdBy: 'u1',
              paidWith: PaymentMethod.ownMoney,
            ),
          ],
          vehicleName: 'Golf',
          driverOn: driverOn,
        ),
        incomeEntriesToCsv(
          [
            IncomeEntry(
              id: 'i1',
              vehicleId: 'v1',
              date: DateTime.utc(2026, 9, 2),
              category: IncomeCategories.ride,
              amount: 25,
              createdBy: 'u1',
            ),
          ],
          vehicleName: 'Golf',
          driverOn: driverOn,
        ),
        odometerEntriesToCsv(
          [
            OdometerEntry(
              id: 'o1',
              vehicleId: 'v1',
              date: DateTime.utc(2026, 9, 3),
              odometerKm: 60100,
              createdBy: 'u1',
            ),
          ],
          vehicleName: 'Golf',
          driverOn: driverOn,
        ),
        observationsToCsv(
          [
            Observation(
              id: 'ob1',
              vehicleId: 'v1',
              noticedOn: DateTime.utc(2026, 9, 5),
              note: 'Squeals when braking',
              createdBy: 'u1',
              createdAt: DateTime.utc(2026, 9, 5),
            ),
          ],
          vehicleName: 'Golf',
          driverOn: driverOn,
        ),
      ];

      for (final sheet in sheets) {
        final table = rows(sheet);
        expect(table.first.last, 'driver', reason: sheet);
        expect(table[1].last, 'Ana', reason: sheet);
      }
      expect(rows(sheets.first)[1], contains('own_money'));
    });

    test('a driver whose name has a comma stays one cell', () {
      final fuel = rows(
        fuelEntriesToCsv(
          [
            FuelEntry(
              id: 'f1',
              vehicleId: 'v1',
              date: DateTime.utc(2026, 9, 12),
              odometerKm: 61000,
              volumeL: 40,
              fullTank: true,
              missedFill: false,
              createdBy: 'u1',
            ),
          ],
          vehicleName: 'Golf',
          driverOn: (_) => 'Horvat, Ana',
        ),
      );

      expect(fuel[1].last, 'Horvat, Ana');
      expect(fuel[1].length, fuel.first.length);
    });

    test('a private garage gets the column, blank', () {
      final fuel = rows(
        fuelEntriesToCsv([
          FuelEntry(
            id: 'f1',
            vehicleId: 'v1',
            date: DateTime.utc(2026, 9, 12),
            odometerKm: 61000,
            volumeL: 40,
            fullTank: true,
            missedFill: false,
            createdBy: 'u1',
          ),
        ], vehicleName: 'Golf'),
      );

      expect(fuel.first.last, 'driver');
      expect(fuel[1].last, '');
      expect(fuel[1].length, fuel.first.length);
    });
  });
}
