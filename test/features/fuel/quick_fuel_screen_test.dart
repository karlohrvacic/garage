import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/router/app_redirect.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/attachments/providers/attachment_providers.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/fuel/providers/pump_providers.dart';
import 'package:garage/features/fuel/screens/quick_fuel_screen.dart';
import 'package:garage/features/fuel/widgets/fuel_entry_sheet.dart';
import 'package:garage/features/odometer/providers/odometer_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:riverpod/misc.dart' show Override;

import '../attachments/attachment_providers_test.dart'
    show FakeAttachmentRepository;
import '../../support/pump_screen.dart';

/// Everything the fuel sheet reads on its way up, stubbed at the leaves.
///
/// Overridden directly rather than left to derive: the sheet asks for the fuel
/// log, every odometer reading of every kind, and the station being stood at,
/// and none of that is what this screen's tests are about.
List<Override> sheetStubs(Iterable<String> vehicleIds) {
  return [
    attachmentRepositoryProvider.overrideWithValue(FakeAttachmentRepository()),
    for (final id in vehicleIds) ...[
      rawFuelEntriesProvider(id).overrideWith((ref) async => const []),
      rawOdometerSamplesProvider(id).overrideWith((ref) async => const []),
      stationAtThePumpProvider(id).overrideWith((ref) async => null),
    ],
  ];
}

Future<NavigationLog> pumpQuickFuel(
  WidgetTester tester, {
  required List<Vehicle> vehicles,
  Object? failure,
}) {
  return pumpScreen(
    tester,
    const QuickFuelScreen(),
    initialLocation: quickFuelRoute,
    overrides: [
      allVehiclesProvider.overrideWith((ref) async {
        if (failure != null) {
          throw failure;
        }
        return vehicles;
      }),
      ...sheetStubs(vehicles.map((v) => v.id)),
    ],
  );
}

void main() {
  testWidgets('one car goes straight to the sheet', (tester) async {
    await pumpQuickFuel(tester, vehicles: [testVehicle('v1')]);
    await tester.pumpAndSettle();

    expect(find.byType(FuelEntrySheet), findsOneWidget);
  });

  testWidgets('and closing the sheet leaves you on the dashboard, not on a '
      'blank route with nowhere to go', (tester) async {
    final log = await pumpQuickFuel(tester, vehicles: [testVehicle('v1')]);
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(FuelEntrySheet))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(FuelEntrySheet), findsNothing);
    expect(log.last, '/');
  });

  testWidgets('two cars ask which, because the sheet never names one', (
    tester,
  ) async {
    await pumpQuickFuel(
      tester,
      vehicles: [
        testVehicle('v1', nickname: 'Golf'),
        testVehicle('v2'),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(FuelEntrySheet), findsNothing);
    expect(find.text('Golf'), findsOneWidget);

    await tester.tap(find.text('Golf'));
    await tester.pumpAndSettle();

    expect(find.byType(FuelEntrySheet), findsOneWidget);
  });

  testWidgets('declining to pick a car lands on the dashboard', (tester) async {
    final log = await pumpQuickFuel(
      tester,
      vehicles: [testVehicle('v1'), testVehicle('v2')],
    );
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.text('v1'))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(FuelEntrySheet), findsNothing);
    expect(log.last, '/');
  });

  // The three ways this route is reached with nothing to log against. None of
  // them may open a sheet with no vehicle behind it, and none may throw: a
  // launcher shortcut is tapped by people who have not opened the app in a
  // month, and a crash on the way in is the whole app as far as they can tell.
  testWidgets('an empty garage falls back to the start-up destination', (
    tester,
  ) async {
    final log = await pumpQuickFuel(tester, vehicles: const []);
    await tester.pumpAndSettle();

    expect(find.byType(FuelEntrySheet), findsNothing);
    expect(log.last, '/');
  });

  testWidgets('a garage of archived cars does too', (tester) async {
    final log = await pumpQuickFuel(
      tester,
      vehicles: [testVehicle('sold', archived: true)],
    );
    await tester.pumpAndSettle();

    expect(find.byType(FuelEntrySheet), findsNothing);
    expect(log.last, '/');
  });

  testWidgets('and so does a garage that could not be loaded', (tester) async {
    final log = await pumpQuickFuel(
      tester,
      vehicles: const [],
      failure: Exception('offline'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FuelEntrySheet), findsNothing);
    expect(log.last, '/');
  });
}
