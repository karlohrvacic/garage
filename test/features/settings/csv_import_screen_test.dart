import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/files/file_picker.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/features/fuel/data/fuel_repository.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/settings/screens/csv_import_screen.dart';
import 'package:garage/domain/entities/trip_draft.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/features/trips/data/trip_repository.dart';
import 'package:garage/features/trips/providers/trip_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import '../../support/pump_screen.dart';

class RecordingFuelRepository implements FuelRepository {
  final List<FuelEntry> added = [];

  @override
  Future<List<FuelEntry>> forVehicle(String vehicleId) async => added;

  @override
  Future<void> add(FuelEntry entry) async => added.add(entry);

  @override
  Future<void> update(FuelEntry entry) async {}

  @override
  Future<void> delete(String id) async {}
}

const _fuelCsv =
    'Date;Odometer (km);Litres;Total cost\n'
    '09/03/2026;1000;40,5;62,30\n'
    '23/03/2026;1500;38;58,00\n';

/// Records the trip a Car Scanner recording turns into.
class RecordingTripRepository implements TripRepository {
  final List<TripEntry> added = [];

  /// Every write the screen tried, including the ones that threw. What a
  /// retry carried is only visible here.
  final List<TripEntry> attempted = [];

  @override
  Future<List<TripEntry>> forVehicle(String vehicleId) async => added;

  @override
  Future<void> add(TripEntry entry) async {
    attempted.add(entry);
    added.add(entry);
  }

  @override
  Future<void> update(TripEntry entry) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<TripDraft?> openDraft(String vehicleId) async => null;

  @override
  Future<void> startDraft(TripDraft draft) async {}

  @override
  Future<void> discardDraft(String id) async {}
}

/// Fails the first write and takes the second, which is what a timed-out save
/// looks like from the screen: the row may or may not have landed, and the
/// only way the second attempt can be safe is by carrying the first one's id.
class FlakyTripRepository extends RecordingTripRepository {
  bool _refused = false;

  @override
  Future<void> add(TripEntry entry) async {
    if (!_refused) {
      _refused = true;
      attempted.add(entry);
      throw Exception('timeout');
    }
    return super.add(entry);
  }
}

/// A recording with no distance channel: the OBD adapter never connected, so
/// the file is GPS samples and nothing else. The drive is still real.
const _gpsOnlyCsv =
    '"SECONDS";"PID";"VALUE";"UNITS";"LATITUDE";"LONGTITUDE";\n'
    '"53219.7";"Speed (GPS)";"0";"km/h";"45.79";"15.72";\n'
    '"53819.7";"Speed (GPS)";"41";"km/h";"45.80";"15.73";\n';

/// The long format Car Scanner's "export records" writes, one file per drive.
const _carScannerCsv =
    '"SECONDS";"PID";"VALUE";"UNITS";"LATITUDE";"LONGTITUDE";\n'
    '"85095.1";"Distance travelled";"0";"km";"45.79";"15.72";\n'
    '"86000.0";"Distance travelled";"12.4";"km";"45.80";"15.73";\n'
    '"87039.0";"Distance travelled";"32.37";"km";"45.81";"15.74";\n'
    '"87039.0";"Distance travelled (total)";"77.62";"km";"45.81";"15.74";\n'
    '"87039.0";"Fuel used";"1.84";"L";"45.81";"15.74";\n';

Future<void> pumpImport(
  WidgetTester tester, {
  required RecordingFuelRepository repository,
  String csv = _fuelCsv,
  String fileName = 'export.csv',
  RecordingTripRepository? trips,
  UnitPreferences preferences = metricPreferences,
  Locale? locale,
  Size surface = const Size(500, 2400),
  double textScale = 1,
}) async {
  await pumpScreen(
    tester,
    const CsvImportScreen(),
    initialLocation: '/import',
    surface: surface,
    locale: locale,
    textScale: textScale,
    preferences: preferences,
    overrides: [
      fuelRepositoryProvider.overrideWithValue(repository),
      if (trips != null) tripRepositoryProvider.overrideWithValue(trips),
      allVehiclesProvider.overrideWith(
        (ref) async => [testVehicle('v1', nickname: 'Golf')],
      ),
      // A real file on disk, not `XFile.fromData`: the name is what dates a
      // Car Scanner recording, and `fromData` drops it — its `name` getter
      // reads the path, which such an XFile does not have.
      backupFilePickerProvider.overrideWithValue(() async {
        final file = File('${Directory.systemTemp.path}/$fileName')
          ..writeAsStringSync(csv);
        addTearDown(() {
          if (file.existsSync()) {
            file.deleteSync();
          }
        });
        return XFile(file.path);
      }),
    ],
  );
  await tester.pumpAndSettle();
}

/// Picks the file and waits for it to actually be read.
///
/// The picker now hands back a real file on disk, because a Car Scanner
/// recording is dated from its name and `XFile.fromData` has none. Real I/O
/// does not finish inside `pumpAndSettle`, which only pumps frames — without
/// `runAsync` the screen is asserted against before it has read anything.
Future<void> pickFile(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.tap(find.byKey(const Key('csv-pick-file')));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

void main() {
  group('a Car Scanner recording', _carScannerTests);

  testWidgets('picking a file guesses which column is which', (tester) async {
    final repository = RecordingFuelRepository();
    await pumpImport(tester, repository: repository);

    await pickFile(tester);

    // Two rows readable straight away, with no mapping done by hand.
    expect(find.textContaining('2 rows ready'), findsOneWidget);
  });

  testWidgets('a semicolon file with decimal commas imports as written', (
    tester,
  ) async {
    final repository = RecordingFuelRepository();
    await pumpImport(tester, repository: repository);

    await pickFile(tester);
    await tester.tap(find.byKey(const Key('csv-import')));
    await tester.pumpAndSettle();

    expect(repository.added, hasLength(2));
    expect(repository.added.first.volumeL, 40.5);
    expect(repository.added.first.total, 62.30);
    expect(repository.added.first.date, DateTime.utc(2026, 3, 9));
  });

  testWidgets('importing the same file twice does not double the history', (
    tester,
  ) async {
    final repository = RecordingFuelRepository();
    await pumpImport(tester, repository: repository);

    await pickFile(tester);
    await tester.tap(find.byKey(const Key('csv-import')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('csv-import')));
    await tester.pumpAndSettle();

    expect(repository.added, hasLength(2));
    expect(find.textContaining('already there'), findsOneWidget);
  });

  testWidgets('a row that cannot be read is reported, not written', (
    tester,
  ) async {
    final repository = RecordingFuelRepository();
    await pumpImport(
      tester,
      repository: repository,
      csv:
          'Date;Odometer;Litres\n'
          '09/03/2026;1000;40\n'
          'sometime;1500;38\n',
    );

    await pickFile(tester);

    expect(find.textContaining('1 row ready'), findsOneWidget);
    expect(find.textContaining('1 row will be skipped'), findsOneWidget);
    expect(find.textContaining('Line 3'), findsOneWidget);
  });

  testWidgets('a file with no usable columns cannot be imported', (
    tester,
  ) async {
    final repository = RecordingFuelRepository();
    await pumpImport(tester, repository: repository, csv: 'alpha;beta\n1;2\n');

    await pickFile(tester);

    expect(find.textContaining('Choose a column for'), findsWidgets);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('csv-import')))
          .onPressed,
      isNull,
      reason: 'the import button refuses rather than writing nothing',
    );
  });

  testWidgets('miles are converted to kilometres on the way in', (
    tester,
  ) async {
    final repository = RecordingFuelRepository();
    await pumpImport(tester, repository: repository);

    await pickFile(tester);
    await tester.tap(find.text('Distances are in miles'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('csv-import')));
    await tester.pumpAndSettle();

    expect(repository.added.first.odometerKm, 1609);
  });

  testWidgets('gallons mean the household\'s own gallons', (tester) async {
    // A UK household reads and writes imperial gallons everywhere else in the
    // app, so a file it says is "in gallons" is in those. Assuming US would
    // understate every volume by a fifth, silently and permanently.
    final repository = RecordingFuelRepository();
    await pumpImport(
      tester,
      repository: repository,
      csv:
          'Date;Odometer;Gallons;Price\n'
          '09/03/2026;1000;10;4.20\n',
      preferences: const UnitPreferences(
        distance: DistanceUnit.mi,
        volume: VolumeUnit.ukGallon,
        currencyCode: 'GBP',
      ),
    );

    await pickFile(tester);
    await tester.tap(find.text('Volumes are in gallons'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('csv-import')));
    await tester.pumpAndSettle();

    expect(repository.added.single.volumeL, closeTo(45.4609, 0.001));
    expect(repository.added.single.pricePerL, closeTo(0.92386, 0.0001));
  });

  testWidgets('a price per gallon is converted along with the gallons', (
    tester,
  ) async {
    // Converting the volume but not the price leaves an entry whose own
    // numbers disagree — 10 gallons at "4.20 per litre" for a total of 42 —
    // and puts every price-per-litre statistic out by a factor of 3.8.
    final repository = RecordingFuelRepository();
    await pumpImport(
      tester,
      repository: repository,
      csv:
          'Date;Odometer;Gallons;Price;Total\n'
          '09/03/2026;1000;10;4.20;42.00\n',
    );

    await pickFile(tester);
    await tester.tap(find.text('Volumes are in gallons'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('csv-import')));
    await tester.pumpAndSettle();

    final entry = repository.added.single;
    expect(entry.volumeL, closeTo(37.854, 0.001));
    expect(entry.pricePerL, closeTo(1.10952, 0.0001));
    expect(entry.total, 42.00);
    expect(
      entry.pricePerL! * entry.volumeL,
      closeTo(entry.total!, 0.01),
      reason: 'the entry has to agree with itself',
    );
  });
}

/// A Car Scanner export is telemetry, not a table: tens of thousands of rows
/// for one drive, no columns worth mapping, and the whole file adds up to a
/// single line in the trip log.
void _carScannerTests() {
  testWidgets('a recording is recognised and summarised, not mapped', (
    tester,
  ) async {
    final trips = RecordingTripRepository();
    await pumpImport(
      tester,
      repository: RecordingFuelRepository(),
      csv: _carScannerCsv,
      fileName: '2026-01-27 23-38-14.csv',
      trips: trips,
    );

    await pickFile(tester);

    expect(find.byKey(const Key('car-scanner-card')), findsOneWidget);
    // The drive's own distance, not Car Scanner's running total of 77.62.
    expect(find.textContaining('32.4 km'), findsOneWidget);
    expect(find.byKey(const Key('csv-ready')), findsNothing);
  });

  testWidgets('importing it writes one trip, dated from the file name', (
    tester,
  ) async {
    final trips = RecordingTripRepository();
    await pumpImport(
      tester,
      repository: RecordingFuelRepository(),
      csv: _carScannerCsv,
      fileName: '2026-01-27 23-38-14.csv',
      trips: trips,
    );

    await pickFile(tester);
    await tester.tap(find.byKey(const Key('car-scanner-import')));
    await tester.pumpAndSettle();

    expect(trips.added, hasLength(1));
    expect(trips.added.single.distanceKm, 32.37);
    expect(trips.added.single.minutes, 32);
    expect(trips.added.single.date, DateTime.utc(2026, 1, 27));
  });

  testWidgets('a scanner left running in a parked car is called out', (
    tester,
  ) async {
    await pumpImport(
      tester,
      repository: RecordingFuelRepository(),
      csv:
          '"SECONDS";"PID";"VALUE";"UNITS";"LATITUDE";"LONGTITUDE";\n'
          '"53106.0";"Distance travelled";"0";"km";"45.79";"15.72";\n'
          '"59290.0";"Distance travelled";"0.42";"km";"45.79";"15.72";\n',
      fileName: '2025-09-04 14-44-54.csv',
      trips: RecordingTripRepository(),
    );

    await pickFile(tester);

    expect(find.textContaining('never went anywhere'), findsOneWidget);
  });

  testWidgets(
    'a save that timed out is retried as the same row, not a second',
    (tester) async {
      // A write that times out cannot be cancelled: it may well have landed.
      // Pressing import again therefore has to carry the first attempt's id, so
      // the backend can refuse it as "already there" — the id was being minted
      // at the moment of the press, which made every retry a fresh trip.
      final trips = FlakyTripRepository();
      await pumpImport(
        tester,
        repository: RecordingFuelRepository(),
        csv: _carScannerCsv,
        fileName: '2026-01-27 23-38-14.csv',
        trips: trips,
      );

      await pickFile(tester);
      await tester.tap(find.byKey(const Key('car-scanner-import')));
      await tester.pumpAndSettle();
      final refused = trips.attempted.single;

      await tester.tap(find.byKey(const Key('car-scanner-import')));
      await tester.pumpAndSettle();

      expect(trips.added.single.id, refused.id);
      expect(trips.attempted.map((e) => e.id).toSet(), hasLength(1));
    },
  );

  testWidgets('a recording with no distance asks rather than importing zero', (
    tester,
  ) async {
    // Writing the zero would put a 0 km journey in a logbook somebody may one
    // day hand to a tax inspector, and "add it afterwards" only works for the
    // person who remembers they have to.
    final trips = RecordingTripRepository();
    await pumpImport(
      tester,
      repository: RecordingFuelRepository(),
      csv: _gpsOnlyCsv,
      fileName: '2026-01-27 23-38-14.csv',
      trips: trips,
    );

    await pickFile(tester);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('car-scanner-import')),
    );
    expect(button.onPressed, isNull, reason: 'nothing to import yet');

    await tester.enterText(find.byKey(const Key('car-scanner-distance')), '18');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('car-scanner-import')));
    await tester.pumpAndSettle();

    expect(trips.added.single.distanceKm, 18);
    expect(trips.added.single.minutes, 10);
  });

  testWidgets('and the distance it asks for is in the household unit', (
    tester,
  ) async {
    final trips = RecordingTripRepository();
    await pumpImport(
      tester,
      repository: RecordingFuelRepository(),
      csv: _gpsOnlyCsv,
      fileName: '2026-01-27 23-38-14.csv',
      trips: trips,
      preferences: const UnitPreferences(
        distance: DistanceUnit.mi,
        volume: VolumeUnit.liter,
        currencyCode: 'EUR',
      ),
    );

    await pickFile(tester);
    await tester.enterText(find.byKey(const Key('car-scanner-distance')), '10');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('car-scanner-import')));
    await tester.pumpAndSettle();

    expect(trips.added.single.distanceKm, closeTo(16.09, 0.01));
  });

  testWidgets('a recording nobody can date is not quietly dated today', (
    tester,
  ) async {
    // The file name is the only thing that says which day a recording was, and
    // a renamed file has lost it. Today's date would be a guess that reads as
    // a fact for as long as the trip log exists.
    final trips = RecordingTripRepository();
    await pumpImport(
      tester,
      repository: RecordingFuelRepository(),
      csv: _carScannerCsv,
      fileName: 'drive.csv',
      trips: trips,
    );

    await pickFile(tester);

    expect(find.byKey(const Key('car-scanner-card')), findsOneWidget);
    expect(find.byKey(const Key('car-scanner-date')), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('car-scanner-import')),
    );
    expect(button.onPressed, isNull);
    expect(trips.added, isEmpty);
  });

  // Croatian runs a third longer than English, and the card at its widest is
  // the one asking for both things a recording can fail to carry: two warning
  // sentences, a date row and a labelled field with a unit suffix.
  testWidgets(
    'the card that asks for both fits in Croatian at 320px and 1.5x',
    (tester) async {
      await pumpImport(
        tester,
        repository: RecordingFuelRepository(),
        csv: _gpsOnlyCsv,
        fileName: 'voznja.csv',
        trips: RecordingTripRepository(),
        locale: const Locale('hr'),
        surface: const Size(320, 2400),
        textScale: 1.5,
      );

      await pickFile(tester);

      expect(find.byKey(const Key('car-scanner-card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the card that asks for both fits in Italian at 320px and 1.5x', (
    tester,
  ) async {
    await pumpImport(
      tester,
      repository: RecordingFuelRepository(),
      csv: _gpsOnlyCsv,
      fileName: 'voznja.csv',
      trips: RecordingTripRepository(),
      locale: const Locale('it'),
      surface: const Size(320, 2400),
      textScale: 1.5,
    );

    await pickFile(tester);

    expect(find.byKey(const Key('car-scanner-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an ordinary CSV still gets its columns mapped', (tester) async {
    // The positive control: recognising a recording must not swallow every
    // other file the importer exists for.
    await pumpImport(tester, repository: RecordingFuelRepository());

    await pickFile(tester);

    expect(find.byKey(const Key('car-scanner-card')), findsNothing);
    expect(find.byKey(const Key('csv-ready')), findsOneWidget);
  });
}
