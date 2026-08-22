import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/tyre_set.dart';
import 'package:garage/features/tyres/data/tyre_repository.dart';
import 'package:garage/features/tyres/providers/tyre_providers.dart';
import 'package:garage/features/tyres/screens/tyres_screen.dart';

import '../../support/pump_screen.dart';
import '../../support/vehicle_entries.dart';

class FakeTyreRepository implements TyreRepository {
  FakeTyreRepository([this.sets = const []]);

  List<TyreSet> sets;
  final List<String> calls = [];

  @override
  Future<List<TyreSet>> forVehicle(String vehicleId) async => sets;

  @override
  Future<void> addSet({
    required String vehicleId,
    required String name,
    required TyreSeason season,
    String? size,
    String? storageLocation,
  }) async => calls.add('addSet:$name:${season.key}');

  @override
  Future<void> fitSet({
    required String vehicleId,
    required String setId,
  }) async => calls.add('fitSet:$setId');

  @override
  Future<void> retireSet(String setId) async => calls.add('retireSet:$setId');

  @override
  Future<void> deleteSet(String setId) async => calls.add('deleteSet:$setId');

  @override
  Future<void> addReading({
    required String tyreSetId,
    required DateTime date,
    int? odometerKm,
    double? frontLeftMm,
    double? frontRightMm,
    double? rearLeftMm,
    double? rearRightMm,
  }) async => calls.add('addReading:$tyreSetId:$frontLeftMm');
}

TyreSet tyreSet({
  String id = 't1',
  String name = 'Winter — studded',
  TyreSeason season = TyreSeason.winter,
  bool fitted = false,
  DateTime? retiredAt,
  List<TyreReading> readings = const [],
}) {
  return TyreSet(
    id: id,
    vehicleId: 'v1',
    name: name,
    season: season,
    fitted: fitted,
    size: '205/55 R16',
    storageLocation: 'Cellar',
    retiredAt: retiredAt,
    createdBy: 'u1',
    readings: readings,
  );
}

TyreReading reading({
  String id = 'r1',
  double shallowest = 6.5,
  DateTime? date,
  int? odometerKm,
}) {
  return TyreReading(
    id: id,
    date: date ?? DateTime.utc(2026, 10, 1),
    odometerKm: odometerKm,
    frontLeftMm: shallowest,
    frontRightMm: shallowest + 0.2,
    rearLeftMm: shallowest + 0.4,
    rearRightMm: shallowest + 0.3,
  );
}

Future<NavigationLog> pumpTyres(
  WidgetTester tester,
  FakeTyreRepository repository, {
  Size surface = const Size(420, 1000),
}) {
  return pumpScreen(
    tester,
    const TyresScreen(vehicleId: 'v1'),
    initialLocation: '/vehicles/v1/tyres',
    surface: surface,
    overrides: [
      tyreRepositoryProvider.overrideWithValue(repository),
      ...vehicleEntryOverrides('v1'),
    ],
  );
}

void main() {
  testWidgets('the add dialog survives a keyboard-sized window', (
    tester,
  ) async {
    // Three fields and a dropdown in a plain Column: when the keyboard opens
    // the dialog shrinks, an unscrollable column clips its last field, and the
    // buttons get squeezed into what is left.
    await pumpTyres(
      tester,
      FakeTyreRepository(),
      // Roughly what is left of a phone once the keyboard is up.
      surface: const Size(400, 400),
    );
    await tester.pumpAndSettle();

    final add = find.widgetWithText(FilledButton, 'Add a set');
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'the dialog overflows the short window',
    );
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
  });

  testWidgets('a vehicle with no sets is invited to add one', (tester) async {
    await pumpTyres(tester, FakeTyreRepository());
    await tester.pumpAndSettle();

    expect(find.text('Add the sets this vehicle runs on'), findsOneWidget);
  });

  testWidgets('each set is listed with its season and size', (tester) async {
    await pumpTyres(tester, FakeTyreRepository([tyreSet()]));
    await tester.pumpAndSettle();

    expect(find.text('Winter — studded'), findsOneWidget);
    expect(find.textContaining('Winter'), findsWidgets);
    expect(find.textContaining('205/55 R16'), findsOneWidget);
  });

  testWidgets('the set on the car is marked as such', (tester) async {
    await pumpTyres(tester, FakeTyreRepository([tyreSet(fitted: true)]));
    await tester.pumpAndSettle();

    expect(find.text('On the vehicle'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Fit to vehicle'), findsNothing);
  });

  testWidgets('a set in storage can be fitted', (tester) async {
    final repository = FakeTyreRepository([tyreSet()]);
    await pumpTyres(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Fit to vehicle'));
    await tester.pumpAndSettle();

    expect(repository.calls, ['fitSet:t1']);
  });

  testWidgets('the latest tread reading is shown', (tester) async {
    await pumpTyres(
      tester,
      FakeTyreRepository([
        tyreSet(readings: [reading()]),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('6.5'), findsOneWidget);
  });

  testWidgets('a set measured twice shows an estimate of what is left', (
    tester,
  ) async {
    await pumpTyres(
      tester,
      FakeTyreRepository([
        tyreSet(
          readings: [
            reading(
              id: 'r1',
              shallowest: 6.0,
              date: DateTime.utc(2026, 1, 1),
              odometerKm: 40000,
            ),
            reading(
              id: 'r2',
              shallowest: 5.0,
              date: DateTime.utc(2026, 6, 1),
              odometerKm: 50000,
            ),
          ],
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('left, around'), findsOneWidget);
  });

  testWidgets('a set measured only once has nothing to estimate from yet', (
    tester,
  ) async {
    await pumpTyres(
      tester,
      FakeTyreRepository([
        tyreSet(readings: [reading(odometerKm: 40000)]),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('left, around'), findsNothing);
  });

  testWidgets('a set at the legal limit is called out', (tester) async {
    await pumpTyres(
      tester,
      FakeTyreRepository([
        tyreSet(readings: [reading(shallowest: 1.5)]),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('At or below the 1.6 mm legal minimum'), findsOneWidget);
  });

  testWidgets('a set nobody measured says so rather than looking worn', (
    tester,
  ) async {
    await pumpTyres(tester, FakeTyreRepository([tyreSet()]));
    await tester.pumpAndSettle();

    expect(find.text('No tread recorded'), findsOneWidget);
    expect(find.text('At or below the 1.6 mm legal minimum'), findsNothing);
  });

  testWidgets('a retired set is marked and cannot be fitted', (tester) async {
    await pumpTyres(
      tester,
      FakeTyreRepository([tyreSet(retiredAt: DateTime.utc(2027, 3, 1))]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Retired'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Fit to vehicle'), findsNothing);
  });

  testWidgets('adding a set records its name and season', (tester) async {
    final repository = FakeTyreRepository();
    await pumpTyres(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add a set'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Summer set');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.calls, ['addSet:Summer set:all_season']);
  });

  group('retiring and deleting are different things', () {
    // Retiring reused the shared delete confirmation, so taking a set off the
    // car asked "Delete entry?" and warned it could not be undone — of an
    // action that keeps the set and every reading on it.
    testWidgets('retiring asks in its own words, not deletion\'s', (
      tester,
    ) async {
      await pumpTyres(tester, FakeTyreRepository([tyreSet()]));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Retire'));
      await tester.pumpAndSettle();

      expect(find.text('Retire this set?'), findsOneWidget);
      expect(find.text('Delete entry?'), findsNothing);
      expect(find.textContaining('stays on the list'), findsOneWidget);
    });

    testWidgets('confirming a retire retires it', (tester) async {
      final repository = FakeTyreRepository([tyreSet()]);
      await pumpTyres(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Retire'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Retire'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['retireSet:t1']);
    });

    // The repository could always do this and nothing offered it: a set
    // entered by mistake could be retired but never removed.
    testWidgets('a set can be deleted outright', (tester) async {
      final repository = FakeTyreRepository([tyreSet()]);
      await pumpTyres(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Delete set'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['deleteSet:t1']);
    });

    testWidgets('and says the readings go with it', (tester) async {
      await pumpTyres(tester, FakeTyreRepository([tyreSet()]));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Delete set'));
      await tester.pumpAndSettle();

      expect(find.textContaining('every tread reading'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);
    });

    testWidgets('a retired set can still be deleted', (tester) async {
      // Retiring is not a dead end: the set entered by mistake and then
      // retired still has to be removable.
      final repository = FakeTyreRepository([
        tyreSet(retiredAt: DateTime.utc(2027, 3, 1)),
      ]);
      await pumpTyres(tester, repository);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Retire'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Delete set'), findsOneWidget);
    });
  });

  testWidgets('recording tread stores what was measured', (tester) async {
    final repository = FakeTyreRepository([tyreSet()]);
    await pumpTyres(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Record tread'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '5.5');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.calls, ['addReading:t1:5.5']);
  });
}
