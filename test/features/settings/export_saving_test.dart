import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_selector/file_selector.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/files/file_picker.dart';
import 'package:garage/core/files/file_saver.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/domain/export/garage_backup.dart';
import 'package:garage/features/vehicles/data/vehicle_repository.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/vehicle_assignment.dart';
import 'package:garage/features/company/providers/company_providers.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/household/data/household_repository.dart';
import 'package:garage/features/household/providers/member_providers.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/settings/providers/settings_providers.dart';
import 'package:garage/features/settings/screens/data_screen.dart';
import 'package:garage/features/stations/providers/station_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:riverpod/misc.dart' show Override;

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

Future<RecordingFileSaver> pumpData(
  WidgetTester tester, {
  Household household = testHousehold,
  String role = 'admin',
  Locale? locale,
  double textScale = 1,
  Size surface = const Size(400, 1600),
  List<Override> overrides = const [],

  /// The vehicle store, for a test about a restore the store refuses.
  VehicleRepository? vehicleRepository,
}) async {
  final saver = RecordingFileSaver();
  await pumpScreen(
    tester,
    const DataScreen(),
    initialLocation: '/data',
    surface: surface,
    locale: locale,
    textScale: textScale,
    household: household,
    role: role,
    overrides: [
      ...overrides,
      vehiclesProvider.overrideWith((ref) async => [testVehicle('v1')]),
      allVehiclesProvider.overrideWith((ref) async => [testVehicle('v1')]),
      rawFuelEntriesProvider('v1').overrideWith((ref) async => [fill()]),
      serviceEntriesProvider('v1').overrideWith((ref) async => const []),
      // The JSON backup walks every repository, so all of them have to
      // resolve even though this test only cares where the file ends up.
      vehicleRepositoryProvider.overrideWithValue(
        vehicleRepository ?? FakeVehicles([testVehicle('v1')]),
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

/// Refuses to create a car, as the insert policy would for a driver or a
/// full free garage.
class _RefusingVehicles extends FakeVehicles {
  _RefusingVehicles() : super([testVehicle('v1')]);

  @override
  Future<Vehicle> create(Vehicle vehicle) async {
    throw const AppFailure(kind: AppFailureKind.permission);
  }
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

  // A company's export says whose car it was on the day of each entry, and
  // can be cut down to one driver: the two things an accountant asks a fleet
  // for that a household never needs.
  testWidgets('a restore the store refuses says why, not nothing', (
    tester,
  ) async {
    // The picker closed and nothing was said: the restore's failure was an
    // unhandled exception in the handler. The same catch carries the cap
    // the restore raises before creating anything.
    final backup = GarageBackup.encode([
      VehicleBackup(vehicle: testVehicle('v9', nickname: 'Passat')),
    ], householdName: 'Test');
    await pumpData(
      tester,
      vehicleRepository: _RefusingVehicles(),
      overrides: [
        restoreFilePickerProvider.overrideWithValue(
          () async => XFile.fromData(
            Uint8List.fromList(utf8.encode(backup)),
            name: 'backup.json',
          ),
        ),
      ],
    );

    await tapRow(tester, 'Restore from a backup');

    expect(find.textContaining('You do not have access'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('the export on the company plan', () {
    const company = Household(id: 'h1', name: 'Prijevoz', plan: 'company');

    /// Ana has had the car since the new year; Karlo never has. Before the
    /// first handover the log is empty and the members are still two.
    List<Override> fleet({String driverId = 'u2', bool handedOver = true}) => [
      fleetAssignmentsProvider.overrideWith(
        (ref) async => [
          if (handedOver)
            VehicleAssignment(
              id: 'a1',
              vehicleId: 'v1',
              userId: driverId,
              fromDate: DateTime.utc(2026, 1, 1),
            ),
        ],
      ),
      membersProvider.overrideWith(
        (ref) async => const [
          HouseholdMember(userId: 'u1', displayName: 'Karlo', role: 'admin'),
          HouseholdMember(userId: 'u2', displayName: 'Ana', role: 'driver'),
        ],
      ),
    ];

    String fuelSheet(RecordingFileSaver saver) => utf8.decode(
      ZipDecoder()
              .decodeBytes(saver.bytes.single)
              .findFile('v1-fuel.csv')!
              .content
          as List<int>,
    );

    /// The sheet as cells, so a name can be asserted in its column and not
    /// merely somewhere on the page.
    List<List<dynamic>> fuelRows(RecordingFileSaver saver) =>
        Csv().decode(fuelSheet(saver));

    testWidgets('every sheet names the driver of the day', (tester) async {
      final saver = await pumpData(
        tester,
        household: company,
        overrides: fleet(),
      );

      await tapRow(tester, 'Export as spreadsheets');

      final fuel = fuelRows(saver);
      expect(fuel.first.last, 'driver');
      expect(fuel[1].last, 'Ana');
    });

    testWidgets('before the first handover, the chosen driver has no rows', (
      tester,
    ) async {
      // The log is empty, the chooser still lists two members, and Karlo's
      // export must be as empty as his log: everyone's rows under his name
      // is the one answer that misfiles.
      final saver = await pumpData(
        tester,
        household: company,
        overrides: [
          exportDriverFilterProvider.overrideWith((ref) => 'u1'),
          ...fleet(handedOver: false),
        ],
      );

      await tapRow(tester, 'Export as spreadsheets');

      expect(fuelRows(saver), hasLength(1), reason: 'header only');
    });

    testWidgets('the per-driver export drops everybody else\'s entries', (
      tester,
    ) async {
      // The same garage, filtered to Karlo, who never had the car.
      final saver = await pumpData(
        tester,
        household: company,
        overrides: [
          exportDriverFilterProvider.overrideWith((ref) => 'u1'),
          ...fleet(),
        ],
      );

      await tapRow(tester, 'Export as spreadsheets');

      expect(fuelRows(saver), hasLength(1), reason: 'header only');
    });

    testWidgets('a filter chosen in another garage is ignored', (tester) async {
      // The setting outlives switching garages, and the chooser shows
      // Everyone for a driver it does not list: the sheets agree with it
      // rather than coming back empty.
      final saver = await pumpData(
        tester,
        household: company,
        overrides: [
          exportDriverFilterProvider.overrideWith((ref) => 'u9'),
          ...fleet(),
        ],
      );

      await tapRow(tester, 'Export as spreadsheets');

      expect(fuelRows(saver)[1].last, 'Ana');
    });

    testWidgets('a driver who has since left is still named', (tester) async {
      // The window outlives the membership, and the member list no longer
      // has the name: a blank would read as a day nobody had the car.
      final saver = await pumpData(
        tester,
        household: company,
        overrides: fleet(driverId: 'u3'),
      );

      await tapRow(tester, 'Export as spreadsheets');

      expect(fuelRows(saver)[1].last, 'Former member');
    });

    testWidgets('offers the driver to export for, above the export row', (
      tester,
    ) async {
      await pumpData(tester, household: company, overrides: fleet());

      final chooser = find.byKey(const Key('export-driver-filter'));
      await tester.scrollUntilVisible(
        chooser,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Everyone'), findsOneWidget);
      expect(
        tester.getTopLeft(chooser).dy,
        lessThan(tester.getTopLeft(find.text('Export as spreadsheets')).dy),
      );

      await tester.tap(find.text('Everyone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana').last);
      await tester.pumpAndSettle();

      expect(find.text('Ana'), findsOneWidget);
    });

    testWidgets('a private garage has no driver to choose', (tester) async {
      await pumpData(tester);

      expect(find.byKey(const Key('export-driver-filter')), findsNothing);
    });

    testWidgets('a driver is not offered the chooser, and a stale choice '
        'does not empty their export', (tester) async {
      // The log a driver holds is their own windows, so every other pick
      // yields an empty file; the rows are theirs without asking. A choice
      // made as an admin in another garage outlives the switch and is
      // ignored here too.
      final saver = await pumpData(
        tester,
        household: company,
        role: 'driver',
        overrides: [
          exportDriverFilterProvider.overrideWith((ref) => 'u1'),
          ...fleet(),
        ],
      );

      expect(find.byKey(const Key('export-driver-filter')), findsNothing);

      await tapRow(tester, 'Export as spreadsheets');

      expect(fuelRows(saver)[1].last, 'Ana');
    });

    testWidgets('in Croatian on a narrow phone at a large font', (
      tester,
    ) async {
      await pumpData(
        tester,
        household: company,
        overrides: fleet(),
        locale: const Locale('hr'),
        textScale: 1.5,
        surface: const Size(320, 1200),
      );

      final chooser = find.byKey(const Key('export-driver-filter'));
      await tester.scrollUntilVisible(
        chooser,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(chooser, findsOneWidget);
      expect(find.text('Svi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
