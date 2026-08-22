import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/files/file_picker.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/settings/screens/data_screen.dart';
import 'package:garage/domain/entities/vehicle_transfer.dart';
import 'package:garage/features/vehicles/data/vehicle_repository.dart';
import 'package:garage/features/stations/providers/station_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import '../../support/pump_screen.dart';

class RecordingVehicleRepository implements VehicleRepository {
  @override
  Future<List<VehicleTransfer>> transfersOffered(String householdId) async =>
      const [];

  @override
  Future<void> delete(String id) async {}

  @override
  Future<String?> outstandingTransferCode(String vehicleId) async => null;

  final List<Vehicle> created = [];

  @override
  Future<Vehicle> create(Vehicle vehicle) async {
    created.add(vehicle);
    return Vehicle(
      id: 'created-1',
      householdId: vehicle.householdId,
      nickname: vehicle.nickname,
      fuelTypeKey: vehicle.fuelTypeKey,
      baselineOdometerKm: vehicle.baselineOdometerKm,
      baselineDate: vehicle.baselineDate,
    );
  }

  @override
  Future<List<Vehicle>> forHousehold(String householdId) async => const [];

  @override
  Future<void> update(Vehicle vehicle) async {}

  @override
  Future<void> setArchived(String id, bool archived) async {}

  @override
  Future<void> deleteAllForHousehold(String householdId) async {}

  @override
  Future<String> offerTransfer(String vehicleId) async => 'TRANSFER';

  @override
  Future<String> redeemTransfer({
    required String code,
    required String householdId,
  }) async => 'v1';
}

/// A trimmed Fuelio export: one vehicle, one fill-up.
const _backupCsv = '''
"## Vehicle"
"Name","Description","DistUnit","FuelUnit","VIN","Plate","Make","Model","Year"
"Renault Clio","","0","0","","ZG1234AB","Renault","Clio","2022"
"## Log"
"Data","Odo (km)","Fuel (litres)","Full","Price (optional)","VolumePrice"
"2026-07-25 14:58","46818.0","34.578","1","53.25","1.54"
''';

/// The same export with a City column that is actually filled in, which is
/// what Fuelio *could* produce and what a real one never does.
const _withStationCsv = '''
"## Vehicle"
"Name","Description","DistUnit","FuelUnit","VIN","Plate","Make","Model","Year"
"Renault Clio","","0","0","","ZG1234AB","Renault","Clio","2022"
"## Log"
"Data","Odo (km)","Fuel (litres)","Full","Price (optional)","City (optional)"
"2026-07-25 14:58","46818.0","34.578","1","53.25","INA Zagreb"
''';

const _noVehicleCsv = '''
"## Log"
"Data","Odo (km)","Fuel (litres)","Full"
"2026-07-25 14:58","46818.0","34.578","1"
''';

Future<RecordingVehicleRepository> pumpImport(
  WidgetTester tester, {
  required String csv,
}) => pumpImportWith(tester, csv: csv);

Future<RecordingVehicleRepository> pumpImportWith(
  WidgetTester tester, {
  required String csv,
  RecordingVehicleRepository? vehicleRepository,
  bool locationGranted = false,
}) async {
  vehicleRepository ??= RecordingVehicleRepository();
  await pumpScreen(
    tester,
    const DataScreen(),
    initialLocation: '/data',
    surface: const Size(400, 1600),
    overrides: [
      // The household owns nothing yet — the case that used to do nothing.
      vehiclesProvider.overrideWith((ref) async => const []),
      allVehiclesProvider.overrideWith((ref) async => const []),
      vehicleRepositoryProvider.overrideWithValue(vehicleRepository),
      locationGrantedStateProvider.overrideWith((ref) async => locationGranted),
      backupFilePickerProvider.overrideWithValue(
        () async => XFile.fromData(utf8.encode(csv), name: 'fuelio.csv'),
      ),
    ],
  );
  await tester.pumpAndSettle();
  return vehicleRepository;
}

/// The settings list is long and lazily built, so the import row has to be
/// scrolled into view before it can be tapped.
Future<void> tapImport(WidgetTester tester) async {
  final target = find.text('Import from Fuelio');
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// A repository whose vehicle creation fails, to exercise the other way out
/// of the progress dialog.
class FailingVehicleRepository extends RecordingVehicleRepository {
  @override
  Future<Vehicle> create(Vehicle vehicle) async {
    throw Exception('the network went away');
  }
}

void main() {
  group('the pump-autofill row', () {
    // Once permission is granted there is nothing left to do, and the row said
    // so by disabling itself — which greys the title and subtitle. It then
    // read "On", in the colour the rest of the app uses for "unavailable",
    // beside a tick. Nothing left to do is not the same as nothing you may do.
    testWidgets('does not grey itself out once it is on', (tester) async {
      await pumpImportWith(tester, csv: _backupCsv, locationGranted: true);
      await tester.pumpAndSettle();

      final row = find.widgetWithText(
        ListTile,
        'Fill in the station and price for me',
      );

      expect(tester.widget<ListTile>(row).enabled, isTrue);
      expect(
        tester.widget<ListTile>(row).onTap,
        isNull,
        reason: 'there is nothing left to ask for, so it does not ask',
      );
    });

    testWidgets('and is tappable while it is off', (tester) async {
      await pumpImportWith(tester, csv: _backupCsv, locationGranted: false);
      await tester.pumpAndSettle();

      final row = find.widgetWithText(
        ListTile,
        'Fill in the station and price for me',
      );

      expect(tester.widget<ListTile>(row).onTap, isNotNull);
    });
  });

  group('the progress spinner always comes down', () {
    // It used to be dismissed through the calling widget's context, guarded by
    // `context.mounted` — and creating the first car invalidates the vehicle
    // providers, which unmounts the empty state the import was started from.
    // The guard then returned early and left a modal with no barrier to tap.
    testWidgets('after an import that worked', (tester) async {
      await pumpImport(tester, csv: _backupCsv);

      await tapImport(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('and after one that failed', (tester) async {
      await pumpImportWith(
        tester,
        csv: _backupCsv,
        vehicleRepository: FailingVehicleRepository(),
      );

      await tapImport(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  testWidgets('importing with no cars offers to create the one in the file', (
    tester,
  ) async {
    final vehicles = await pumpImport(tester, csv: _backupCsv);

    await tapImport(tester);

    expect(
      find.textContaining('Renault Clio'),
      findsOneWidget,
      reason: 'the backup names the car, so the import can create it',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();

    expect(vehicles.created, hasLength(1));
    expect(vehicles.created.single.nickname, 'Renault Clio');
    expect(vehicles.created.single.make, 'Renault');
  });

  testWidgets('a backup with no car says so instead of doing nothing', (
    tester,
  ) async {
    final vehicles = await pumpImport(tester, csv: _noVehicleCsv);

    await tapImport(tester);

    expect(
      find.textContaining('has no vehicle in it'),
      findsOneWidget,
      reason: 'tapping and seeing nothing happen is the bug being fixed',
    );
    expect(vehicles.created, isEmpty);
  });

  testWidgets('export says why it is unavailable rather than sharing nothing', (
    tester,
  ) async {
    await pumpImport(tester, csv: _backupCsv);

    final target = find.text('Export as CSV');
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Nothing to export yet — log a fill-up or a service first'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'Export as CSV'))
          .enabled,
      isFalse,
      reason: 'an empty CSV shared to a chat app helps nobody',
    );
  });

  // A real Fuelio export leaves City and StationID empty on every row, so an
  // import used to land fifty fill-ups with nowhere attached and the only fix
  // was fifty edits.
  group('the station a Fuelio file does not carry', () {
    testWidgets('is offered once, at import', (tester) async {
      await pumpImport(tester, csv: _backupCsv);

      await tapImport(tester);

      expect(find.text('Fuel station'), findsOneWidget);
      expect(
        find.textContaining('does not say where you filled up'),
        findsOneWidget,
        reason: 'the field has to explain why it is being asked for',
      );
    });

    testWidgets('is not offered when the file does say', (tester) async {
      await pumpImport(tester, csv: _withStationCsv);

      await tapImport(tester);

      expect(
        find.text('Fuel station'),
        findsNothing,
        reason:
            'asking about a value the file already carries invites the '
            'user to overwrite it',
      );
    });

    testWidgets('is not offered when the import cannot start at all', (
      tester,
    ) async {
      // This file names no car, so it never reaches the dialog. Asserted so
      // the field cannot leak into the one path that bails early.
      await pumpImport(tester, csv: _noVehicleCsv);
      await tapImport(tester);
      await tester.pumpAndSettle();

      expect(find.text('Fuel station'), findsNothing);
    });
  });
}
