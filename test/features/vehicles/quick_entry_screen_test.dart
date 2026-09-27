import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/router/app_redirect.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/costs/providers/cost_providers.dart';
import 'package:garage/features/costs/widgets/cost_entry_sheet.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/fuel/providers/pump_providers.dart';
import 'package:garage/features/fuel/widgets/fuel_entry_sheet.dart';
import 'package:garage/features/odometer/providers/odometer_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/features/vehicles/screens/quick_entry_screen.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../support/pump_screen.dart';

/// Everything the fuel sheet reads on its way up, stubbed at the leaves.
///
/// Overridden directly rather than left to derive: the sheet asks for the fuel
/// log, every odometer reading of every kind, and the station being stood at,
/// and none of that is what this screen's tests are about.
List<Override> sheetStubs(Iterable<String> vehicleIds) {
  return [
    for (final id in vehicleIds) ...[
      rawFuelEntriesProvider(id).overrideWith((ref) async => const []),
      rawOdometerSamplesProvider(id).overrideWith((ref) async => const []),
    ],
    stationAtThePumpProvider.overrideWith((ref, query) async => null),
    for (final id in vehicleIds)
      costEntriesProvider(id).overrideWith((ref) async => const []),
  ];
}

Future<NavigationLog> pumpQuickFuel(
  WidgetTester tester, {
  required List<Vehicle> vehicles,
  Object? failure,
}) {
  return pumpQuickEntry(
    tester,
    const QuickEntryScreen(openSheet: showFuelEntrySheet),
    route: quickFuelRoute,
    vehicles: vehicles,
    failure: failure,
  );
}

Future<NavigationLog> pumpQuickCost(
  WidgetTester tester, {
  required List<Vehicle> vehicles,
  Locale? locale,
  double textScale = 1,
  Size surface = const Size(400, 900),
}) {
  return pumpQuickEntry(
    tester,
    const QuickEntryScreen(openSheet: showCostEntrySheet),
    route: quickCostRoute,
    vehicles: vehicles,
    locale: locale,
    textScale: textScale,
    surface: surface,
  );
}

Future<NavigationLog> pumpQuickEntry(
  WidgetTester tester,
  QuickEntryScreen screen, {
  required String route,
  required List<Vehicle> vehicles,
  Object? failure,
  Locale? locale,
  double textScale = 1,
  Size surface = const Size(400, 900),
}) {
  return pumpScreen(
    tester,
    screen,
    initialLocation: route,
    locale: locale,
    textScale: textScale,
    surface: surface,
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

  group('the expense route', () {
    testWidgets('opens the expense sheet for the one car, on parking', (
      tester,
    ) async {
      await pumpQuickCost(tester, vehicles: [testVehicle('v1')]);
      await tester.pumpAndSettle();

      expect(find.byType(CostEntrySheet), findsOneWidget);
      expect(find.byType(FuelEntrySheet), findsNothing);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .initialValue,
        CostCategories.parking,
      );
    });

    testWidgets('asks which car when there are two', (tester) async {
      await pumpQuickCost(
        tester,
        vehicles: [
          testVehicle('v1', nickname: 'Golf'),
          testVehicle('v2'),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(CostEntrySheet), findsNothing);
      await tester.tap(find.text('Golf'));
      await tester.pumpAndSettle();

      expect(find.byType(CostEntrySheet), findsOneWidget);
    });

    testWidgets('and closing the sheet leaves you on the dashboard', (
      tester,
    ) async {
      final log = await pumpQuickCost(tester, vehicles: [testVehicle('v1')]);
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(CostEntrySheet))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(CostEntrySheet), findsNothing);
      expect(log.last, '/');
    });

    testWidgets('an empty garage falls back to the start-up destination', (
      tester,
    ) async {
      final log = await pumpQuickCost(tester, vehicles: const []);
      await tester.pumpAndSettle();

      expect(find.byType(CostEntrySheet), findsNothing);
      expect(log.last, '/');
    });

    testWidgets('in Croatian on a narrow phone at a large font it lays out', (
      tester,
    ) async {
      await pumpQuickCost(
        tester,
        vehicles: [testVehicle('v1')],
        locale: const Locale('hr'),
        textScale: 1.5,
        surface: const Size(320, 900),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CostEntrySheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
