import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/core/widgets/adaptive.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/features/fuel/data/fuel_repository.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/features/fuel/screens/fuel_log_screen.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/l10n/app_localizations.dart';

FuelEntry fill({
  required String id,
  required int odometerKm,
  bool missedFill = false,
}) {
  return FuelEntry(
    id: id,
    vehicleId: 'v1',
    date: DateTime.utc(2026, 7, 24),
    odometerKm: odometerKm,
    volumeL: 43.4,
    pricePerL: 1.55,
    total: 67.27,
    fullTank: true,
    missedFill: missedFill,
    createdBy: 'u1',
  );
}

/// A repository whose deletes always fail, for the swipe's failure path.
class FailingFuelRepository implements FuelRepository {
  FailingFuelRepository(this.entries);

  final List<FuelEntry> entries;

  @override
  Future<List<FuelEntry>> forVehicle(String vehicleId) async => entries;

  @override
  Future<void> add(FuelEntry entry) async {}

  @override
  Future<void> update(FuelEntry entry) async {}

  @override
  Future<void> delete(String id) async => throw Exception('nope');
}

Vehicle car({String fuelTypeKey = 'fuel_diesel'}) {
  return Vehicle(
    id: 'v1',
    householdId: 'h1',
    nickname: 'Golf',
    fuelTypeKey: fuelTypeKey,
    baselineOdometerKm: 50000,
    baselineDate: DateTime.utc(2026, 1, 1),
  );
}

Future<void> pumpFuelLog(
  WidgetTester tester,
  List<FuelEntry> entries, {
  FuelRepository? repository,
  Vehicle? vehicle,
  Size? surface,
}) {
  if (surface != null) {
    // One physical pixel per logical pixel, so [surface] means what it says.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = surface;
    addTearDown(tester.view.reset);
  }
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (repository != null)
          fuelRepositoryProvider.overrideWithValue(repository),
        rawFuelEntriesProvider('v1').overrideWith((ref) async => entries),
        allVehiclesProvider.overrideWith((ref) async => [vehicle ?? car()]),
        unitPreferencesProvider.overrideWithValue(
          const UnitPreferences(
            distance: DistanceUnit.km,
            volume: VolumeUnit.liter,
            currencyCode: 'EUR',
          ),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FuelLogScreen(vehicleId: 'v1'),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'a row without a computable economy shows the compact placeholder, '
    'not the long explanation that crushes the ListTile layout',
    (tester) async {
      // A single full-tank fill has no previous fill to compute a span from.
      await pumpFuelLog(tester, [fill(id: 'f1', odometerKm: 51140)]);
      await tester.pumpAndSettle();

      expect(
        find.text('Not enough full-tank fills to calculate'),
        findsNothing,
      );
      expect(find.text(UnitFormat.emptyValue), findsWidgets);
    },
  );

  testWidgets('rows with a computable span still show their economy', (
    tester,
  ) async {
    await pumpFuelLog(tester, [
      fill(id: 'f1', odometerKm: 50310),
      fill(id: 'f2', odometerKm: 51140),
    ]);
    await tester.pumpAndSettle();

    expect(find.textContaining('l/100km'), findsWidgets);
  });

  testWidgets('an electric vehicle reads its economy in kWh', (tester) async {
    await pumpFuelLog(tester, [
      fill(id: 'f1', odometerKm: 50310),
      fill(id: 'f2', odometerKm: 51140),
    ], vehicle: car(fuelTypeKey: 'fuel_electric'));
    await tester.pumpAndSettle();

    expect(find.textContaining('kWh/100km'), findsWidgets);
    expect(find.textContaining('l/100km'), findsNothing);
  });

  testWidgets('a swipe-delete the server refuses says so and keeps the row', (
    tester,
  ) async {
    final entries = [fill(id: 'f1', odometerKm: 50310)];
    await pumpFuelLog(
      tester,
      entries,
      repository: FailingFuelRepository(entries),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Dismissible).first, const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('f1')), findsOneWidget);
  });

  testWidgets('a desktop window keeps the log in a reading column', (
    tester,
  ) async {
    await pumpFuelLog(tester, [
      fill(id: 'f1', odometerKm: 50310),
      fill(id: 'f2', odometerKm: 51140),
    ], surface: const Size(1500, 1000));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(ListView)).width,
      GarageBreakpoints.contentMaxWidth,
      reason:
          'a row is a date on the left and an economy figure on the right '
          'with nothing between them, so extra width only pushes the two '
          'apart',
    );
  });
}
