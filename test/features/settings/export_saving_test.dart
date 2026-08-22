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
import 'package:garage/features/tyres/providers/tyre_providers.dart';

import '../../support/pump_screen.dart';
import 'backup_restore_test.dart'
    show
        FakeCosts,
        FakeFuel,
        FakeIncome,
        FakeMaintenance,
        FakeOdometer,
        FakeTrips,
        FakeTyres,
        FakeVehicles;

/// What the save dialog was asked to write, without a platform dialog.
class RecordingFileSaver {
  final List<({String fileName, String mimeType, int bytes})> saved = [];
  bool accept = true;

  Future<bool> call({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    saved.add((fileName: fileName, mimeType: mimeType, bytes: bytes.length));
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

      expect(find.text('Backup saved'), findsOneWidget);
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

      await tapRow(tester, 'Export as CSV');

      expect(saver.saved, hasLength(1));
      expect(saver.saved.single.mimeType, 'text/csv');
      expect(
        saver.saved.single.fileName,
        matches(RegExp(r'^garage-export-\d{4}-\d{2}-\d{2}\.csv$')),
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
}
