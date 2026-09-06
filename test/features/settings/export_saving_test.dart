import 'dart:convert';

import 'package:archive/archive.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/files/file_saver.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/settings/screens/data_screen.dart';
import 'package:garage/features/stations/providers/station_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import 'package:garage/features/costs/providers/cost_providers.dart';
import 'package:garage/features/income/providers/income_providers.dart';
import 'package:garage/features/odometer/providers/odometer_providers.dart';
import 'package:garage/features/trips/providers/trip_providers.dart';
import 'package:garage/features/documents/providers/document_providers.dart';
import 'package:garage/features/tyres/providers/tyre_providers.dart';

import '../../support/pump_screen.dart';
import '../../support/fake_documents.dart';
import 'package:garage/features/observations/providers/observation_providers.dart';

import 'package:garage/features/trips/providers/route_providers.dart';

import '../../support/fake_repositories.dart';
import 'backup_restore_test.dart'
    show
        FakeCosts,
        FakeFuel,
        FakeIncome,
        FakeMaintenance,
        FakeObservations,
        FakeOdometer,
        FakeTrips,
        FakeTyres,
        FakeVehicles;

/// What the save dialog was asked to write, without a platform dialog.
class RecordingFileSaver {
  final List<({String fileName, String mimeType, int bytes})> saved = [];

  /// The raw bytes, for an export that is not text.
  final List<Uint8List> bytes = [];

  /// What was actually written, decoded. The length alone says a file was
  /// produced; only the text says whether it holds what the screen claims.
  final List<String> contents = [];
  bool accept = true;

  Future<bool> call({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    saved.add((fileName: fileName, mimeType: mimeType, bytes: bytes.length));
    this.bytes.add(bytes);
    // Zip bytes are not text; only the callers that write text read this.
    contents.add(mimeType == 'application/zip' ? '' : utf8.decode(bytes));
    return accept;
  }
}

FuelEntry fill() => FuelEntry(
  id: 'f1',
  vehicleId: 'v1',
  date: DateTime.utc(2026, 7, 24),
  odometerKm: 51000,
  volumeL: 40,
  pricePerL: 1.55,
  total: 62,
  fullTank: true,
  missedFill: false,
  createdBy: 'u1',
);

Future<RecordingFileSaver> pumpData(WidgetTester tester) async {
  final saver = RecordingFileSaver();
  await pumpScreen(
    tester,
    const DataScreen(),
    initialLocation: '/data',
    surface: const Size(400, 1600),
    overrides: [
      vehiclesProvider.overrideWith((ref) async => [testVehicle('v1')]),
      allVehiclesProvider.overrideWith((ref) async => [testVehicle('v1')]),
      rawFuelEntriesProvider('v1').overrideWith((ref) async => [fill()]),
      serviceEntriesProvider('v1').overrideWith((ref) async => const []),
      // The JSON backup walks every repository, so all of them have to
      // resolve even though this test only cares where the file ends up.
      vehicleRepositoryProvider.overrideWithValue(
        FakeVehicles([testVehicle('v1')]),
      ),
      fuelRepositoryProvider.overrideWithValue(FakeFuel([fill()])),
      costRepositoryProvider.overrideWithValue(FakeCosts()),
      odometerRepositoryProvider.overrideWithValue(FakeOdometer()),
      tripRepositoryProvider.overrideWithValue(FakeTrips()),
      incomeRepositoryProvider.overrideWithValue(FakeIncome()),
      maintenanceRepositoryProvider.overrideWithValue(FakeMaintenance()),
      tyreRepositoryProvider.overrideWithValue(FakeTyres()),
      observationRepositoryProvider.overrideWithValue(FakeObservations()),
      routeRepositoryProvider.overrideWithValue(FakeRouteRepository()),
      documentRepositoryProvider.overrideWithValue(FakeDocumentRepository()),
      locationGrantedStateProvider.overrideWith((ref) async => false),
      fileSaverProvider.overrideWithValue(saver.call),
    ],
  );
  await tester.pumpAndSettle();
  return saver;
}

Future<void> tapRow(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  // Exports went straight to the share sheet, which is the wrong default for
  // "get my data out": the common case is putting a file somewhere, and the
  // share sheet made that a two-step detour through whichever app happened to
  // accept it.
  group('getting a file onto the device', () {
    testWidgets('a backup is written where the user chose', (tester) async {
      final saver = await pumpData(tester);

      await tapRow(tester, 'Back up everything');

      expect(saver.saved, hasLength(1));
      expect(saver.saved.single.mimeType, 'application/json');
      expect(saver.saved.single.bytes, greaterThan(0));
    });

    testWidgets('says "saved", not the wording the share button uses', (
      tester,
    ) async {
      // This flow writes to a folder, not to another app; "Backup shared"
      // said something that had not happened.
      await pumpData(tester);

      await tapRow(tester, 'Back up everything');
      await tester.pump();

      expect(find.textContaining('Backup saved:'), findsOneWidget);
      expect(find.text('Backup shared'), findsNothing);
    });

    testWidgets('and is named so it can be found again', (tester) async {
      final saver = await pumpData(tester);

      await tapRow(tester, 'Back up everything');

      expect(
        saver.saved.single.fileName,
        matches(RegExp(r'^garage-backup-\d{4}-\d{2}-\d{2}\.json$')),
        reason: 'the date is what tells two backups apart in a folder',
      );
    });

    testWidgets('a CSV export is a separate file and a separate word', (
      tester,
    ) async {
      final saver = await pumpData(tester);

      await tapRow(tester, 'Export as spreadsheets');

      expect(saver.saved, hasLength(1));
      expect(saver.saved.single.mimeType, 'application/zip');
      expect(
        saver.saved.single.fileName,
        matches(RegExp(r'^garage-export-\d{4}-\d{2}-\d{2}\.zip$')),
        reason: 'one of these restores and the other does not',
      );
    });

    testWidgets('backing out of the dialog is not reported as saved', (
      tester,
    ) async {
      final saver = await pumpData(tester);
      saver.accept = false;

      await tapRow(tester, 'Back up everything');

      expect(find.textContaining('Saved'), findsNothing);
      expect(find.textContaining('saved'), findsNothing);
    });

    testWidgets('sharing is still offered, as the secondary action', (
      tester,
    ) async {
      // Some people do want it straight into a chat, and taking that away to
      // fix the default would be trading one complaint for another.
      await pumpData(tester);

      final target = find.text('Back up everything');
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-backup-share')), findsOneWidget);
    });
  });

  // The exporters existed and were unit-tested; nothing proved the screen
  // called them. Fuel and services had been the only two written for a long
  // time, so "Export as spreadsheets" quietly meant "export two of the six kinds you
  // can import".
  group('the export is a folder of real tables', () {
    testWidgets('one file per kind, in a zip a spreadsheet can open', (
      tester,
    ) async {
      // It used to be twelve differently shaped tables concatenated into one
      // .csv with # comment lines between them. Excel, Numbers and pandas all
      // read that as one broken table.
      final saver = await pumpData(tester);

      await tapRow(tester, 'Export as spreadsheets');

      expect(saver.saved.single.mimeType, 'application/zip');
      expect(
        saver.saved.single.fileName,
        matches(RegExp(r'^garage-export-\d{4}-\d{2}-\d{2}\.zip$')),
      );
      final names = ZipDecoder()
          .decodeBytes(saver.bytes.single)
          .files
          .map((file) => file.name)
          .toList();
      for (final kind in [
        'fuel',
        'service',
        'cost',
        'income',
        'trip',
        'odometer',
        'tyres',
      ]) {
        expect(
          names,
          contains('v1-$kind.csv'),
          reason: '$kind has no file in the export',
        );
      }
      // What the household owns, which no section ever carried.
      expect(names, contains('vehicles.csv'));
    });

    testWidgets('and every table carries its own header row', (tester) async {
      final saver = await pumpData(tester);

      await tapRow(tester, 'Export as spreadsheets');

      final archive = ZipDecoder().decodeBytes(saver.bytes.single);
      String contentOf(String name) =>
          utf8.decode(archive.findFile(name)!.content as List<int>);

      expect(contentOf('v1-cost.csv'), contains('vignette_country'));
      expect(contentOf('v1-trip.csv'), contains('purpose'));
      expect(contentOf('v1-trip.csv'), contains('start_odometer_km'));
      expect(contentOf('v1-odometer.csv'), contains('odometer_km'));
      expect(contentOf('v1-tyres.csv'), contains('front_left_mm'));
      expect(contentOf('vehicles.csv'), contains('plate'));
    });
  });

  testWidgets('an export that cannot be built says so', (tester) async {
    // Eight per-vehicle reads and a zip: a throw from any of them used to be
    // an unhandled future, and the tap looked like it had done nothing at
    // all. Here the service history is the read that fails, because this
    // harness deliberately does not stand it up.
    final saver = RecordingFileSaver();
    await pumpScreen(
      tester,
      const DataScreen(),
      initialLocation: '/data',
      surface: const Size(400, 1600),
      overrides: [
        vehiclesProvider.overrideWith((ref) async => [testVehicle('v1')]),
        allVehiclesProvider.overrideWith((ref) async => [testVehicle('v1')]),
        rawFuelEntriesProvider('v1').overrideWith((ref) async => [fill()]),
        vehicleRepositoryProvider.overrideWithValue(
          FakeVehicles([testVehicle('v1')]),
        ),
        locationGrantedStateProvider.overrideWith((ref) async => false),
        fileSaverProvider.overrideWithValue(saver.call),
      ],
    );
    await tester.pumpAndSettle();

    await tapRow(tester, 'Export as spreadsheets');

    expect(saver.saved, isEmpty);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
