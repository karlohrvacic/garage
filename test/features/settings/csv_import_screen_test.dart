import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/files/file_picker.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/features/fuel/data/fuel_repository.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/settings/screens/csv_import_screen.dart';
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

Future<void> pumpImport(
  WidgetTester tester, {
  required RecordingFuelRepository repository,
  String csv = _fuelCsv,
  UnitPreferences preferences = metricPreferences,
}) async {
  await pumpScreen(
    tester,
    const CsvImportScreen(),
    initialLocation: '/import',
    surface: const Size(500, 2400),
    preferences: preferences,
    overrides: [
      fuelRepositoryProvider.overrideWithValue(repository),
      allVehiclesProvider.overrideWith(
        (ref) async => [testVehicle('v1', nickname: 'Golf')],
      ),
      backupFilePickerProvider.overrideWithValue(
        () async => XFile.fromData(
          utf8.encode(csv),
          name: 'export.csv',
          mimeType: 'text/csv',
        ),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('picking a file guesses which column is which', (tester) async {
    final repository = RecordingFuelRepository();
    await pumpImport(tester, repository: repository);

    await tester.tap(find.byKey(const Key('csv-pick-file')));
    await tester.pumpAndSettle();

    // Two rows readable straight away, with no mapping done by hand.
    expect(find.textContaining('2 rows ready'), findsOneWidget);
  });

  testWidgets('a semicolon file with decimal commas imports as written', (
    tester,
  ) async {
    final repository = RecordingFuelRepository();
    await pumpImport(tester, repository: repository);

    await tester.tap(find.byKey(const Key('csv-pick-file')));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byKey(const Key('csv-pick-file')));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byKey(const Key('csv-pick-file')));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 row ready'), findsOneWidget);
    expect(find.textContaining('1 row will be skipped'), findsOneWidget);
    expect(find.textContaining('Line 3'), findsOneWidget);
  });

  testWidgets('a file with no usable columns cannot be imported', (
    tester,
  ) async {
    final repository = RecordingFuelRepository();
    await pumpImport(tester, repository: repository, csv: 'alpha;beta\n1;2\n');

    await tester.tap(find.byKey(const Key('csv-pick-file')));
    await tester.pumpAndSettle();

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

    await tester.tap(find.byKey(const Key('csv-pick-file')));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byKey(const Key('csv-pick-file')));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byKey(const Key('csv-pick-file')));
    await tester.pumpAndSettle();
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
