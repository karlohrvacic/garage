import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/core/theme/garage_tokens.dart';
import 'package:garage/core/widgets/adaptive.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/features/fuel/data/fuel_repository.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/attachments/providers/attachment_providers.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/features/fuel/screens/fuel_log_screen.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/l10n/app_localizations.dart';

FuelEntry fill({
  required String id,
  required int odometerKm,
  bool missedFill = false,
  String? station,
  String? notes,
  DateTime? date,
}) {
  return FuelEntry(
    id: id,
    vehicleId: 'v1',
    date: date ?? DateTime.utc(2026, 7, 24),
    odometerKm: odometerKm,
    volumeL: 43.4,
    pricePerL: 1.55,
    total: 67.27,
    fullTank: true,
    missedFill: missedFill,
    station: station,
    notes: notes,
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
  Set<String> withAttachments = const {},
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
        entriesWithAttachmentsProvider.overrideWith(
          (ref) async => withAttachments,
        ),
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

  group('the header says what its figures are', () {
    testWidgets('the running figure carries its own distance unit', (
      tester,
    ) async {
      await pumpFuelLog(tester, [
        fill(id: 'f1', odometerKm: 50310),
        fill(id: 'f2', odometerKm: 51140),
      ]);
      await tester.pumpAndSettle();

      // It read "0,09 €" under a heading assembled as "Price per unit / km":
      // a bare amount, and a label naming a unit the figure did not carry.
      expect(find.textContaining('/km'), findsWidgets);
      expect(find.text('Fuel cost'), findsOneWidget);
      expect(find.text('Price per unit / km'), findsNothing);
    });
  });

  group('economy reads at a glance', () {
    /// The colour a fill's row renders [economy] in.
    ///
    /// Scoped to the list: the header quotes an average that can read the same
    /// as one of the rows below it.
    Color? economyColourAt(WidgetTester tester, String economy) {
      final finder = find.descendant(
        of: find.byType(ListView),
        matching: find.text(economy),
      );
      return tester.widget<Text>(finder).style?.color;
    }

    testWidgets('a good tank is green and a bad one is red', (tester) async {
      // Three spans on one tank size: 830 km is frugal, 415 km is thirsty.
      // Which end of this car's own history a tank sits at is the thing worth
      // seeing without reading four numbers and subtracting.
      await pumpFuelLog(tester, [
        fill(id: 'f1', odometerKm: 50310),
        fill(id: 'f2', odometerKm: 51140),
        fill(id: 'f3', odometerKm: 51555),
      ]);
      await tester.pumpAndSettle();

      // The harness mounts a bare MaterialApp, so the tokens extension is
      // absent and `context.tokens` falls back to the light set.
      const tokens = GarageTokens.light;
      final best = economyColourAt(tester, '5.2 l/100km');
      final worst = economyColourAt(tester, '10.5 l/100km');

      expect(best, tokens.success);
      expect(worst, tokens.danger);
    });

    testWidgets('a car with too little history is left uncoloured', (
      tester,
    ) async {
      // Two fills give one figure, so there is no range to place it in.
      // Colouring it would be inventing a verdict out of a single reading.
      await pumpFuelLog(tester, [
        fill(id: 'f1', odometerKm: 50310),
        fill(id: 'f2', odometerKm: 51140),
      ]);
      await tester.pumpAndSettle();

      // The figure still has the numeric style's own colour; what it must
      // not have is a verdict.
      const tokens = GarageTokens.light;
      expect(
        economyColourAt(tester, '5.2 l/100km'),
        isNot(anyOf(tokens.success, tokens.warn, tokens.danger)),
      );
    });
  });

  // The fuel log showed date, odometer, volume, cost and economy — and not
  // where the fuel was bought, nor whether the row carried a note or a
  // receipt. The timeline has marked both since decision 46; the one screen a
  // driver actually reads their fill-ups on did not, so the row worth opening
  // looked exactly like the twenty that were not.
  group('what a fill-up row says without being opened', () {
    testWidgets('names the station when there is one', (tester) async {
      await pumpFuelLog(tester, [
        fill(id: 'f1', odometerKm: 51140, station: 'INA Zagreb'),
      ]);
      await tester.pumpAndSettle();

      expect(find.textContaining('INA Zagreb'), findsOneWidget);
    });

    testWidgets('says nothing extra when there is no station', (tester) async {
      await pumpFuelLog(tester, [fill(id: 'f1', odometerKm: 51140)]);
      await tester.pumpAndSettle();

      // No dangling separator where the station would have been.
      expect(find.textContaining('· ·'), findsNothing);
      expect(find.textContaining('·  ·'), findsNothing);
    });

    testWidgets('marks a row that carries a note', (tester) async {
      await pumpFuelLog(tester, [
        fill(id: 'f1', odometerKm: 51140, notes: 'smelled odd'),
      ]);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
    });

    testWidgets('does not mark a note that is only whitespace', (tester) async {
      await pumpFuelLog(tester, [
        fill(id: 'f1', odometerKm: 51140, notes: '   '),
      ]);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.sticky_note_2_outlined), findsNothing);
    });

    testWidgets('marks a row that carries a receipt', (tester) async {
      await pumpFuelLog(
        tester,
        [fill(id: 'f1', odometerKm: 51140)],
        withAttachments: {'f1'},
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.attach_file), findsOneWidget);
    });

    testWidgets('leaves an ordinary row unmarked', (tester) async {
      await pumpFuelLog(tester, [fill(id: 'f1', odometerKm: 51140)]);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.sticky_note_2_outlined), findsNothing);
      expect(find.byIcon(Icons.attach_file), findsNothing);
    });

    testWidgets('still shows the economy figure beside the markers', (
      tester,
    ) async {
      // The markers share the trailing slot with the number the screen exists
      // for; adding them must not push it out.
      await pumpFuelLog(
        tester,
        [
          fill(id: 'f1', odometerKm: 50000),
          fill(id: 'f2', odometerKm: 51140, notes: 'note'),
        ],
        withAttachments: {'f2'},
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
      expect(find.byIcon(Icons.attach_file), findsOneWidget);
      expect(find.textContaining('l/100km'), findsWidgets);
    });
  });

  // Every other place a fill-up shows up already read as one continuous list
  // with no sense of when relative to the others, unlike Timeline, which has
  // grouped by month since decision 46.
  group('grouped by month', () {
    testWidgets('a header names each month the list spans', (tester) async {
      await pumpFuelLog(tester, [
        fill(id: 'f1', odometerKm: 51500, date: DateTime.utc(2026, 8, 3)),
        fill(id: 'f2', odometerKm: 51000, date: DateTime.utc(2026, 7, 20)),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('AUGUST 2026'), findsOneWidget);
      expect(find.text('JULY 2026'), findsOneWidget);
    });

    testWidgets('one header serves every fill-up in the same month', (
      tester,
    ) async {
      await pumpFuelLog(tester, [
        fill(id: 'f1', odometerKm: 51500, date: DateTime.utc(2026, 8, 20)),
        fill(id: 'f2', odometerKm: 51000, date: DateTime.utc(2026, 8, 3)),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('AUGUST 2026'), findsOneWidget);
    });

    testWidgets('the header sits above the rows it covers', (tester) async {
      await pumpFuelLog(tester, [
        fill(id: 'f1', odometerKm: 51500, date: DateTime.utc(2026, 8, 3)),
      ]);
      await tester.pumpAndSettle();

      final headerY = tester.getTopLeft(find.text('AUGUST 2026')).dy;
      final rowY = tester.getTopLeft(find.byKey(const ValueKey('f1'))).dy;
      expect(headerY, lessThan(rowY));
    });
  });
}
