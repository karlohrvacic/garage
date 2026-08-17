import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/files/file_picker.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/settings/screens/settings_screen.dart';
import 'package:garage/features/vehicles/data/vehicle_repository.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import '../../support/pump_screen.dart';

class RecordingVehicleRepository implements VehicleRepository {
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

const _noVehicleCsv = '''
"## Log"
"Data","Odo (km)","Fuel (litres)","Full"
"2026-07-25 14:58","46818.0","34.578","1"
''';

Future<RecordingVehicleRepository> pumpImport(
  WidgetTester tester, {
  required String csv,
}) async {
  final vehicleRepository = RecordingVehicleRepository();
  await pumpScreen(
    tester,
    const SettingsScreen(),
    initialLocation: '/settings',
    surface: const Size(400, 1600),
    overrides: [
      // The household owns nothing yet — the case that used to do nothing.
      vehiclesProvider.overrideWith((ref) async => const []),
      allVehiclesProvider.overrideWith((ref) async => const []),
      vehicleRepositoryProvider.overrideWithValue(vehicleRepository),
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

void main() {
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
}
