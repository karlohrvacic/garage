import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/tyre_set.dart';
import 'package:garage/features/tyres/data/tyre_repository.dart';
import 'package:garage/features/tyres/providers/tyre_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/core/widgets/entry_sheet_body.dart';
import 'package:garage/features/tyres/screens/tyres_screen.dart';

import 'package:garage/features/maintenance/providers/maintenance_providers.dart';

import '../../support/pump_screen.dart';
import '../../support/vehicle_entries.dart';

class FakeTyreRepository implements TyreRepository {
  FakeTyreRepository([this.sets = const []]);

  List<TyreSet> sets;
  final List<String> calls = [];

  /// What each reading carried beyond its tread figures.
  final List<({DateTime date, int? odometerKm})> readings = [];

  @override
  Future<List<TyreSet>> forVehicle(String vehicleId) async => sets;

  @override
  Future<void> addSet({
    required String vehicleId,
    required String name,
    required TyreSeason season,
    String? size,
    String? storageLocation,
    DateTime? manufacturedOn,
  }) async => calls.add(
    'addSet:$name:${season.key}:${manufacturedOn?.toIso8601String() ?? ''}',
  );

  @override
  Future<void> updateSet({
    required String setId,
    required String name,
    required TyreSeason season,
    String? size,
    String? storageLocation,
    DateTime? manufacturedOn,
  }) async => calls.add(
    'updateSet:$setId:$name:${season.key}:${size ?? ''}:'
    '${storageLocation ?? ''}:${manufacturedOn?.toIso8601String() ?? ''}',
  );

  @override
  Future<void> fitSet({
    required String vehicleId,
    required String setId,
  }) async => calls.add('fitSet:$setId');

  @override
  Future<void> unfitSet(String setId) async => calls.add('unfit:$setId');

  @override
  Future<void> unretireSet(String setId) async => unretired.add(setId);

  final unretired = <String>[];

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
  }) async {
    readings.add((date: date, odometerKm: odometerKm));
    calls.add(
      'addReading:$tyreSetId:$frontLeftMm:$frontRightMm:$rearLeftMm:$rearRightMm',
    );
  }
}

TyreSet tyreSet({
  String id = 't1',
  String name = 'Winter — studded',
  TyreSeason season = TyreSeason.winter,
  bool fitted = false,
  DateTime? retiredAt,
  DateTime? fittedAt,
  String? size = '205/55 R16',
  String? storage = 'Cellar',
  DateTime? manufacturedOn,
  List<TyreReading> readings = const [],
}) {
  return TyreSet(
    id: id,
    vehicleId: 'v1',
    name: name,
    season: season,
    fitted: fitted,
    size: size,
    storageLocation: storage,
    manufacturedOn: manufacturedOn,
    retiredAt: retiredAt,
    fittedAt: fittedAt,
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

  /// The vehicle's measured driving rate. Null is a vehicle with too little
  /// history to measure one, which is what the entry overrides give by
  /// default and what turns the wear estimate into a distance without a date.
  double? kmPerDay,

  /// What the car is. A motorcycle has two tyres, not four corners, and the
  /// tread sheet asks accordingly.
  String kind = 'car',
}) {
  return pumpScreen(
    tester,
    const TyresScreen(vehicleId: 'v1'),
    initialLocation: '/vehicles/v1/tyres',
    surface: surface,
    overrides: [
      tyreRepositoryProvider.overrideWithValue(repository),
      allVehiclesProvider.overrideWith(
        (ref) async => [testVehicle('v1', kind: kind)],
      ),
      ...vehicleEntryOverrides('v1'),
      if (kmPerDay != null)
        drivingRateProvider('v1').overrideWith((ref) async => kmPerDay),
    ],
  );
}

/// Retire and Delete moved behind the card's menu; open it first.
Future<void> openSetMenu(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<void>).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a retired set can be brought back', (tester) async {
    // "It stays on the list with its readings" reads reversible, and the
    // only menu item afterwards was Delete set.
    final repository = FakeTyreRepository([
      tyreSet(id: 's1', retiredAt: DateTime.utc(2026, 5, 1)),
    ]);
    await pumpTyres(tester, repository);
    await tester.pumpAndSettle();
    await openSetMenu(tester);

    expect(find.text('Bring back into use'), findsOneWidget);
    await tester.tap(find.text('Bring back into use'));
    await tester.pumpAndSettle();

    expect(repository.unretired, ['s1']);
  });

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

    // No measured driving rate in this harness, so there is a distance and
    // deliberately no date behind it.
    expect(find.textContaining('About'), findsOneWidget);
    expect(find.textContaining('left, around'), findsNothing);
  });

  // The date comes back the moment the vehicle has driving to measure.
  testWidgets('and dates it once the vehicle has a measured rate', (
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
      kmPerDay: 50,
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

    // Trailing empty field: no DOT code was typed, which is the common case.
    expect(repository.calls, ['addSet:Summer set:all_season:']);
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

      await openSetMenu(tester);
      await tester.tap(find.text('Retire').last);
      await tester.pumpAndSettle();

      expect(find.text('Retire this set?'), findsOneWidget);
      expect(find.text('Delete entry?'), findsNothing);
      expect(find.textContaining('stays on the list'), findsOneWidget);
    });

    testWidgets('confirming a retire retires it', (tester) async {
      final repository = FakeTyreRepository([tyreSet()]);
      await pumpTyres(tester, repository);
      await tester.pumpAndSettle();

      await openSetMenu(tester);
      await tester.tap(find.text('Retire').last);
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

      await openSetMenu(tester);
      await tester.tap(find.text('Delete set').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['deleteSet:t1']);
    });

    testWidgets('and says the readings go with it', (tester) async {
      await pumpTyres(tester, FakeTyreRepository([tyreSet()]));
      await tester.pumpAndSettle();

      await openSetMenu(tester);
      await tester.tap(find.text('Delete set').last);
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

      await openSetMenu(tester);
      expect(find.text('Retire'), findsNothing);
      expect(find.text('Delete set'), findsOneWidget);
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

    expect(repository.calls, ['addReading:t1:5.5:null:null:null']);
  });

  // Tyres and API access were the last two surfaces building their own
  // AlertDialogs, so on a phone the same act of typing a few fields arrived
  // as a centre-screen dialog here and as a sheet everywhere else.
  testWidgets('adding a set arrives as a sheet, like every other form', (
    tester,
  ) async {
    await pumpTyres(tester, FakeTyreRepository());
    await tester.pumpAndSettle();

    final add = find.widgetWithText(FilledButton, 'Add a set');
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(find.byType(EntrySheetBody), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  // A tyre set was the only thing in the app a household creates and cannot
  // then correct. Every entry kind edits through its own sheet and a vehicle
  // has an edit screen; a set could only be added, fitted, retired or deleted
  // — so a typo in the name, a wrong season or a moved storage box meant
  // deleting the set and losing its whole tread history with it.
  group('editing a set', () {
    TyreSet existing() => tyreSet(
      name: 'Winter — studded',
      season: TyreSeason.winter,
      size: '205/55 R16',
      storage: 'Cellar',
    );

    Future<void> openEdit(WidgetTester tester) async {
      final edit = find.widgetWithText(TextButton, 'Edit');
      await tester.ensureVisible(edit);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
    }

    testWidgets('is offered on the card', (tester) async {
      await pumpTyres(tester, FakeTyreRepository([existing()]));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Edit'), findsOneWidget);
    });

    testWidgets('opens a sheet that says Edit, not Add', (tester) async {
      await pumpTyres(tester, FakeTyreRepository([existing()]));
      await tester.pumpAndSettle();
      await openEdit(tester);

      // Scoped to the sheet: the screen's own "Add a set" button is still
      // behind it and legitimately says so.
      expect(
        find.descendant(
          of: find.byType(EntrySheetBody),
          matching: find.text('Edit set'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(EntrySheetBody),
          matching: find.text('Add a set'),
        ),
        findsNothing,
      );
    });

    testWidgets('prefills everything the set already holds', (tester) async {
      await pumpTyres(tester, FakeTyreRepository([existing()]));
      await tester.pumpAndSettle();
      await openEdit(tester);

      expect(
        find.widgetWithText(TextField, 'Winter — studded'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, '205/55 R16'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Cellar'), findsOneWidget);
    });

    testWidgets('saves the corrected values against the same set', (
      tester,
    ) async {
      final repository = FakeTyreRepository([existing()]);
      await pumpTyres(tester, repository);
      await tester.pumpAndSettle();
      await openEdit(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Winter — studded'),
        'Winter studded',
      );
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        repository.calls,
        contains('updateSet:t1:Winter studded:winter:205/55 R16:Cellar:'),
      );
    });

    // The tread history is the thing deleting-and-re-adding used to destroy,
    // and the reason an edit had to exist at all.
    testWidgets('and never touches the readings', (tester) async {
      final repository = FakeTyreRepository([existing()]);
      await pumpTyres(tester, repository);
      await tester.pumpAndSettle();
      await openEdit(tester);

      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repository.calls.where((c) => c.startsWith('deleteSet')), isEmpty);
      expect(repository.calls.where((c) => c.startsWith('addSet')), isEmpty);
    });
  });

  // Rubber perishes on a schedule of its own: a set can be legal on tread and
  // years past it on age, and nothing in the app could say so.
  group('how old a set is', () {
    testWidgets('says nothing about a set nothing dates', (tester) async {
      await pumpTyres(tester, FakeTyreRepository([tyreSet()]));
      await tester.pumpAndSettle();

      expect(find.textContaining('years old'), findsNothing);
    });

    testWidgets('stays quiet under six years', (tester) async {
      await pumpTyres(
        tester,
        FakeTyreRepository([tyreSet(manufacturedOn: DateTime.utc(2022, 6, 1))]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('years old'), findsNothing);
    });

    testWidgets('mentions a set past six', (tester) async {
      await pumpTyres(
        tester,
        FakeTyreRepository([tyreSet(manufacturedOn: DateTime.utc(2019, 6, 1))]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('7 years old'), findsOneWidget);
    });

    testWidgets('and says to replace one past ten', (tester) async {
      await pumpTyres(
        tester,
        FakeTyreRepository([tyreSet(manufacturedOn: DateTime.utc(2014, 6, 1))]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('whatever the tread'), findsOneWidget);
    });

    // The fallback errs low, so it is marked rather than asserted — the same
    // distinction the wear estimate and the driving rate already make.
    testWidgets('marks an age taken from the fitted date as estimated', (
      tester,
    ) async {
      await pumpTyres(
        tester,
        FakeTyreRepository([tyreSet(fittedAt: DateTime.utc(2019, 6, 1))]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('estimated'), findsOneWidget);
    });
  });

  group('the DOT code', () {
    Future<void> openEditSheet(WidgetTester tester) async {
      final edit = find.widgetWithText(TextButton, 'Edit');
      await tester.ensureVisible(edit);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
    }

    Future<void> save(WidgetTester tester) async {
      final button = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('is stored as the week it names', (tester) async {
      final repository = FakeTyreRepository([tyreSet()]);
      await pumpTyres(tester, repository);
      await tester.pumpAndSettle();
      await openEditSheet(tester);

      await tester.enterText(find.byKey(const Key('tyre-dot-code')), '3419');
      await tester.pumpAndSettle();
      await save(tester);

      expect(repository.calls.single, contains('2019-08-19T00:00:00.000Z'));
    });

    // Shown back as the code on the sidewall, so it can be checked against
    // the tyre rather than mentally converted from a date.
    testWidgets('comes back as the code, not the date', (tester) async {
      await pumpTyres(
        tester,
        FakeTyreRepository([
          tyreSet(manufacturedOn: DateTime.utc(2019, 8, 19)),
        ]),
      );
      await tester.pumpAndSettle();
      await openEditSheet(tester);

      expect(find.widgetWithText(TextField, '3419'), findsOneWidget);
    });

    // Refused rather than dropped: silently ignoring a mistyped code loses
    // the one thing the household went to the sidewall for.
    testWidgets('a code that is not a code is refused, not ignored', (
      tester,
    ) async {
      final repository = FakeTyreRepository([tyreSet()]);
      await pumpTyres(tester, repository);
      await tester.pumpAndSettle();
      await openEditSheet(tester);

      await tester.enterText(find.byKey(const Key('tyre-dot-code')), '9999');
      await tester.pumpAndSettle();
      await save(tester);

      expect(find.textContaining('week 01-53'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });
  });

  group('a motorcycle has two tyres, not four corners', () {
    testWidgets('the tread sheet asks for a front and a rear', (tester) async {
      // The form asked for four corners on a bike, so a rider left two boxes
      // empty and the sheet looked like a car's.
      await pumpTyres(
        tester,
        FakeTyreRepository([tyreSet()]),
        kind: 'motorcycle',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Record tread'));
      await tester.pumpAndSettle();

      expect(find.text('Front (mm)'), findsOneWidget);
      expect(find.text('Rear (mm)'), findsOneWidget);
      expect(find.text('Front left (mm)'), findsNothing);
      // Two tread boxes and the odometer.
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('what is typed is stored as the front and the rear', (
      tester,
    ) async {
      final repository = FakeTyreRepository([tyreSet()]);
      await pumpTyres(tester, repository, kind: 'motorcycle');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Record tread'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '4.5');
      await tester.enterText(find.byType(TextField).at(1), '3');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['addReading:t1:4.5:null:3.0:null']);
    });
  });

  group('uneven wear', () {
    testWidgets('a set worn unevenly says so, with both figures', (
      tester,
    ) async {
      // The worst corner alone cannot tell a set that is wearing out from one
      // whose alignment is dragging a single corner down.
      await pumpTyres(
        tester,
        FakeTyreRepository([
          tyreSet(
            readings: [
              TyreReading(
                id: 'r1',
                date: DateTime.utc(2026, 5, 1),
                frontLeftMm: 6.5,
                frontRightMm: 3.2,
                rearLeftMm: 7,
                rearRightMm: 7.1,
              ),
            ],
          ),
        ]),
      );
      await tester.pumpAndSettle();

      // The front axle: 3.2 against 6.5. The rear pair agree, and front
      // against rear is not what this line is about.
      expect(find.textContaining('3.2 mm to 6.5 mm'), findsOneWidget);
    });

    testWidgets('a worn rear on a bike is not called uneven', (tester) async {
      // How a motorcycle's readings are stored: front-left and rear-left. A
      // rear that is 3 mm down on the front is a bike being ridden, not a
      // fault.
      await pumpTyres(
        tester,
        FakeTyreRepository([
          tyreSet(
            readings: [
              TyreReading(
                id: 'r1',
                date: DateTime.utc(2026, 5, 1),
                frontLeftMm: 6.5,
                rearLeftMm: 3.0,
              ),
            ],
          ),
        ]),
        kind: 'motorcycle',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(' mm to '), findsNothing);
    });

    testWidgets('an evenly worn set says nothing about it', (tester) async {
      await pumpTyres(
        tester,
        FakeTyreRepository([
          tyreSet(
            readings: [
              TyreReading(
                id: 'r1',
                date: DateTime.utc(2026, 5, 1),
                frontLeftMm: 6.5,
                frontRightMm: 6.4,
                rearLeftMm: 7,
                rearRightMm: 7.1,
              ),
            ],
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(' mm to '), findsNothing);
    });
  });

  group('a tread reading is a dated measurement', () {
    testWidgets('the sheet takes a date and an odometer', (tester) async {
      // Without a date every reading was stamped today, and two taken on one
      // afternoon tied — the card kept showing the first for ever. Without an
      // odometer the wear estimate had nothing to measure against.
      final repository = FakeTyreRepository([tyreSet()]);
      await pumpTyres(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Record tread'));
      await tester.pumpAndSettle();

      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Odometer'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '5.5');
      await tester.enterText(find.byType(TextField).last, '124000');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repository.readings.single.odometerKm, 124000);
    });

    testWidgets('an odometer typed with separators still counts', (
      tester,
    ) async {
      // "124 000" and "124,000" parsed to nothing and the reading saved
      // without the one field the wear estimate needs.
      final repository = FakeTyreRepository([tyreSet()]);
      await pumpTyres(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Record tread'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '5.5');
      await tester.enterText(find.byType(TextField).last, '124 000');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repository.readings.single.odometerKm, 124000);
    });

    testWidgets('an odometer that is not a number is refused, not dropped', (
      tester,
    ) async {
      final repository = FakeTyreRepository([tyreSet()]);
      await pumpTyres(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Record tread'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '5.5');
      await tester.enterText(find.byType(TextField).last, 'about 120k');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repository.readings, isEmpty);
      expect(find.text('Not a number'), findsOneWidget);
    });

    testWidgets('saving says so', (tester) async {
      // Recording the same figures twice is what a person does when the app
      // appears to have ignored the first attempt.
      final repository = FakeTyreRepository([tyreSet()]);
      await pumpTyres(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Record tread'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '5.5');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Tread recorded'), findsOneWidget);
    });

    testWidgets('the card says when the tread was measured', (tester) async {
      await pumpTyres(
        tester,
        FakeTyreRepository([
          tyreSet(
            readings: [
              TyreReading(
                id: 'r1',
                date: DateTime.utc(2026, 5, 1),
                frontLeftMm: 5.5,
              ),
            ],
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Measured'), findsOneWidget);
    });
  });

  group('what the law asks of this vehicle', () {
    testWidgets('a bike below 1.6 mm but above 1.0 is not flagged', (
      tester,
    ) async {
      await pumpTyres(
        tester,
        FakeTyreRepository([
          tyreSet(
            readings: [
              TyreReading(
                id: 'r1',
                date: DateTime.utc(2026, 5, 1),
                frontLeftMm: 2.0,
                rearLeftMm: 1.4,
              ),
            ],
          ),
        ]),
        kind: 'motorcycle',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('legal minimum'), findsNothing);
    });

    testWidgets('a bike at 1.0 mm is flagged, with the figure it is held to', (
      tester,
    ) async {
      await pumpTyres(
        tester,
        FakeTyreRepository([
          tyreSet(
            readings: [
              TyreReading(
                id: 'r1',
                date: DateTime.utc(2026, 5, 1),
                frontLeftMm: 2.0,
                rearLeftMm: 0.9,
              ),
            ],
          ),
        ]),
        kind: 'motorcycle',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('1.0 mm'), findsOneWidget);
      expect(find.textContaining('1.6 mm'), findsNothing);
    });
  });

  testWidgets('the tread figure says which corner it came from', (
    tester,
  ) async {
    // "Tread: 1.4 mm" under four figures entered as 6.2 / 6.0 / 1.4 / 1.6
    // threw away the diagnostic half: which corner is down.
    await pumpTyres(
      tester,
      FakeTyreRepository([
        tyreSet(
          readings: [
            TyreReading(
              id: 'r1',
              date: DateTime.utc(2026, 5, 1),
              frontLeftMm: 6.2,
              frontRightMm: 6.0,
              rearLeftMm: 1.4,
              rearRightMm: 1.6,
            ),
          ],
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1.4 mm (rear left)'), findsOneWidget);
  });

  group('a set that is on the car', () {
    testWidgets('does not also advertise where it is stored', (tester) async {
      // "Garage shelf" beside "On the vehicle" is two answers to one
      // question: a fitted set is on the car, not on the shelf.
      await pumpTyres(
        tester,
        FakeTyreRepository([tyreSet(fitted: true, storage: 'Cellar')]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Cellar'), findsNothing);
    });

    testWidgets('can be taken off again', (tester) async {
      // Fitting another set swapped them, and a household with one set had no
      // way to say the car is on something else entirely.
      final repository = FakeTyreRepository([tyreSet(fitted: true)]);
      await pumpTyres(tester, repository);
      await tester.pumpAndSettle();

      await openSetMenu(tester);
      await tester.tap(find.text('Take off the vehicle'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['unfit:t1']);
    });
  });
}
