import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/import/fuelio_backup.dart';

FuelioFillUp fill({String? station}) => FuelioFillUp(
  date: DateTime.utc(2026, 8, 12),
  odometerKm: 48029,
  volumeL: 37.7,
  fullTank: true,
  missedFill: false,
  station: station,
);

FuelioBackup backupOf(List<FuelioFillUp> fills) => FuelioBackup(
  fillUps: fills,
  costs: const [],
  services: const [],
  reminders: const [],
);

void main() {
  // Fuelio's export has a City column and a StationID column, and a real
  // export has both empty on every row: the app it came from does not record
  // where the fuel was bought in any form this file carries. Every imported
  // fill-up therefore arrives with no station, which is worth offering to fix
  // once rather than leaving fifty rows to be edited by hand.
  group('whether a backup names any station', () {
    test('a file with no station anywhere says so', () {
      expect(backupOf([fill(), fill()]).hasAnyStation, isFalse);
    });

    test('one named station is enough to leave it alone', () {
      expect(backupOf([fill(), fill(station: 'INA')]).hasAnyStation, isTrue);
    });

    test('a blank string is not a station', () {
      expect(
        backupOf([fill(station: ''), fill(station: '   ')]).hasAnyStation,
        isFalse,
      );
    });

    test('a file with no fill-ups at all has nothing to offer', () {
      // Nothing to apply a station to, so the prompt would be asking about
      // rows that do not exist.
      expect(backupOf(const []).hasAnyStation, isFalse);
      expect(backupOf(const []).fillUps, isEmpty);
    });
  });

  test('a real Fuelio export names no station on any row', () {
    // Captured from an actual Fuelio backup and anonymised. Both columns that
    // could carry a station are present and empty on every row: `City` is
    // blank and `StationID` is 0. That is what the export looks like, and it
    // is why the import offers to set one.
    //
    // A copy rather than a reference to the file it came from: the original
    // sits in `docs/wishlist`, which is gitignored — it holds a real
    // registration plate and a year of somebody's driving, so it is not in
    // the repository and a test that read it passed locally and failed in CI.
    final backup = parseFuelioBackup(_anonymisedExport);

    expect(backup.fillUps, hasLength(3));
    expect(backup.hasAnyStation, isFalse);
  });
}

/// A trimmed, anonymised Fuelio export: the real column layout, three rows.
const _anonymisedExport = '''
"## Vehicle"
"Name","Description","DistUnit","FuelUnit","ConsumptionUnit","ImportCSVDateFormat","VIN","Insurance","Plate","Make","Model","Year","TankCount","Tank1Type","Tank2Type","Active","Tank1Capacity","Tank2Capacity","FuelUnitTank2","FuelConsumptionTank2","guid","lastupdated"
"Example Car","Description","0","0","0","yyyy-MM-dd","","","","Renault","Clio","2022","1","100","0","1","42.0","0.0","0","0","00000000-0000-4000-8000-000000000000","1786828899014"
"## Log"
"Data","Odo (km)","Fuel (litres)","Full","Price (optional)","l/100km (optional)","latitude (optional)","longitude (optional)","City (optional)","Notes (optional)","Missed","TankNumber","FuelType","VolumePrice","StationID (optional)","ExcludeDistance","UniqueId","TankCalc","Weather","guid","lastupdated"
"2026-08-12 20:03","48029.0","37.737","1","58.87","5.74","0.0","0.0",,"","0","1","110","1.56","0","0.0","48","0.0",,"00000000-0000-4000-8000-000000000001","1786557938304"
"2026-08-07 18:12","47371.0","32.037","1","51.9","8.78","0.0","0.0",,"","0","1","110","1.62","0","0.0","47","0.0",,"00000000-0000-4000-8000-000000000002","1786557938306"
"2026-07-25 14:58","46818.0","34.578","1","53.25","6.07","0.0","0.0",,"","0","1","110","1.54","0","0.0","45","0.0",,"00000000-0000-4000-8000-000000000003","1786557938308"
''';
