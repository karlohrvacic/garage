import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/dashboard/providers/dashboard_providers.dart';
import 'package:garage/features/dashboard/widgets/household_metrics_strip.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import '../../support/pump_screen.dart';

Future<void> pumpStrip(
  WidgetTester tester, {
  List<Vehicle> vehicles = const [],
  double spend = 1234.5,
  double? economy = 6.4,
  double textScale = 1,
  Size surface = const Size(400, 800),
}) async {
  await pumpScreen(
    tester,
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: const Scaffold(body: HouseholdMetricsStrip()),
    ),
    surface: surface,
    overrides: [
      vehiclesProvider.overrideWith((ref) async => vehicles),
      allVehiclesProvider.overrideWith((ref) async => vehicles),
      fleetSpendProvider.overrideWith((ref) async => spend),
      fleetAverageEconomyProvider.overrideWith((ref) async => economy),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('it shows the fleet size, spend, and economy', (tester) async {
    await pumpStrip(tester, vehicles: [testVehicle('v1'), testVehicle('v2')]);

    expect(find.textContaining('2'), findsWidgets);
    expect(find.textContaining('1,234.50'), findsOneWidget);
    expect(find.textContaining('6.4'), findsOneWidget);
  });

  testWidgets('an economy that cannot be computed shows a placeholder', (
    tester,
  ) async {
    await pumpStrip(tester, economy: null);

    expect(find.text('—'), findsWidgets);
  });

  testWidgets('it survives a large accessibility text scale', (tester) async {
    await pumpStrip(tester, vehicles: [testVehicle('v1')], textScale: 2);

    expect(tester.takeException(), isNull);
  });

  testWidgets('it survives a narrow window', (tester) async {
    await pumpStrip(
      tester,
      vehicles: [testVehicle('v1')],
      surface: const Size(320, 600),
    );

    expect(tester.takeException(), isNull);
  });
}
